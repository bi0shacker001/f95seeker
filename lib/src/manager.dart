import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// What a link is to the game it belongs to (Manager Mode).
enum LinkKind {
  game('Game'),
  mod('Mod'),
  patch('Patch'),
  translation('Translation'),
  other('Other');

  const LinkKind(this.label);
  final String label;
}

/// A guess at what a download link is from the section it is listed under and its own label, the words F95 threads
/// use ("Mod", "Patch", "Walkthrough", "English"). The person can change it; a guess is only the starting point.
LinkKind guessLinkKind(String section, String label) {
  final text = '$section $label'.toLowerCase();
  if (RegExp(r'\b(translation|translated|english|eng\b|traduc|übersetz)').hasMatch(text)) {
    return LinkKind.translation;
  }
  if (RegExp(r'\b(mod|mods|cheat|walkthrough|gallery|unlocker)\b').hasMatch(text)) {
    return LinkKind.mod;
  }
  if (RegExp(r'\b(patch|fix|hotfix|update)\b').hasMatch(text)) {
    return LinkKind.patch;
  }
  if (RegExp(r'\b(win|windows|linux|mac|android|pc|download|mega|gofile|pixeldrain|mediafire|workupload)\b').hasMatch(text) ||
      text.trim().isEmpty) {
    return LinkKind.game;
  }
  return LinkKind.other;
}

/// One link the person tagged for a managed game: where it is, what it is, and the version it is for.
class TaggedLink {
  const TaggedLink({required this.url, required this.label, required this.kind, this.version = ''});
  final String url;
  final String label;
  final LinkKind kind;
  final String version;

  TaggedLink copyWith({LinkKind? kind, String? version}) =>
      TaggedLink(url: url, label: label, kind: kind ?? this.kind, version: version ?? this.version);

  Map<String, dynamic> toJson() => {'url': url, 'label': label, 'kind': kind.name, 'version': version};
  factory TaggedLink.fromJson(Map<String, dynamic> json) => TaggedLink(
        url: json['url'] as String? ?? '',
        label: json['label'] as String? ?? '',
        kind: LinkKind.values.firstWhere((k) => k.name == json['kind'], orElse: () => LinkKind.other),
        version: json['version'] as String? ?? '',
      );
}

/// A game the person manages: the thread, the version installed, the latest the thread posts, the folder it is in,
/// the person's own tags and the links they tagged.
class ManagedGame {
  const ManagedGame({
    required this.game,
    this.installedVersion = '',
    this.latestVersion = '',
    this.folder = '',
    this.tags = const [],
    this.links = const [],
    this.checkedAt,
  });
  final GameSummary game;
  final String installedVersion;
  final String latestVersion;
  final String folder;
  final List<String> tags;
  final List<TaggedLink> links;
  final DateTime? checkedAt;

  /// The thread posts a version other than the one installed. Unknown (false) while either is not known.
  bool get hasUpdate =>
      installedVersion.trim().isNotEmpty &&
      latestVersion.trim().isNotEmpty &&
      normalizeVersion(installedVersion) != normalizeVersion(latestVersion);

  ManagedGame copyWith({
    String? installedVersion,
    String? latestVersion,
    String? folder,
    List<String>? tags,
    List<TaggedLink>? links,
    DateTime? checkedAt,
  }) =>
      ManagedGame(
        game: game,
        installedVersion: installedVersion ?? this.installedVersion,
        latestVersion: latestVersion ?? this.latestVersion,
        folder: folder ?? this.folder,
        tags: tags ?? this.tags,
        links: links ?? this.links,
        checkedAt: checkedAt ?? this.checkedAt,
      );

