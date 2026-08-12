import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class F95Api {
  F95Api({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _stopWords = {
    'a', 'is', 'the', 'an', 'and', 'are', 'as', 'at', 'be', 'but', 'by',
    'for', 'if', 'in', 'into', 'it', 'no', 'not', 'of', 'on', 'or', 'such',
    'that', 'their', 'then', 'there', 'these', 'they', 'this', 'to', 'was',
    'will', 'with',
  };

  /// Adapted from F95Checker's latest_updates_search_sanitize_query.
  static String sanitizeQuery(String input) {
    final normalized = input
        .replaceAll(RegExp(r"[’']s\s+", caseSensitive: false), ' ')
        .replaceAll(RegExp(r"[?&/':;.\-+!~(),*]+"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final words = normalized.split(' ').where((word) =>
        word.isNotEmpty && !_stopWords.contains(word.toLowerCase()));
    var result = '';
    for (final word in words) {
      final addition = '${result.isEmpty ? '' : ' '}$word';
      final remaining = 30 - result.length;
      if (remaining <= 0) break;
      result += addition.substring(0, addition.length.clamp(0, remaining));
      if (addition.length > remaining) break;
    }
    return result;
  }

  Future<List<GameSummary>> search({
    required String query,
    required SearchCategory category,
    required SearchField field,
  }) async {
    final clean = sanitizeQuery(query);
    if (clean.isEmpty) throw const FormatException('Try a more specific search.');
    final uri = Uri.https('f95zone.to', '/sam/latest_alpha/latest_data.php', {
      'cmd': 'list',
      'cat': category.apiValue,
      'page': '1',
      field.apiValue: clean,
      'sort': 'likes',
      'rows': '30',
      '_': DateTime.now().millisecondsSinceEpoch.toString(),
    });
    final root = await _getObject(uri);
    _throwApiError(root);
    final data = ((root['msg'] as Map?)?['data'] as List?) ?? const [];
    return data.whereType<Map>().map((item) => GameSummary(
      id: (item['thread_id'] as num).toInt(),
      title: item['title'] as String? ?? '',
      creator: item['creator'] as String? ?? '',
    )).toList();
  }

  Future<GameDetail> detail(GameSummary summary) async {
    final root = await _getObject(Uri.parse('https://api.f95checker.dev/full/${summary.id}?ts=0'));
    _throwApiError(root);
    final tags = _decodeList(root['tags']).map((e) => e.toString()).toList();
    final downloads = _decodeList(root['downloads']).map((section) {
      final values = section as List;
      final mirrors = (values.length > 1 ? values[1] as List : const []).map((mirror) {
        final pair = mirror as List;
        return DownloadMirror(pair.firstOrNull?.toString() ?? 'Open', pair.elementAtOrNull(1)?.toString() ?? '');
      }).toList();
      return DownloadSection(values.firstOrNull?.toString() ?? 'Downloads', mirrors);
    }).toList();
    final image = root['image_url']?.toString();
    return GameDetail(
      summary: GameSummary(id: summary.id, title: _text(root, 'name', fallback: summary.title), creator: _text(root, 'developer', fallback: summary.creator)),
      version: _text(root, 'version', fallback: 'N/A'),
      developer: _text(root, 'developer', fallback: summary.creator),
      status: const {'1': 'Normal', '2': 'Completed', '3': 'On hold', '4': 'Abandoned'}[root['status']?.toString()] ?? 'Unknown',
      description: _text(root, 'description'),
      changelog: _text(root, 'changelog'),
      tags: tags,
      imageUrl: image != null && image.startsWith('http') ? image : null,
      score: double.tryParse(root['score']?.toString() ?? '') ?? 0,
      votes: int.tryParse(root['votes']?.toString() ?? '') ?? 0,
      downloads: downloads,
    );
  }

  Future<Map<String, dynamic>> _getObject(Uri uri) async {
    final response = await _client.get(uri, headers: {'User-Agent': 'f95seeker/0.1 Android'});
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Request failed (${response.statusCode}).');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void _throwApiError(Map<String, dynamic> root) {
    if (root['status']?.toString().toLowerCase() == 'error') {
      throw Exception(root['msg']?.toString() ?? 'The service returned an error.');
    }
  }

  List<dynamic> _decodeList(dynamic value) {
    if (value is List) return value;
    if (value is String && value.isNotEmpty) return jsonDecode(value) as List;
    return const [];
  }

  String _text(Map<String, dynamic> root, String key, {String fallback = ''}) {
    final value = root[key]?.toString() ?? '';
    return value.isEmpty ? fallback : value;
  }
}

extension _SafeListAccess<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? elementAtOrNull(int index) => index < 0 || index >= length ? null : this[index];
}
