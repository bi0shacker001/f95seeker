import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'f95_api.dart';
import 'library_store.dart';
import 'models.dart';

class F95FeedApp extends StatefulWidget {
  const F95FeedApp({super.key});
  @override State<F95FeedApp> createState() => _F95FeedAppState();
}

class _F95FeedAppState extends State<F95FeedApp> {
  final store = LibraryStore();
  @override void initState() { super.initState(); store.load(); }
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'f95seeker',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff913535)), useMaterial3: true),
    home: HomePage(store: store),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({required this.store, super.key});
  final LibraryStore store;
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;
  SearchRecord? replay;
  @override Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: Text(['Search', 'History', 'Saved games'][tab])),
      body: IndexedStack(index: tab, children: [
        SearchPage(store: widget.store, replay: replay, onReplayConsumed: () => replay = null),
        HistoryPage(store: widget.store, onSelect: (record) => setState(() { replay = record; tab = 0; })),
        SavedPage(store: widget.store),
      ]),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (value) => setState(() => tab = value), destinations: const [
        NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
        NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        NavigationDestination(icon: Icon(Icons.favorite_outline), selectedIcon: Icon(Icons.favorite), label: 'Saved'),
      ]),
    ),
  );
}

class SearchPage extends StatefulWidget {
  const SearchPage({required this.store, required this.replay, required this.onReplayConsumed, super.key});
  final LibraryStore store;
  final SearchRecord? replay;
  final VoidCallback onReplayConsumed;
  @override State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final api = F95Api();
  final controller = TextEditingController();
  SearchCategory category = SearchCategory.games;
  SearchField field = SearchField.title;
  List<GameSummary> results = const [];
  bool loading = false;
  String? error;

  @override void didUpdateWidget(covariant SearchPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final record = widget.replay;
    if (record != null) {
      controller.text = record.query; category = record.category; field = record.field;
      widget.onReplayConsumed();
      WidgetsBinding.instance.addPostFrameCallback((_) => search());
    }
  }

  Future<void> search() async {
    FocusScope.of(context).unfocus();
    final query = controller.text.trim();
    if (query.isEmpty) return;
    setState(() { loading = true; error = null; });
    try {
      final found = await api.search(query: query, category: category, field: field);
      await widget.store.addHistory(query, category, field);
      if (mounted) setState(() => results = found);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override Widget build(BuildContext context) => Column(children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 4), child: SearchBar(
      controller: controller, hintText: 'Search F95 threads', onSubmitted: (_) => search(),
      leading: const Icon(Icons.search), trailing: [IconButton(onPressed: search, icon: const Icon(Icons.arrow_forward))],
    )),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
      Expanded(child: DropdownButtonFormField(key: ValueKey(category), initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: SearchCategory.values.map((v) => DropdownMenuItem(value: v, child: Text(v.label))).toList(), onChanged: (v) => setState(() => category = v!))),
      const SizedBox(width: 12),
      Expanded(child: DropdownButtonFormField(key: ValueKey(field), initialValue: field, decoration: const InputDecoration(labelText: 'Search by'), items: SearchField.values.map((v) => DropdownMenuItem(value: v, child: Text(v.label))).toList(), onChanged: (v) => setState(() => field = v!))),
    ])),
    if (loading) const LinearProgressIndicator(),
    if (error != null) Padding(padding: const EdgeInsets.all(16), child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
    Expanded(child: results.isEmpty && !loading ? const Center(child: Text('Search by title or creator.')) : ListView.builder(
      padding: const EdgeInsets.all(12), itemCount: results.length, itemBuilder: (context, index) {
        final game = results[index];
        return Card(child: ListTile(
          title: Text(game.title), subtitle: Text(game.creator.isEmpty ? 'Thread ${game.id}' : '${game.creator}\nThread ${game.id}'), isThreeLine: game.creator.isNotEmpty,
          trailing: IconButton(onPressed: () => widget.store.toggleFavorite(game), icon: Icon(widget.store.isFavorite(game.id) ? Icons.favorite : Icons.favorite_border)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(summary: game, store: widget.store))),
        ));
      },
    )),
  ]);
}

