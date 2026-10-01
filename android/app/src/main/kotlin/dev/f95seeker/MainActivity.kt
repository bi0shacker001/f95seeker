package dev.f95seeker

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.webkit.CookieManager
import android.webkit.URLUtil
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import android.view.View
import android.webkit.WebView
import android.webkit.WebViewClient
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "dev.f95seeker/apk_installer"
    private lateinit var channel: MethodChannel
    private var selectedApk: File? = null
    private var pendingInstall = false
    private val downloadIds = mutableSetOf<Long>()
    private val pcDownloadIds = mutableSetOf<Long>()
    private val sessionHeaders = mutableMapOf<String, Map<String, String>>()

    private val downloadReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != DownloadManager.ACTION_DOWNLOAD_COMPLETE) return
            val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1)
            if (downloadIds.remove(id)) inspectCompletedDownload(id)
            if (pcDownloadIds.contains(id)) channel.invokeMethod("pcDownloadChanged", mapOf("id" to id))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        )
        channel.setMethodCallHandler(::handleMethodCall)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "dev.f95seeker/download_webview", DownloadWebViewFactory(channel)
        )
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(downloadReceiver, filter, Context.RECEIVER_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(downloadReceiver, filter)
        }
    }

    override fun onDestroy() {
        unregisterReceiver(downloadReceiver)
        super.onDestroy()
    }

    private fun inspectCompletedDownload(id: Long) {
        val manager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        val cursor = manager.query(DownloadManager.Query().setFilterById(id))
        cursor.use {
            if (!it.moveToFirst()) return
            val status = it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
            if (status != DownloadManager.STATUS_SUCCESSFUL) return
            val localUri = it.getString(
                it.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI)
            ) ?: return
            copyAndInspect(Uri.parse(localUri))
        }
    }

    private fun copyAndInspect(uri: Uri) {
        try {
            val target = File(cacheDir, "selected-package.apk")
            val source = if (uri.scheme == "file") {
                File(requireNotNull(uri.path)).inputStream()
            } else {
                contentResolver.openInputStream(uri)
            }
            source.use { input ->
                requireNotNull(input) { "The selected file could not be opened." }
                target.outputStream().use(input::copyTo)
            }
            selectedApk = target
            channel.invokeMethod("apkDownloaded", inspectApk(target))
        } catch (_: Exception) {
            // The completed download was not a readable Android package.
        }
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "downloadApk" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) {
                    result.error("URL_MISSING", "The download URL is missing.", null)
                    return
                }
                try {
                    result.success(enqueueDownload(url))
                } catch (error: Exception) {
                    result.error("DOWNLOAD_FAILED", error.message, null)
                }
            }
            "enqueuePcDownload" -> {
                val url = call.argument<String>("url")
                if (url.isNullOrBlank()) { result.error("URL_MISSING", "The download URL is missing.", null); return }
                try {
                    val id = enqueuePcDownload(url, call.argument<String>("userAgent"), call.argument<String>("cookie"), call.argument<String>("name"))
                    pcDownloadIds.add(id)
                    result.success(id)
                } catch (error: Exception) { result.error("DOWNLOAD_FAILED", error.message, null) }
            }
            "queryPcDownloads" -> result.success(queryPcDownloads(call.argument<List<Number>>("ids")?.map { it.toLong() } ?: emptyList()))
            "cancelPcDownload" -> {
                val id = call.argument<Number>("id")?.toLong()
                if (id != null) (getSystemService(DOWNLOAD_SERVICE) as DownloadManager).remove(id)
                if (id != null) pcDownloadIds.remove(id)
                result.success(true)
            }
            "openPcDownload" -> {
                val id = call.argument<Number>("id")?.toLong()
                val uri = id?.let { (getSystemService(DOWNLOAD_SERVICE) as DownloadManager).getUriForDownloadedFile(it) }
                if (uri == null) result.error("FILE_MISSING", "The downloaded file is not available.", null)
                else {
                    try { startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "*/*").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)); result.success(true) }
                    catch (_: Exception) { result.error("NO_HANDLER", "No app can open this file.", null) }
                }
            }
            "installSelectedApk" -> {
                val apk = selectedApk
                if (apk == null || !apk.exists()) {
                    result.error("APK_MISSING", "Select an APK first.", null)
                    return
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                    !packageManager.canRequestPackageInstalls()
                ) {
                    pendingInstall = true
                    startActivity(Intent(
                        Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                        Uri.parse("package:$packageName")
                    ))
                    result.success(true)
                } else {
                    launchInstaller(apk)
                    result.success(true)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun enqueueDownload(url: String): Long {
        val uri = Uri.parse(url)
        val guessedName = URLUtil.guessFileName(url, null, null)
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
        val fileName = "${System.currentTimeMillis()}-$guessedName"
        val request = DownloadManager.Request(uri)
            .setTitle(guessedName)
            .setDescription("Downloaded by f95seeker")
            .setNotificationVisibility(
                DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED
            )
            .setDestinationInExternalFilesDir(
                this,
                Environment.DIRECTORY_DOWNLOADS,
                fileName
            )
        CookieManager.getInstance().getCookie(url)?.let {
            request.addRequestHeader("Cookie", it)
        }
        request.addRequestHeader("User-Agent", "f95seeker Android")
        val id = (getSystemService(DOWNLOAD_SERVICE) as DownloadManager)
            .enqueue(request)
        downloadIds.add(id)
        return id
    }

    private fun enqueuePcDownload(url: String, userAgent: String?, cookie: String?, name: String?): Long {
        val uri = Uri.parse(url)
        val filename = URLUtil.guessFileName(url, null, null).replace(Regex("[^A-Za-z0-9._-]"), "_")
        val title = name?.takeIf { it.isNotBlank() } ?: filename
        val request = DownloadManager.Request(uri)
            .setTitle(title)
            .setDescription("PC game download")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalPublicDir(Environment.DIRECTORY_DOWNLOADS, "f95seeker/$filename")
        val headers = sessionHeaders[url] ?: buildDownloadHeaders(cookie, userAgent)
        if (headers.isNotEmpty()) sessionHeaders[url] = headers
        headers.forEach { (key, value) -> request.addRequestHeader(key, value) }
        return (getSystemService(DOWNLOAD_SERVICE) as DownloadManager).enqueue(request)
    }

    private fun buildDownloadHeaders(cookie: String?, userAgent: String?): Map<String, String> = buildMap {
        if (!cookie.isNullOrBlank()) put("Cookie", cookie)
        if (!userAgent.isNullOrBlank()) put("User-Agent", userAgent)
    }

    private fun queryPcDownloads(ids: List<Long>): List<Map<String, Any?>> {
        val manager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager
        return ids.mapNotNull { id ->
            val cursor = manager.query(DownloadManager.Query().setFilterById(id))
            cursor.use {
                if (!it.moveToFirst()) return@mapNotNull null
                mapOf(
                    "id" to id,
                    "status" to it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS)),
                    "reason" to it.getInt(it.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON)),
                    "totalBytes" to it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)),
                    "downloadedBytes" to it.getLong(it.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)),
                    "localUri" to it.getString(it.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
                )
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (pendingInstall &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                packageManager.canRequestPackageInstalls())
        ) {
            pendingInstall = false
            selectedApk?.takeIf(File::exists)?.let(::launchInstaller)
        }
    }

    private fun inspectApk(apk: File): Map<String, Any?> {
        val archive = archiveInfo(apk)
            ?: error("Android could not read package information from this APK.")
        val archiveCertificate = certificate(archive)
        val installed = try {
            installedInfo(archive.packageName)
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
        val installedCertificate = installed?.let(::certificate)
        return mapOf(
            "label" to archive.applicationInfo?.let {
                it.sourceDir = apk.absolutePath
                it.publicSourceDir = apk.absolutePath
                packageManager.getApplicationLabel(it).toString()
            },
            "packageName" to archive.packageName,
            "versionName" to (archive.versionName ?: "Unknown"),
            "versionCode" to versionCode(archive),
            "installed" to (installed != null),
            "installedVersionName" to installed?.versionName,
            "installedVersionCode" to installed?.let(::versionCode),
            "certificateMatches" to if (installedCertificate == null) null
                else archiveCertificate == installedCertificate
        )
    }

    @Suppress("DEPRECATION")
    private fun archiveInfo(apk: File): PackageInfo? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageArchiveInfo(
                apk.absolutePath,
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong()
                )
            )
        } else {
            packageManager.getPackageArchiveInfo(
                apk.absolutePath,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
        }

    @Suppress("DEPRECATION")
    private fun installedInfo(packageName: String): PackageInfo =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(
                    PackageManager.GET_SIGNING_CERTIFICATES.toLong()
                )
            )
        } else {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
        }

    @Suppress("DEPRECATION")
    private fun certificate(info: PackageInfo): String? {
        val bytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners?.firstOrNull()?.toByteArray()
        } else {
            info.signatures?.firstOrNull()?.toByteArray()
        } ?: return null
        return MessageDigest.getInstance("SHA-256").digest(bytes)
            .joinToString("") { "%02x".format(it) }
    }

    @Suppress("DEPRECATION")
    private fun versionCode(info: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) info.longVersionCode
        else info.versionCode.toLong()

    private fun launchInstaller(apk: File) {
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.file_provider",
            apk
        )
        startActivity(Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            data = uri
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        })
    }
}

