import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:f95seeker/src/library_store.dart';
import 'package:f95seeker/src/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saved games, searches, and recently opened games persist', () async {
    SharedPreferences.setMockInitialValues({});
    const game = GameSummary(id: 42, title: 'Test game', creator: 'Developer');

    final first = LibraryStore();
    await first.load();
    await first.toggleFavorite(game);
    await first.addHistory('test', SearchCategory.games, SearchField.title);
    await first.addRecentGame(game);
    await first.setOfferApkInstalls(true);

    final restored = LibraryStore();
    await restored.load();

    expect(restored.favorites.single.id, 42);
    expect(restored.history.single.query, 'test');
    expect(restored.recentGames.single.id, 42);
    expect(restored.offerApkInstalls, isTrue);
  });

  test('PC download queue survives reload with game and manager state', () async {
    SharedPreferences.setMockInitialValues({});
    final store = LibraryStore();
    await store.load();
    store.pcDownloads.add(const PcDownload(
      id: 'q1', game: GameSummary(id: 8, title: 'Game', creator: 'Maker'),
      version: '1.2', url: 'https://files.example/game.zip', name: 'game.zip',
      host: 'files.example', state: PcDownloadState.running, managerId: 25));
    await store.savePcDownloads();
    final restored = LibraryStore();
    await restored.load();
    expect(restored.pcDownloads.single.game.id, 8);
    expect(restored.pcDownloads.single.managerId, 25);
    expect(restored.pcDownloads.single.state, PcDownloadState.running);
  });

  test('download headers omit absent values and keep session values', () {
    expect(buildDownloadHeaders(cookie: 'sid=secret', userAgent: 'WebView/1'),
        {'Cookie': 'sid=secret', 'User-Agent': 'WebView/1'});
    expect(buildDownloadHeaders(), isEmpty);
  });
}
