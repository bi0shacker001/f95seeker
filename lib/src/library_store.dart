import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class LibraryStore extends ChangeNotifier {
  static const _favoritesKey = 'saved_games_v1';
  static const _historyKey = 'search_history_v1';
  static const _themeKey = 'theme_mode_v1';
  static const _colorKey = 'theme_color_v1';
  final List<GameSummary> favorites = [];
  final List<SearchRecord> history = [];
  SharedPreferences? _preferences;
  ThemeModePreference themeMode = ThemeModePreference.system;
  ThemeColor themeColor = ThemeColor.crimson;

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
    themeMode = ThemeModePreference.values
        .byName(_preferences!.getString(_themeKey) ?? 'system');
    themeColor = ThemeColor.values
        .byName(_preferences!.getString(_colorKey) ?? 'crimson');
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
    await _preferences?.setString(
        _favoritesKey, jsonEncode(favorites.map((e) => e.toJson()).toList()));
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
    await _preferences?.setString(_themeKey, value.name);
    notifyListeners();
  }

  Future<void> setThemeColor(ThemeColor value) async {
    themeColor = value;
    await _preferences?.setString(_colorKey, value.name);
    notifyListeners();
  }

  Future<void> _saveHistory() async => _preferences?.setString(
      _historyKey, jsonEncode(history.map((e) => e.toJson()).toList()));

  List<Map<String, dynamic>> _decode(String? value) {
    if (value == null || value.isEmpty) return const [];
    return (jsonDecode(value) as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

enum ThemeModePreference { system, light, dark }

enum ThemeColor { crimson, violet, blue, green, amber }
