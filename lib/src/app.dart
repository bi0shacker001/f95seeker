import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'f95_api.dart';
import 'library_store.dart';
import 'models.dart';

class F95FeedApp extends StatefulWidget {
  const F95FeedApp({super.key});
  @override
  State<F95FeedApp> createState() => _F95FeedAppState();
}

class _F95FeedAppState extends State<F95FeedApp> {
  final store = LibraryStore();
  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final seed = switch (store.themeColor) {
            ThemeColor.lavender => const Color(0xffB89BFF),
            ThemeColor.crimson => const Color(0xff913535),
            ThemeColor.violet => const Color(0xff6f43a5),
            ThemeColor.blue => const Color(0xff3168a8),
            ThemeColor.green => const Color(0xff357a55),
            ThemeColor.amber => const Color(0xff9a6415),
          };
          final mode = switch (store.themeMode) {
            ThemeModePreference.system => ThemeMode.system,
            ThemeModePreference.light => ThemeMode.light,
            ThemeModePreference.dark => ThemeMode.dark,
          };
          return MaterialApp(
            title: 'f95seeker',
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: seed),
                useMaterial3: true),
            darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                    seedColor: seed, brightness: Brightness.dark),
                useMaterial3: true),
            home: HomePage(store: store),
          );
        },
      );
}

class HomePage extends StatefulWidget {
  const HomePage({required this.store, super.key});
  final LibraryStore store;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  SearchRecord? replay;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.store,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
              title:
                  Text(['Search', 'History', 'Saved games', 'Settings'][tab])),
          body: IndexedStack(index: tab, children: [
            SearchPage(
                store: widget.store,
                replay: replay,
                onReplayConsumed: () => replay = null),
            HistoryPage(
                store: widget.store,
                onSelect: (record) => setState(() {
                      replay = record;
                      tab = 0;
                    })),
            SavedPage(store: widget.store),
            SettingsPage(store: widget.store),
          ]),
          bottomNavigationBar: NavigationBar(
              selectedIndex: tab,
              onDestinationSelected: (value) => setState(() => tab = value),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.search), label: 'Search'),
                NavigationDestination(
                    icon: Icon(Icons.history), label: 'History'),
                NavigationDestination(
                    icon: Icon(Icons.favorite_outline),
                    selectedIcon: Icon(Icons.favorite),
                    label: 'Saved'),
                NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: 'Settings'),
              ]),
        ),
      );
}

class SearchPage extends StatefulWidget {
  const SearchPage(
      {required this.store,
      required this.replay,
      required this.onReplayConsumed,
      super.key});
  final LibraryStore store;
  final SearchRecord? replay;
  final VoidCallback onReplayConsumed;
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final api = F95Api();
  final controller = TextEditingController();
  SearchCategory category = SearchCategory.games;
  SearchField field = SearchField.title;
  List<GameSummary> results = const [];
  bool loading = false;
  String? error;

  @override
  void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final record = widget.replay;
    if (record != null) {
      controller.text = record.query;
      category = record.category;
      field = record.field;
      widget.onReplayConsumed();
      WidgetsBinding.instance.addPostFrameCallback((_) => search());
    }
  }

  Future<void> search() async {
    FocusScope.of(context).unfocus();
    final query = controller.text.trim();
    if (query.isEmpty) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final found =
          await api.search(query: query, category: category, field: field);
      await widget.store.addHistory(query, category, field);
      if (mounted) {
        setState(() => results = found);
      }
    } catch (exception) {
      if (mounted) {
        setState(
            () => error = exception.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SearchBar(
              controller: controller,
              hintText: 'Search F95 threads',
              onSubmitted: (_) => search(),
              leading: const Icon(Icons.search),
              trailing: [
                IconButton(
                    onPressed: search, icon: const Icon(Icons.arrow_forward))
              ],
            )),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Expanded(
                  child: DropdownButtonFormField(
                      key: ValueKey(category),
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: SearchCategory.values
                          .map((v) =>
                              DropdownMenuItem(value: v, child: Text(v.label)))
                          .toList(),
                      onChanged: (v) => setState(() => category = v!))),
              const SizedBox(width: 12),
              Expanded(
                  child: DropdownButtonFormField(
                      key: ValueKey(field),
                      initialValue: field,
                      decoration: const InputDecoration(labelText: 'Search by'),
                      items: SearchField.values
                          .map((v) =>
                              DropdownMenuItem(value: v, child: Text(v.label)))
                          .toList(),
                      onChanged: (v) => setState(() => field = v!))),
            ])),
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        Expanded(
            child: results.isEmpty && !loading
                ? const Center(child: Text('Search by title or creator.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final game = results[index];
                      return Card(
                          child: ListTile(
                        title: Text(game.title),
                        subtitle: Text(game.creator.isEmpty
                            ? 'Thread ${game.id}'
                            : '${game.creator}\nThread ${game.id}'),
                        isThreeLine: game.creator.isNotEmpty,
                        trailing: IconButton(
                            onPressed: () => widget.store.toggleFavorite(game),
                            icon: Icon(widget.store.isFavorite(game.id)
                                ? Icons.favorite
                                : Icons.favorite_border)),
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => DetailPage(
                                    summary: game, store: widget.store))),
                      ));
                    },
                  )),
      ]);
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({required this.store, required this.onSelect, super.key});
  final LibraryStore store;
  final ValueChanged<SearchRecord> onSelect;
  @override
  Widget build(BuildContext context) => Column(children: [
        if (store.history.isNotEmpty)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: store.clearHistory,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear history'))),
        Expanded(
            child: store.history.isEmpty
                ? const Center(child: Text('No searches yet.'))
                : ListView.builder(
                    itemCount: store.history.length,
                    itemBuilder: (context, index) {
                      final item = store.history[index];
                      return ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(item.query),
                          subtitle: Text(
                              '${item.category.label} · ${item.field.label}'),
                          onTap: () => onSelect(item));
                    })),
      ]);
}

