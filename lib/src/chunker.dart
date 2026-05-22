/// Splits [body] into a flat list of words on whitespace.
///
/// Empty/whitespace-only bodies yield an empty list.
List<String> splitWords(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return const [];
  // Split on whitespace, then on em/en-dash boundaries, keeping the dash
  // attached to the preceding token.  Plain hyphens in "well-known" are left
  // alone.  "word—word" → ["word—", "word"]; "word–word" → ["word–", "word"].
  return trimmed
      .split(RegExp(r'\s+'))
      .expand((tok) {
        // Split "foo—bar" into ["foo—", "bar"]; leave "—bar" or "foo—" as-is.
        final parts = tok.split(RegExp(r'(?<=[—–])(?=\S)'));
        return parts.where((p) => p.isNotEmpty);
      })
      .toList();
}

/// Returns the break type before word at index [i]: `'\n'` for a single
/// newline (rendered as ` / `), `'\n\n'` for a blank-line paragraph break
/// (rendered as ` ¶ `).  Indices not present use a plain space.
///
/// Word indices here correspond 1-to-1 with [splitWords].
Map<int, String> computeLineBreaks(String body) {
  final breaks = <int, String>{};
  final s = body;
  final n = s.length;
  var i = 0;
  var wordIdx = 0;

  // Skip leading whitespace (mirrors body.trim() in splitWords).
  while (i < n && _isWs(s[i])) {
    i++;
  }

  while (i < n) {
    // Consume a word.
    while (i < n && !_isWs(s[i])) {
      i++;
    }
    wordIdx++;

    // Consume trailing whitespace; count newlines.
    var nlCount = 0;
    while (i < n && _isWs(s[i])) {
      if (s[i] == '\n') nlCount++;
      i++;
    }

    if (nlCount > 0 && i < n) {
      breaks[wordIdx] = nlCount >= 2 ? '\n\n' : '\n';
    }
  }
  return breaks;
}

bool _isWs(String c) => c == ' ' || c == '\t' || c == '\n' || c == '\r';

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