  Map<String, dynamic> toJson() => {
        'game': game.toJson(),
        'installedVersion': installedVersion,
        'latestVersion': latestVersion,
        'folder': folder,
        'tags': tags,
        'links': links.map((l) => l.toJson()).toList(),
        'checkedAt': checkedAt?.toIso8601String(),
      };
  factory ManagedGame.fromJson(Map<String, dynamic> json) => ManagedGame(
        game: GameSummary.fromJson(Map<String, dynamic>.from(json['game'] as Map)),
        installedVersion: json['installedVersion'] as String? ?? '',
        latestVersion: json['latestVersion'] as String? ?? '',
        folder: json['folder'] as String? ?? '',
        tags: (json['tags'] as List? ?? const []).whereType<String>().toList(),
        links: (json['links'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => TaggedLink.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        checkedAt: DateTime.tryParse(json['checkedAt'] as String? ?? ''),
      );
}

/// A version as compared: case and a leading "v" ignored, spaces dropped ("v0.5 Beta" is "0.5beta").
String normalizeVersion(String version) =>
    version.trim().toLowerCase().replaceFirst(RegExp(r'^v(?=\d)'), '').replaceAll(RegExp(r'\s+'), '');

/// The person's tags as typed ("vn, sandbox, finished"), each once, in order.
List<String> parseTags(String text) {
  final out = <String>[];
  for (final raw in text.split(',')) {
    final tag = raw.trim();
    if (tag.isNotEmpty && !out.any((t) => t.toLowerCase() == tag.toLowerCase())) out.add(tag);
  }
  return out;
}

/// Manager Mode's local library: the managed games, kept on the device like the saved games are.
class ManagerStore extends ChangeNotifier {
  static const _key = 'manager_games_v1';
  final List<ManagedGame> games = [];
  SharedPreferences? _preferences;

  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    final raw = _preferences!.getString(_key);
    games.clear();
    if (raw != null && raw.isNotEmpty) {
      try {
        games.addAll((jsonDecode(raw) as List).whereType<Map>().map((m) => ManagedGame.fromJson(Map<String, dynamic>.from(m))));
      } catch (_) {
        // A damaged list is read as empty; nothing else depends on it.
      }
    }
    notifyListeners();
  }

  ManagedGame? find(int threadId) {
    for (final g in games) {
      if (g.game.id == threadId) return g;
    }
    return null;
  }

  bool isManaged(int threadId) => find(threadId) != null;

  /// Adds [game] when it is not managed yet; the installed version is what the person downloaded, when known.
  Future<ManagedGame> add(GameSummary game, {String installedVersion = '', String latestVersion = ''}) async {
    final known = find(game.id);
    if (known != null) return known;
    final added = ManagedGame(game: game, installedVersion: installedVersion, latestVersion: latestVersion);
    games.insert(0, added);
    await _save();
    return added;
  }

  Future<void> remove(int threadId) async {
    games.removeWhere((g) => g.game.id == threadId);
    await _save();
  }

  Future<void> update(int threadId, ManagedGame Function(ManagedGame) change) async {
    final index = games.indexWhere((g) => g.game.id == threadId);
    if (index < 0) return;
    games[index] = change(games[index]);
    await _save();
  }

  /// Tags [link] for the game (added to the manager if it is not yet), replacing an earlier tag of the same address.
  Future<void> tagLink(GameSummary game, TaggedLink link, {String latestVersion = ''}) async {
    await add(game, latestVersion: latestVersion);
    await update(game.id, (g) => g.copyWith(links: [link, ...g.links.where((l) => l.url != link.url)]));
  }

  /// Asks the thread's latest version of every managed game with [latestOf]; one that fails keeps what it had.
  Future<int> refresh(Future<String> Function(GameSummary) latestOf, {DateTime? now}) async {
    var updates = 0;
    for (var i = 0; i < games.length; i++) {
      try {
        final latest = await latestOf(games[i].game);
        games[i] = games[i].copyWith(latestVersion: latest, checkedAt: now ?? DateTime.now());
      } catch (_) {
        continue;
      }
      if (games[i].hasUpdate) updates++;
    }
    await _save();
    return updates;
  }

  Future<void> _save() async {
    await _preferences?.setString(_key, jsonEncode(games.map((g) => g.toJson()).toList()));
    notifyListeners();
  }
}