class SavedPage extends StatelessWidget {
  const SavedPage({required this.store, super.key});
  final LibraryStore store;
  @override
  Widget build(BuildContext context) => store.favorites.isEmpty
      ? const Center(child: Text('No saved games yet.'))
      : ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: store.favorites.length,
          itemBuilder: (context, index) {
            final game = store.favorites[index];
            return Card(
                child: ListTile(
                    title: Text(game.title),
                    subtitle: Text(game.creator),
                    trailing: IconButton(
                        onPressed: () => store.toggleFavorite(game),
                        icon: const Icon(Icons.favorite)),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                DetailPage(summary: game, store: store)))));
          },
        );
}

class DetailPage extends StatefulWidget {
  const DetailPage({required this.summary, required this.store, super.key});
  final GameSummary summary;
  final LibraryStore store;
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late final Future<GameDetail> detail = F95Api().detail(widget.summary);
  void open(String target) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ForumBrowserPage(
                initialUrl: widget.summary.threadUrl,
                directUrl: target.startsWith('http') ? target : null,
                xpath: target.startsWith('//') ? target : null,
              )));
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => Scaffold(
            appBar: AppBar(title: Text(widget.summary.title), actions: [
              IconButton(
                  onPressed: () => widget.store.toggleFavorite(widget.summary),
                  icon: Icon(widget.store.isFavorite(widget.summary.id)
                      ? Icons.favorite
                      : Icons.favorite_border))
            ]),
            body: FutureBuilder<GameDetail>(
                future: detail,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(snapshot.error.toString())));
                  }
                  final game = snapshot.requireData;
                  return DefaultTabController(
                      length: 4,
                      child: Column(children: [
                        _GameHeader(game: game),
                        const TabBar(isScrollable: true, tabs: [
                          Tab(text: 'Overview'),
                          Tab(text: 'Changelog'),
                          Tab(text: 'Downloads'),
                          Tab(text: 'Info')
                        ]),
                        Expanded(
                            child: TabBarView(children: [
                          _TabBody(
                              child: game.description.isEmpty
                                  ? const Text('No overview available.')
                                  : Text(game.description)),
                          _TabBody(
                              child: game.changelog.isEmpty
                                  ? const Text('No changelog available.')
                                  : Text(game.changelog)),
                          _DownloadsTab(game: game, open: open),
                          _InfoTab(
                              game: game,
                              openThread: () => open(widget.summary.threadUrl)),
                        ])),
                      ]));
                }),
          ));
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({required this.game});
  final GameDetail game;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (game.imageUrl != null)
          ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(game.imageUrl!,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink())),
        if (game.imageUrl != null) const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(game.summary.title,
              style: Theme.of(context).textTheme.titleLarge),
          if (game.developer.isNotEmpty) Text(game.developer),
          const SizedBox(height: 4),
          Text('Version ${game.version} · ${game.status}'),
          if (game.score > 0) Text('★ ${game.score} (${game.votes} votes)')
        ])),
      ]));
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(padding: const EdgeInsets.all(16), child: child);
}

