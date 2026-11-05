import 'package:flutter/material.dart';

import 'f95_api.dart';
import 'manager.dart';
import 'models.dart';

/// The one Manager Mode library, loaded at start (lib/main.dart) and shared by every page.
final ManagerStore manager = ManagerStore();

/// Manager Mode's tab: every managed game with the version installed against the thread's latest.
class ManagerPage extends StatefulWidget {
  const ManagerPage({super.key});
  @override
  State<ManagerPage> createState() => _ManagerPageState();
}

class _ManagerPageState extends State<ManagerPage> {
  bool checking = false;

  Future<void> _check() async {
    setState(() => checking = true);
    final api = F95Api();
    final updates = await manager.refresh((game) async => (await api.detail(game)).version);
    if (!mounted) return;
    setState(() => checking = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(updates == 0 ? 'Every managed game is up to date.' : '$updates with a newer version.')));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: manager,
        builder: (context, _) {
          if (manager.games.isEmpty) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No managed games yet. Open a game and choose Add to manager, '
                        'or tag one of its download links.')));
          }
          final sorted = [...manager.games]..sort((a, b) {
              if (a.hasUpdate != b.hasUpdate) return a.hasUpdate ? -1 : 1;
              return a.game.title.toLowerCase().compareTo(b.game.title.toLowerCase());
            });
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Expanded(child: Text('${manager.games.length} managed, ${manager.games.where((g) => g.hasUpdate).length} with an update')),
                checking
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton.icon(onPressed: _check, icon: const Icon(Icons.refresh), label: const Text('Check versions')),
              ]),
            ),
            Expanded(
              child: ListView(
                children: sorted
                    .map((g) => ListTile(
                          title: Text(g.game.title),
                          subtitle: Text([
                            'Installed ${g.installedVersion.isEmpty ? '?' : g.installedVersion}',
                            'latest ${g.latestVersion.isEmpty ? '?' : g.latestVersion}',
                            if (g.tags.isNotEmpty) g.tags.join(', '),
                          ].join(' · ')),
                          trailing: g.hasUpdate ? const Chip(label: Text('Update')) : null,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManagedGamePage(threadId: g.game.id))),
                        ))
                    .toList(),
              ),
            ),
          ]);
        },
      );
}

/// One managed game: its installed version, its folder, the person's tags and the links they tagged.
class ManagedGamePage extends StatelessWidget {
  const ManagedGamePage({required this.threadId, super.key});
  final int threadId;

  Future<String?> _ask(BuildContext context, String title, String value, {String? hint}) {
    final controller = TextEditingController(text: value);
    return showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(title),
              content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(hintText: hint)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
              ],
            ));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: manager,
        builder: (context, _) {
          final g = manager.find(threadId);
          if (g == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('No longer managed.')));
          return Scaffold(
            appBar: AppBar(title: Text(g.game.title), actions: [
              IconButton(
                tooltip: 'Stop managing',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await manager.remove(threadId);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ]),
            body: ListView(padding: const EdgeInsets.all(8), children: [
              ListTile(
                leading: const Icon(Icons.inventory_2_outlined),
                title: const Text('Installed version'),
                subtitle: Text(g.installedVersion.isEmpty ? 'Not set' : g.installedVersion),
                trailing: g.hasUpdate ? Chip(label: Text('Latest ${g.latestVersion}')) : null,
                onTap: () async {
                  final v = await _ask(context, 'Installed version', g.installedVersion, hint: g.latestVersion);
                  if (v != null) await manager.update(threadId, (m) => m.copyWith(installedVersion: v.trim()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.new_releases_outlined),
                title: const Text('Latest version'),
                subtitle: Text(g.latestVersion.isEmpty ? 'Not checked yet' : g.latestVersion),
              ),
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Game folder'),
                subtitle: Text(g.folder.isEmpty ? 'Not tagged' : g.folder),
                onTap: () async {
                  final v = await _ask(context, 'Game folder', g.folder, hint: '/storage/emulated/0/Games/Title');
                  if (v != null) await manager.update(threadId, (m) => m.copyWith(folder: v.trim()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.sell_outlined),
                title: const Text('Tags'),
                subtitle: Text(g.tags.isEmpty ? 'None' : g.tags.join(', ')),
                onTap: () async {
                  final v = await _ask(context, 'Tags', g.tags.join(', '), hint: 'vn, sandbox, finished');
                  if (v != null) await manager.update(threadId, (m) => m.copyWith(tags: parseTags(v)));
                },
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text('Tagged links (${g.links.length})', style: Theme.of(context).textTheme.titleMedium),
              ),
              if (g.links.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Long-press a download on the game\'s Downloads tab to tag it as the game, a mod, a patch or a translation.')),
              ...g.links.map((link) => ListTile(
                    title: Text(link.label.isEmpty ? link.url : link.label),
                    subtitle: Text([link.kind.label, if (link.version.isNotEmpty) link.version].join(' · ')),
                    trailing: PopupMenuButton<LinkKind>(
                      tooltip: 'What it is',
                      onSelected: (kind) => manager.update(
                          threadId, (m) => m.copyWith(links: m.links.map((l) => l.url == link.url ? l.copyWith(kind: kind) : l).toList())),
                      itemBuilder: (_) => LinkKind.values.map((k) => PopupMenuItem(value: k, child: Text(k.label))).toList(),
                    ),
                    onLongPress: () => manager.update(threadId, (m) => m.copyWith(links: m.links.where((l) => l.url != link.url).toList())),
                  )),
            ]),
          );
        },
      );
}

/// Asks what a download link is, guessed from its section and label, and tags it for [game].
Future<void> tagDownloadLink(BuildContext context, GameDetail game, DownloadSection section, DownloadMirror mirror) async {
  final guessed = guessLinkKind(section.name, mirror.label);
  final kind = await showModalBottomSheet<LinkKind>(
      context: context,
      builder: (context) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(title: Text('Tag "${mirror.label}" for ${game.summary.title} as')),
              ...LinkKind.values.map((k) => ListTile(
                    leading: Icon(k == guessed ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                    title: Text(k.label),
                    onTap: () => Navigator.pop(context, k),
                  )),
            ]),
          ));
  if (kind == null) return;
  await manager.tagLink(
      game.summary,
      TaggedLink(url: mirror.target, label: '${section.name} · ${mirror.label}', kind: kind, version: game.version),
      latestVersion: game.version);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tagged as ${kind.label} in Manager.')));
  }
}
