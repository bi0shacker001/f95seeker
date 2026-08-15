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
}
