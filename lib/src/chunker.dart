/// Splits [body] into a flat list of words on whitespace.
///
/// Empty/whitespace-only bodies yield an empty list.
List<String> splitWords(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return const [];
  return trimmed.split(RegExp(r'\s+'));
}

/// Computes chunk-start boundaries from [pinnedEnds] (word indices the user
/// has explicitly fixed as chunk endings) and the default flow [chunkSize].
///
/// Semantics:
/// - `boundaries[0]` is always 0.
/// - Between consecutive pins, there is exactly one chunk (no flow).
/// - After the last pin (or from 0 if no pins), chunks flow forward in
///   strides of [chunkSize] until [wordCount].
/// - A pin equal to [wordCount] is allowed and acts as a flow-terminator
///   (no chunks past it). It contributes no entry to the boundaries list
///   since the terminal sentinel is implicit.
/// - Pins outside `(0, wordCount]` are ignored. Duplicates are deduped.
List<int> computeBoundaries({
  required Iterable<int> pinnedEnds,
  required int wordCount,
  required int chunkSize,
}) {
  if (chunkSize < 1) {
    throw ArgumentError.value(chunkSize, 'chunkSize', 'must be >= 1');
  }
  if (wordCount <= 0) return const [0];

  final pins = pinnedEnds
      .where((p) => p > 0 && p <= wordCount)
      .toSet()
      .toList()
    ..sort();

  final out = <int>[0];
  var i = 0;
  var pinIdx = 0;
  // Track whether a pin has terminated flow (== wordCount).
  while (true) {
    int end;
    if (pinIdx < pins.length && pins[pinIdx] > i) {
      end = pins[pinIdx];
      pinIdx++;
    } else if (pinIdx < pins.length) {
      pinIdx++;
      continue;
    } else {
      end = i + chunkSize;
    }
    if (end >= wordCount) break;
    out.add(end);
    i = end;
  }
  return out;
}

/// Returns the [start, end) word indices of chunk [chunkIndex] given
/// [boundaries] and total [wordCount].
({int start, int end}) chunkRange({
  required List<int> boundaries,
  required int chunkIndex,
  required int wordCount,
}) {
  final start = boundaries[chunkIndex];
  final end = chunkIndex + 1 < boundaries.length
      ? boundaries[chunkIndex + 1]
      : wordCount;
  return (start: start, end: end);
}
