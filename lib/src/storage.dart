import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'piece.dart';

const int _schemaVersion = 1;
const int kDefaultChunkSizeFallback = 12;
const String _fileName = 'chonker_library.json';
const Duration _writeDebounce = Duration(milliseconds: 200);

class LibraryData {
  LibraryData({
    required this.defaultChunkSize,
    required this.pieces,
  });

  int defaultChunkSize;
  List<Piece> pieces;

  factory LibraryData.empty() => LibraryData(
        defaultChunkSize: kDefaultChunkSizeFallback,
        pieces: [],
      );

  Map<String, dynamic> toJson() => {
        'version': _schemaVersion,
        'defaultChunkSize': defaultChunkSize,
        'pieces': pieces.map((p) => p.toJson()).toList(),
      };

  factory LibraryData.fromJson(Map<String, dynamic> j) {
    // Future migrations would branch on j['version'] here.
    return LibraryData(
      defaultChunkSize:
          j['defaultChunkSize'] as int? ?? kDefaultChunkSizeFallback,
      pieces: (j['pieces'] as List? ?? const [])
          .map((e) => Piece.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StorageService {
  StorageService._(this._file, this.data);

  final File _file;
  LibraryData data;

  Timer? _debounce;
  Future<void>? _inFlight;

  static Future<StorageService> load() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_fileName');
    if (!await file.exists()) {
      return StorageService._(file, LibraryData.empty());
    }
    try {
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return StorageService._(file, LibraryData.empty());
      }
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return StorageService._(file, LibraryData.fromJson(json));
    } catch (_) {
      // Corrupt file: fall back to empty rather than crash. The original
      // file is left on disk for manual recovery.
      return StorageService._(file, LibraryData.empty());
    }
  }

  /// Schedules a debounced write. Coalesces rapid edits.
  void scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(_writeDebounce, () {
      _debounce = null;
      _writeNow();
    });
  }

  /// Writes immediately, awaiting any in-flight write first.
  Future<void> flush() async {
    _debounce?.cancel();
    _debounce = null;
    await _writeNow();
  }

  Future<void> _writeNow() async {
    // Serialize writes so a slow disk doesn't let two writes interleave.
    final prior = _inFlight;
    final completer = Completer<void>();
    _inFlight = completer.future;
    if (prior != null) {
      try {
        await prior;
      } catch (_) {}
    }
    try {
      final encoded = const JsonEncoder.withIndent('  ').convert(data.toJson());
      // Write-then-rename for atomicity.
      final tmp = File('${_file.path}.tmp');
      await tmp.writeAsString(encoded, flush: true);
      if (await _file.exists()) {
        await _file.delete();
      }
      await tmp.rename(_file.path);
    } finally {
      completer.complete();
    }
  }
}
