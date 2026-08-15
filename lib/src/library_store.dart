import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LibraryStore extends ChangeNotifier {
  static const _favoritesKey = 'saved_games_v1';
  static const _historyKey = 'search_history_v1';
  static const _recentGamesKey = 'recent_games_v1';
  static const _themeKey = 'theme_mode_v1';
  static const _colorKey = 'theme_color_v1';
  static const _offerApkInstallsKey = 'offer_apk_installs_v1';
  final List<GameSummary> favorites = [];
  final List<SearchRecord> history = [];
  final List<GameSummary> recentGames = [];
  SharedPreferences? _preferences;
  ThemeModePreference themeMode = ThemeModePreference.system;
  ThemeColor themeColor = ThemeColor.lavender;
  bool offerApkInstalls = false;

  Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    favorites
      ..clear()
      ..addAll(_decode(_preferences!.getString(_favoritesKey))
          .map(GameSummary.fromJson));
    history
      ..clear()
      ..addAll(_decode(_preferences!.getString(_historyKey))
          .map(SearchRecord.fromJson));
    recentGames
      ..clear()
      ..addAll(_decode(_preferences!.getString(_recentGamesKey))
          .map(GameSummary.fromJson));
    themeMode = _enumValue(ThemeModePreference.values,
        _preferences!.getString(_themeKey), ThemeModePreference.system);
    themeColor = _enumValue(ThemeColor.values,
        _preferences!.getString(_colorKey), ThemeColor.lavender);
    offerApkInstalls = _preferences!.getBool(_offerApkInstallsKey) ?? false;
    notifyListeners();
  }

  bool isFavorite(int id) => favorites.any((game) => game.id == id);

  Future<void> toggleFavorite(GameSummary game) async {
    final index = favorites.indexWhere((item) => item.id == game.id);
    if (index < 0) {
      favorites.insert(0, game);
    } else {
      favorites.removeAt(index);
    }
    await _preferences!.setString(
        _favoritesKey, jsonEncode(favorites.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> addRecentGame(GameSummary game) async {
    recentGames.removeWhere((item) => item.id == game.id);
    recentGames.insert(0, game);
    if (recentGames.length > 50) {
      recentGames.removeRange(50, recentGames.length);
    }
    await _preferences!.setString(_recentGamesKey,
        jsonEncode(recentGames.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> clearRecentGames() async {
    recentGames.clear();
    await _preferences!.remove(_recentGamesKey);
    notifyListeners();
  }

  Future<void> addHistory(
      String query, SearchCategory category, SearchField field) async {
    history.removeWhere((item) =>
        item.query.toLowerCase() == query.toLowerCase() &&
        item.category == category &&
        item.field == field);
    history.insert(
        0,
        SearchRecord(
            query: query,
            category: category,
            field: field,
            timestamp: DateTime.now()));
    if (history.length > 50) history.removeRange(50, history.length);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeModePreference value) async {
    themeMode = value;
    await _preferences!.setString(_themeKey, value.name);
    notifyListeners();
  }

  Future<void> setThemeColor(ThemeColor value) async {
    themeColor = value;
    await _preferences!.setString(_colorKey, value.name);
    notifyListeners();
  }

  Future<void> setOfferApkInstalls(bool value) async {
    offerApkInstalls = value;
    await _preferences!.setBool(_offerApkInstallsKey, value);
    notifyListeners();
  }

  Future<void> _saveHistory() async => _preferences!.setString(
      _historyKey, jsonEncode(history.map((e) => e.toJson()).toList()));

  List<Map<String, dynamic>> _decode(String? value) {
    if (value == null || value.isEmpty) return const [];
    try {
      return (jsonDecode(value) as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } on FormatException {
      return const [];
    } on TypeError {
      return const [];
    }
  }

  T _enumValue<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.where((value) => value.name == name).firstOrNull ?? fallback;
}

enum ThemeModePreference { system, light, dark }

enum ThemeColor { lavender, crimson, violet, blue, green, amber }
