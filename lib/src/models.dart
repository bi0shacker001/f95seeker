enum SearchCategory {
  games('games', 'Games'),
  comics('comics', 'Comics'),
  animations('animations', 'Animations'),
  assets('assets', 'Assets');

  const SearchCategory(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

enum SearchField {
  title('search', 'Title'),
  creator('creator', 'Creator');

  const SearchField(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class GameSummary {
  const GameSummary({required this.id, required this.title, required this.creator});

  final int id;
  final String title;
  final String creator;
  String get threadUrl => 'https://f95zone.to/threads/$id';

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'creator': creator};
  factory GameSummary.fromJson(Map<String, dynamic> json) => GameSummary(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        creator: json['creator'] as String? ?? '',
      );
}

class SearchRecord {
  const SearchRecord({required this.query, required this.category, required this.field, required this.timestamp});
  final String query;
  final SearchCategory category;
  final SearchField field;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'query': query,
        'category': category.name,
        'field': field.name,
        'timestamp': timestamp.toIso8601String(),
      };
  factory SearchRecord.fromJson(Map<String, dynamic> json) => SearchRecord(
        query: json['query'] as String? ?? '',
        category: SearchCategory.values.byName(json['category'] as String? ?? 'games'),
        field: SearchField.values.byName(json['field'] as String? ?? 'title'),
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

class DownloadMirror {
  const DownloadMirror(this.label, this.target);
  final String label;
  final String target;
}

class DownloadSection {
  const DownloadSection(this.name, this.mirrors);
  final String name;
  final List<DownloadMirror> mirrors;
}

class GameDetail {
  const GameDetail({
    required this.summary,
    required this.version,
    required this.developer,
    required this.status,
    required this.description,
    required this.changelog,
    required this.tags,
    required this.imageUrl,
    required this.score,
    required this.votes,
    required this.downloads,
  });

  final GameSummary summary;
  final String version;
  final String developer;
  final String status;
  final String description;
  final String changelog;
  final List<String> tags;
  final String? imageUrl;
  final double score;
  final int votes;
  final List<DownloadSection> downloads;
}
