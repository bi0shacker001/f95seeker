import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:f95seeker/src/manager.dart';
import 'package:f95seeker/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const game = GameSummary(id: 7, title: 'Test VN', creator: 'Maker');

  test('a link is guessed from its section and label', () {
    expect(guessLinkKind('Win/Linux', 'MEGA'), LinkKind.game);
    expect(guessLinkKind('Mod', 'Walkthrough mod'), LinkKind.mod);
    expect(guessLinkKind('Extras', 'Patch'), LinkKind.patch);
    expect(guessLinkKind('English translation', 'GOFILE'), LinkKind.translation);
    expect(guessLinkKind('Soundtrack', 'Bandcamp'), LinkKind.other);
  });

  test('an update is a different version, ignoring case, spaces and a leading v', () {
    expect(const ManagedGame(game: game, installedVersion: 'v0.5 Beta', latestVersion: '0.5beta').hasUpdate, isFalse);
    expect(const ManagedGame(game: game, installedVersion: '0.5', latestVersion: '0.6').hasUpdate, isTrue);
    expect(const ManagedGame(game: game, latestVersion: '0.6').hasUpdate, isFalse);
  });

  test('tags are trimmed and kept once each', () {
    expect(parseTags(' vn, Sandbox ,vn,, finished'), ['vn', 'Sandbox', 'finished']);
  });

  test('managed games, their folders, tags and tagged links survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ManagerStore();
    await store.load();
    await store.add(game, installedVersion: '0.5');
    await store.update(7, (g) => g.copyWith(folder: '/Games/Test VN', tags: ['vn']));
    await store.tagLink(game, const TaggedLink(url: 'https://mega.nz/x', label: 'Win · MEGA', kind: LinkKind.game, version: '0.6'));
    await store.tagLink(game, const TaggedLink(url: 'https://mega.nz/x', label: 'Win · MEGA', kind: LinkKind.patch, version: '0.6'));
    final restored = ManagerStore();
    await restored.load();
    final g = restored.find(7)!;
    expect(g.installedVersion, '0.5');
    expect(g.folder, '/Games/Test VN');
    expect(g.tags, ['vn']);
    expect(g.links.single.kind, LinkKind.patch);
  });

  test('a version check keeps what it had for a game whose thread cannot be read', () async {
    SharedPreferences.setMockInitialValues({});
    final store = ManagerStore();
    await store.load();
    await store.add(game, installedVersion: '0.5', latestVersion: '0.5');
    await store.add(const GameSummary(id: 8, title: 'Other', creator: 'X'), installedVersion: '1.0');
    final updates = await store.refresh((g) async => g.id == 7 ? '0.6' : throw Exception('down'));
    expect(updates, 1);
    expect(store.find(7)!.latestVersion, '0.6');
    expect(store.find(8)!.latestVersion, '');
  });
}