private class DownloadWebViewFactory(
    private val channel: MethodChannel
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        DownloadWebView(context, channel, args as? Map<*, *>)
}

private class DownloadWebView(
    context: Context,
    channel: MethodChannel,
    args: Map<*, *>?
) : PlatformView {
    private val webView = WebView(context).apply {
        val initialUrl = args?.get("url") as? String
        val xpath = args?.get("xpath") as? String
        settings.javaScriptEnabled = true
        webViewClient = object : WebViewClient() {
            private var resolved = false
            override fun onPageFinished(view: WebView, url: String) {
                if (!resolved && !xpath.isNullOrBlank()) {
                    resolved = true
                    val escaped = xpath.replace("\\", "\\\\").replace("'", "\\'")
                    view.evaluateJavascript("const n=document.evaluate('$escaped',document,null,XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue;if(n&&n.href){location.href=n.href;}", null)
                }
            }
        }
        setDownloadListener { url, userAgent, disposition, mimeType, _ ->
            channel.invokeMethod("pcDownloadReady", mapOf(
                "url" to url,
                "userAgent" to userAgent,
                "cookie" to CookieManager.getInstance().getCookie(url),
                "contentDisposition" to disposition,
                "mimeType" to mimeType,
                "name" to URLUtil.guessFileName(url, disposition, mimeType),
                "gameId" to args?.get("gameId"), "gameTitle" to args?.get("gameTitle"),
                "gameCreator" to args?.get("gameCreator"), "version" to args?.get("version")
            ))
        }
        initialUrl?.let(::loadUrl)
    }
    override fun getView(): View = webView
    override fun dispose() = webView.destroy()
}
