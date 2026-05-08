import 'chunker.dart' as chunker;

class Piece {
  Piece({
    required this.id,
    required this.title,
    required this.body,
    required this.chunkSize,
    required this.pinnedEnds,
    required this.lastChunkIndex,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  String title;
  String body;
  int chunkSize;

  /// Word indices the user has explicitly fixed as chunk endings.
  /// Sorted, all values strictly between 0 and wordCount.
  /// Empty means the piece flows in pure `chunkSize` strides.
  List<int> pinnedEnds;

  int lastChunkIndex;
  final DateTime createdAt;
  DateTime updatedAt;

  factory Piece.fresh({
    required String id,
    required String title,
    required String body,
    required int chunkSize,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now().toUtc();
    return Piece(
      id: id,
      title: title,
      body: body,
      chunkSize: chunkSize,
      pinnedEnds: [],
      lastChunkIndex: 0,
      createdAt: ts,
      updatedAt: ts,
    );
  }

  /// Recomputes chunk-start boundaries from current state. Cheap; cache at
  /// call sites if invoked in hot paths.
  List<int> boundaries() {
    final words = chunker.splitWords(body);
    return chunker.computeBoundaries(
      pinnedEnds: pinnedEnds,
      wordCount: words.length,
      chunkSize: chunkSize,
    );
  }

  int get chunkCount => boundaries().length;

  String firstLinePreview() {
    final firstLine = body
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    return firstLine.length > 80 ? '${firstLine.substring(0, 80)}…' : firstLine;
  }

  /// Drops manual pins (e.g. after a body change makes their indices invalid).
  void clearPins() {
    pinnedEnds = [];
    lastChunkIndex = 0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'chunkSize': chunkSize,
        'pinnedEnds': pinnedEnds,
        'lastChunkIndex': lastChunkIndex,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory Piece.fromJson(Map<String, dynamic> j) {
    // Accept new format ('pinnedEnds') or migrate older format
    // ('boundaries' = flat list including the leading 0).
    List<int> pins;
    if (j.containsKey('pinnedEnds')) {
      pins = (j['pinnedEnds'] as List).map((e) => e as int).toList();
    } else if (j.containsKey('boundaries')) {
      final old = (j['boundaries'] as List).map((e) => e as int).toList();
      pins = old.where((b) => b > 0).toList();
    } else {
      pins = [];
    }
    pins.sort();
    return Piece(
      id: j['id'] as String,
      title: j['title'] as String,
      body: j['body'] as String,
      chunkSize: j['chunkSize'] as int,
      pinnedEnds: pins,
      lastChunkIndex: j['lastChunkIndex'] as int? ?? 0,
      createdAt: DateTime.parse(j['createdAt'] as String),
      updatedAt: DateTime.parse(j['updatedAt'] as String),
    );
  }
}