class HistoryPage extends StatelessWidget {
  const HistoryPage({required this.store, required this.onSelect, super.key});
  final LibraryStore store;
  final ValueChanged<SearchRecord> onSelect;
  @override Widget build(BuildContext context) => Column(children: [
    if (store.history.isNotEmpty) Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: store.clearHistory, icon: const Icon(Icons.delete_outline), label: const Text('Clear history'))),
    Expanded(child: store.history.isEmpty ? const Center(child: Text('No searches yet.')) : ListView.builder(itemCount: store.history.length, itemBuilder: (context, index) {
      final item = store.history[index];
      return ListTile(leading: const Icon(Icons.history), title: Text(item.query), subtitle: Text('${item.category.label} · ${item.field.label}'), onTap: () => onSelect(item));
    })),
  ]);
}

class SavedPage extends StatelessWidget {
  const SavedPage({required this.store, super.key});
  final LibraryStore store;
  @override Widget build(BuildContext context) => store.favorites.isEmpty ? const Center(child: Text('No saved games yet.')) : ListView.builder(
    padding: const EdgeInsets.all(12), itemCount: store.favorites.length, itemBuilder: (context, index) {
      final game = store.favorites[index];
      return Card(child: ListTile(title: Text(game.title), subtitle: Text(game.creator), trailing: IconButton(onPressed: () => store.toggleFavorite(game), icon: const Icon(Icons.favorite)), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailPage(summary: game, store: store)))));
    },
  );
}

class DetailPage extends StatefulWidget {
  const DetailPage({required this.summary, required this.store, super.key});
  final GameSummary summary;
  final LibraryStore store;
  @override State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late final Future<GameDetail> detail = F95Api().detail(widget.summary);
  Future<void> open(String target) async {
    final uri = Uri.parse(target.startsWith('http') ? target : widget.summary.threadUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the browser.')));
    }
  }
  @override Widget build(BuildContext context) => ListenableBuilder(listenable: widget.store, builder: (context, _) => Scaffold(
    appBar: AppBar(title: Text(widget.summary.title), actions: [IconButton(onPressed: () => widget.store.toggleFavorite(widget.summary), icon: Icon(widget.store.isFavorite(widget.summary.id) ? Icons.favorite : Icons.favorite_border))]),
    body: FutureBuilder<GameDetail>(future: detail, builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(snapshot.error.toString())));
      final game = snapshot.requireData;
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (game.imageUrl != null) ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(game.imageUrl!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink())),
        const SizedBox(height: 12), Text(game.summary.title, style: Theme.of(context).textTheme.headlineSmall),
        if (game.developer.isNotEmpty) Text('by ${game.developer}', style: Theme.of(context).textTheme.titleMedium),
        Text('Version ${game.version} · ${game.status}${game.score > 0 ? ' · ★ ${game.score} (${game.votes})' : ''}'),
        if (game.tags.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Wrap(spacing: 6, children: game.tags.map((tag) => Chip(label: Text(tag))).toList())),
        if (game.description.isNotEmpty) _Section('Overview', game.description),
        if (game.changelog.isNotEmpty) _Section('Changelog', game.changelog),
        if (game.downloads.isNotEmpty) Text('Downloads', style: Theme.of(context).textTheme.titleLarge),
        ...game.downloads.map((section) => Padding(padding: const EdgeInsets.only(top: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(section.name, style: Theme.of(context).textTheme.titleMedium), Wrap(spacing: 8, children: section.mirrors.map((mirror) => ActionChip(avatar: const Icon(Icons.open_in_new, size: 16), label: Text(mirror.label), onPressed: () => open(mirror.target))).toList())]))),
        const SizedBox(height: 16), FilledButton.icon(onPressed: () => open(widget.summary.threadUrl), icon: const Icon(Icons.open_in_new), label: const Text('Open forum thread')),
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('Links open in your browser. Some downloads require an F95zone account.')),
      ]);
    }),
  ));
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.body);
  final String title;
  final String body;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 6), Text(body)]));
}