class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab({required this.game, required this.open});
  final GameDetail game;
  final ValueChanged<String> open;
  @override
  Widget build(BuildContext context) => game.downloads.isEmpty
      ? const Center(
          child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                  'No cached download sections. Sign in and open the forum thread to view protected links.')))
      : ListView(
          padding: const EdgeInsets.all(16),
          children: game.downloads
              .map((section) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(section.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: section.mirrors
                                  .map((mirror) => FilledButton.tonalIcon(
                                        onPressed: () => open(mirror.target),
                                        icon: const Icon(Icons.download),
                                        label: Text(mirror.label),
                                      ))
                                  .toList(),
                            ),
                          ]),
                    ),
                  ))
              .toList(),
        );
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.game, required this.openThread});
  final GameDetail game;
  final VoidCallback openThread;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Developer'),
            subtitle:
                Text(game.developer.isEmpty ? 'Unknown' : game.developer)),
        ListTile(
            leading: const Icon(Icons.update),
            title: const Text('Version'),
            subtitle: Text(game.version)),
        ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Status'),
            subtitle: Text(game.status)),
        if (game.tags.isNotEmpty)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      game.tags.map((tag) => Chip(label: Text(tag))).toList())),
        FilledButton.icon(
            onPressed: openThread,
            icon: const Icon(Icons.public),
            label: const Text('Open signed-in forum')),
      ]);
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.store, super.key});
  final LibraryStore store;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        DropdownButtonFormField(
            initialValue: store.themeMode,
            decoration: const InputDecoration(
                labelText: 'Brightness', border: OutlineInputBorder()),
            items: ThemeModePreference.values
                .map((value) => DropdownMenuItem(
                    value: value,
                    child: Text(switch (value) {
                      ThemeModePreference.system => 'Follow system',
                      ThemeModePreference.light => 'Light',
                      ThemeModePreference.dark => 'Dark'
                    })))
                .toList(),
            onChanged: (value) => store.setThemeMode(value!)),
        const SizedBox(height: 12),
        DropdownButtonFormField(
            initialValue: store.themeColor,
            decoration: const InputDecoration(
                labelText: 'Accent color', border: OutlineInputBorder()),
            items: ThemeColor.values
                .map((value) => DropdownMenuItem(
                    value: value,
                    child: Text(
                        value.name[0].toUpperCase() + value.name.substring(1))))
                .toList(),
            onChanged: (value) => store.setThemeColor(value!)),
        const SizedBox(height: 24),
        Text('F95zone session', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        const Text(
            'Sign in on F95zone’s own page. Your password is handled by the website and your session stays in Android’s WebView cookie store.'),
        const SizedBox(height: 12),
        FilledButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ForumBrowserPage(
                        initialUrl: 'https://f95zone.to/login/'))),
            icon: const Icon(Icons.login),
            label: const Text('Sign in to F95zone')),
        OutlinedButton.icon(
            onPressed: () async {
              await WebViewCookieManager().clearCookies();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('F95zone WebView session cleared.')));
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Clear forum session')),
        const SizedBox(height: 24),
        Text('Storage', style: Theme.of(context).textTheme.titleLarge),
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Clear search history'),
            onTap: store.clearHistory),
        const SizedBox(height: 24),
        Text('About', style: Theme.of(context).textTheme.titleLarge),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('Unofficial community project'),
          subtitle: Text(
              'f95seeker is not affiliated with, endorsed by, or sponsored by F95zone or F95Checker. All credit for the original backend and infrastructure goes to F95Checker.'),
        ),
      ]);
}

class ForumBrowserPage extends StatefulWidget {
  const ForumBrowserPage(
      {required this.initialUrl, this.directUrl, this.xpath, super.key});
  final String initialUrl;
  final String? directUrl;
  final String? xpath;
  @override
  State<ForumBrowserPage> createState() => _ForumBrowserPageState();
}

class _ForumBrowserPageState extends State<ForumBrowserPage> {
  late final WebViewController controller;
  var progress = 0;
  var resolved = false;
  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (value) => setState(() => progress = value),
        onPageFinished: (_) => _resolveProtectedLink(),
      ))
      ..loadRequest(Uri.parse(widget.directUrl ?? widget.initialUrl));
  }

  Future<void> _resolveProtectedLink() async {
    if (resolved || widget.xpath == null) return;
    resolved = true;
    final encoded =
        widget.xpath!.replaceAll(r'\', r'\\').replaceAll("'", r"\'");
    await controller.runJavaScript(
        "const n=document.evaluate('$encoded',document,null,XPathResult.FIRST_ORDERED_NODE_TYPE,null).singleNodeValue;if(n&&n.href){location.href=n.href;}");
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('F95zone'), actions: [
          IconButton(
              onPressed: controller.reload, icon: const Icon(Icons.refresh)),
          IconButton(
              onPressed: () async {
                final url = await controller.currentUrl();
                if (url != null) {
                  launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser))
        ]),
        body: Column(children: [
          if (progress < 100) LinearProgressIndicator(value: progress / 100),
          Expanded(child: WebViewWidget(controller: controller))
        ]),
      );
}
