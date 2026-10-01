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
  const GameSummary(
      {required this.id, required this.title, required this.creator});

  final int id;
  final String title;
  final String creator;
  String get threadUrl => 'https://f95zone.to/threads/$id';

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'creator': creator};
  factory GameSummary.fromJson(Map<String, dynamic> json) => GameSummary(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String? ?? '',
        creator: json['creator'] as String? ?? '',
      );
}

class SearchRecord {
  const SearchRecord(
      {required this.query,
      required this.category,
      required this.field,
      required this.timestamp});
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
        category: SearchCategory.values
            .byName(json['category'] as String? ?? 'games'),
        field: SearchField.values.byName(json['field'] as String? ?? 'title'),
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

class DownloadMirror {
  const DownloadMirror(this.label, this.target);
  final String label;
  final String target;
}

enum PcDownloadState { queued, running, paused, completed, failed }

class PcDownload {
  const PcDownload({
    required this.id,
    required this.game,
    required this.version,
    required this.url,
    required this.name,
    required this.host,
    required this.state,
    this.managerId,
    this.totalBytes = -1,
    this.downloadedBytes = 0,
    this.bytesPerSecond = 0,
    this.error,
  });
  final String id;
  final GameSummary game;
  final String version;
  final String url;
  final String name;
  final String host;
  final PcDownloadState state;
  final int? managerId;
  final int totalBytes;
  final int downloadedBytes;
  final int bytesPerSecond;
  final String? error;
  double? get progress => totalBytes <= 0 ? null : downloadedBytes / totalBytes;
  PcDownload copyWith({PcDownloadState? state, int? managerId,
    int? totalBytes, int? downloadedBytes, int? bytesPerSecond, String? error}) => PcDownload(
      id: id, game: game, version: version, url: url, name: name, host: host,
      state: state ?? this.state, managerId: managerId ?? this.managerId,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
      error: error ?? this.error);
  Map<String, dynamic> toJson() => {
    'id': id, 'game': game.toJson(), 'version': version, 'url': url,
    'name': name, 'host': host, 'state': state.name, 'managerId': managerId,
    'totalBytes': totalBytes, 'downloadedBytes': downloadedBytes,
    'bytesPerSecond': bytesPerSecond, 'error': error,
  };
  factory PcDownload.fromJson(Map<String, dynamic> json) => PcDownload(
    id: json['id'] as String, game: GameSummary.fromJson(Map<String,dynamic>.from(json['game'] as Map)),
    version: json['version'] as String? ?? '', url: json['url'] as String? ?? '',
    name: json['name'] as String? ?? 'Download', host: json['host'] as String? ?? '',
    state: PcDownloadState.values.firstWhere((v) => v.name == json['state'], orElse: () => PcDownloadState.failed),
    managerId: json['managerId'] as int?, totalBytes: json['totalBytes'] as int? ?? -1,
    downloadedBytes: json['downloadedBytes'] as int? ?? 0,
    bytesPerSecond: json['bytesPerSecond'] as int? ?? 0, error: json['error'] as String?);
}

Map<String, String> buildDownloadHeaders({String? cookie, String? userAgent}) => {
  if (cookie != null && cookie.trim().isNotEmpty) 'Cookie': cookie,
  if (userAgent != null && userAgent.trim().isNotEmpty) 'User-Agent': userAgent,
};

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
