# f95seeker

This is an f95 feed checker and download helper based off the f95checker backend, intended for downloading games on android based gaming handhelds. All credit for original code and infrastructure goes to [f95checker](https://github.com/WillyJL/F95Checker). One again: ALL THIS APP DOES IS SEARCH F95. For anything more involved, look back at f95checker.

> **Unofficial project:** f95seeker is not affiliated with, endorsed by, or sponsored by F95zone or F95Checker.

Please do report issues you find. This is a semi-personal application, so following the basic manners of the internet, it's our responsibilty to find and fix upstream bugs

## What it includes

- A basic Flutter Material 3 interface designed for touch screens and gaming handhelds.
- Search categories and fields matching F95Checker: Games, Comics, Animations, and Assets; searchable by Title or Creator.
- Local search history, capped at the 50 most recent distinct searches.
- Favorites, presented as "Saved games," stored locally on the device.
- An F95Checker-inspired tabbed detail view for Overview, Changelog, Downloads, and Info.
- System, light, and dark appearance modes with lavender branding and six selectable accent themes.
- An optional signed-in F95zone WebView session for protected forum and download links. Credentials are entered only on F95zone's own login page and cookies remain in Android's WebView storage.
- Thread details from the F95Checker cache backend: version, developer, status, rating, tags, artwork, overview, changelog, and available links.
- All forum and download links open in the external browser. Protected/XPath links open the original forum thread so the user's signed-in browser can resolve them.
- Local response caching: searches are reused for 30 minutes and parsed game details for 12 hours. Stale cached data is used when the upstream service is temporarily unavailable.
- An optional setting that watches APK downloads made inside f95seeker, inspects the completed package, and offers to hand it to Android's system installer. Certificate mismatches produce a warning but do not block the attempt.

The app does not receive or store F95zone passwords. It has no game launcher, silent installer, root integration, Shizuku integration, or background service.

Downloaded APKs are provided by third parties. f95seeker does not verify their safety or authenticity. Review the source and requested permissions before installing. Every installation is initiated by the user and confirmed through Android's system installer.

## Creating the platform runner

The Android runner is included. With a current stable Flutter SDK installed, run:

```text
flutter pub get
flutter test
flutter run
```

Release builds are produced automatically by GitHub Actions when a tag beginning with `v` is pushed. The workflow also supports a manual run from the Actions tab.

## Obtainium updates

Add `https://github.com/bi0shacker001/f95seeker` to Obtainium as a GitHub source. Obtainium will detect tagged releases and select the attached `app-release.apk` asset. Releases beginning with v0.3.0 use the project's permanent signing identity, allowing later versions to update in place. Builds older than v0.3.0 used temporary debug signing and must be uninstalled once before installing the new baseline.

## Upstream boundary

The small query sanitizer is adapted from F95Checker. Search uses F95zone's Latest Updates JSON endpoint, and details use `https://api.f95checker.dev/full/{threadId}`. F95Checker's Python/BeautifulSoup forum parser remains in F95Indexer rather than being duplicated on-device.

## License

F95Checker is GPL-3.0. This repository contains a verbatim copy of its `LICENSE` file and is distributed under the same license. See `NOTICE` for attribution.
