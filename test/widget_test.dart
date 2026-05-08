import 'package:flutter_test/flutter_test.dart';

import 'package:chonker/src/chunker.dart';
import 'package:chonker/src/piece.dart';

void main() {
  group('splitWords', () {
    test('splits on any whitespace', () {
      expect(splitWords('a b\tc\n d'), ['a', 'b', 'c', 'd']);
    });
    test('strips leading/trailing whitespace', () {
      expect(splitWords('  hi  there  '), ['hi', 'there']);
    });
    test('empty body yields empty list', () {
      expect(splitWords(''), const <String>[]);
      expect(splitWords('   \n  '), const <String>[]);
    });
    test('keeps punctuation attached to words', () {
      expect(splitWords('Two roads, diverged.'), ['Two', 'roads,', 'diverged.']);
    });
  });

  group('computeBoundaries — pure flow (no pins)', () {
    test('zero words yields [0]', () {
      expect(
        computeBoundaries(pinnedEnds: const [], wordCount: 0, chunkSize: 12),
        [0],
      );
    });
    test('exact multiples', () {
      expect(
        computeBoundaries(pinnedEnds: const [], wordCount: 24, chunkSize: 12),
        [0, 12],
      );
    });
    test('non-exact: last chunk smaller', () {
      expect(
        computeBoundaries(pinnedEnds: const [], wordCount: 30, chunkSize: 12),
        [0, 12, 24],
      );
    });
    test('throws on chunkSize < 1', () {
      expect(
        () => computeBoundaries(
          pinnedEnds: const [],
          wordCount: 10,
          chunkSize: 0,
        ),
        throwsArgumentError,
      );
    });
  });

  group('computeBoundaries — with pins', () {
    test('one pin: chunks flow forward from pin at chunkSize stride', () {
      // wordCount=42, chunkSize=12, pin at 15.
      // Expected: 0..15 (pin), 15..27 (flow), 27..39 (flow), 39..42 (terminal).
      expect(
        computeBoundaries(pinnedEnds: const [15], wordCount: 42, chunkSize: 12),
        [0, 15, 27, 39],
      );
    });

    test('two pins: each defines exactly one chunk between them', () {
      expect(
        computeBoundaries(
          pinnedEnds: const [15, 30],
          wordCount: 42,
          chunkSize: 12,
        ),
        [0, 15, 30],
      );
    });

    test('pins out of (0, wordCount] are filtered', () {
      expect(
        computeBoundaries(
          pinnedEnds: const [-1, 0, 50],
          wordCount: 42,
          chunkSize: 12,
        ),
        [0, 12, 24, 36],
      );
    });

    test('duplicate pins are deduped', () {
      expect(
        computeBoundaries(
          pinnedEnds: const [15, 15, 15],
          wordCount: 42,
          chunkSize: 12,
        ),
        [0, 15, 27, 39],
      );
    });

    test('pin equal to wordCount terminates flow', () {
      // pin at 42 (wordCount): no chunks past pin, even though flow from 0
      // would normally produce them.
      expect(
        computeBoundaries(pinnedEnds: const [42], wordCount: 42, chunkSize: 12),
        [0],
      );
    });

    test('pin at wordCount with earlier pin', () {
      expect(
        computeBoundaries(
          pinnedEnds: const [12, 42],
          wordCount: 42,
          chunkSize: 12,
        ),
        [0, 12],
      );
    });
  });

  group('Piece.fresh + JSON', () {
    test('fresh piece has no pins (pure flow)', () {
      final p = Piece.fresh(
        id: 'x',
        title: 'T',
        body: 'one two three four five six seven eight nine ten eleven twelve thirteen',
        chunkSize: 5,
        now: DateTime.utc(2026, 1, 1),
      );
      expect(p.pinnedEnds, isEmpty);
      expect(p.boundaries(), [0, 5, 10]);
      expect(p.chunkCount, 3);
      expect(p.lastChunkIndex, 0);
    });

    test('to/from JSON preserves data', () {
      final p = Piece.fresh(
        id: 'x',
        title: 'T',
        body: 'a b c d e f',
        chunkSize: 2,
        now: DateTime.utc(2026, 1, 1),
      );
      p.pinnedEnds = [3];
      p.lastChunkIndex = 1;
      final json = p.toJson();
      final back = Piece.fromJson(Map<String, dynamic>.from(json));
      expect(back.id, p.id);
      expect(back.title, p.title);
      expect(back.body, p.body);
      expect(back.pinnedEnds, p.pinnedEnds);
      expect(back.chunkSize, p.chunkSize);
      expect(back.lastChunkIndex, p.lastChunkIndex);
    });

    test('migrates legacy "boundaries" format to "pinnedEnds"', () {
      final legacy = {
        'id': 'x',
        'title': 'T',
        'body': 'a b c d e f',
        'boundaries': [0, 2, 4],
        'chunkSize': 2,
        'lastChunkIndex': 1,
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
      };
      final p = Piece.fromJson(legacy);
      // Old boundaries [0,2,4] → all pins (since legacy treated every entry as
      // explicit). pinnedEnds drops the leading 0.
      expect(p.pinnedEnds, [2, 4]);
    });

    test('clearPins resets pins and lastChunkIndex', () {
      final p = Piece.fresh(
        id: 'x',
        title: 'T',
        body: 'a b c d',
        chunkSize: 2,
        now: DateTime.utc(2026, 1, 1),
      );
      p.pinnedEnds = [1];
      p.lastChunkIndex = 2;
      p.clearPins();
      expect(p.pinnedEnds, isEmpty);
      expect(p.lastChunkIndex, 0);
    });
  });

  group('boundary edits — pin-based, no cascade', () {
    // Mirrors _editEndBy in ReaderScreen.
    List<int> editEnd({
      required List<int> pins,
      required int currentChunk,
      required int wordCount,
      required int chunkSize,
      required int delta,
    }) {
      final boundaries = computeBoundaries(
        pinnedEnds: pins,
        wordCount: wordCount,
        chunkSize: chunkSize,
      );
      final start = boundaries[currentChunk];
      final end = currentChunk + 1 < boundaries.length
          ? boundaries[currentChunk + 1]
          : wordCount;
      final newEnd = end + delta;
      if (newEnd <= start) return List.of(pins);
      if (newEnd > wordCount) return List.of(pins);
      final next = pins.toSet()
        ..remove(end)
        ..add(newEnd);
      return next.toList()..sort();
    }

    test('+ on chunk 0 grows it; chunk 1 stays default-sized (no cascade)', () {
      // wordCount=42, chunkSize=12, no pins. + on chunk 0.
      var pins = <int>[];
      pins = editEnd(
        pins: pins,
        currentChunk: 0,
        wordCount: 42,
        chunkSize: 12,
        delta: 1,
      );
      expect(pins, [13]);
      final b = computeBoundaries(
        pinnedEnds: pins,
        wordCount: 42,
        chunkSize: 12,
      );
      // Chunk 1 should be 13..25, NOT 13..24.
      expect(b, [0, 13, 25, 37]);
    });

    test('three +s on chunk 0: pin moves, downstream still flows', () {
      var pins = <int>[];
      for (var i = 0; i < 3; i++) {
        pins = editEnd(
          pins: pins,
          currentChunk: 0,
          wordCount: 42,
          chunkSize: 12,
          delta: 1,
        );
      }
      expect(pins, [15]);
      final b = computeBoundaries(
        pinnedEnds: pins,
        wordCount: 42,
        chunkSize: 12,
      );
      expect(b, [0, 15, 27, 39]);
    });

    test('- on chunk 0 with 1 word is a no-op', () {
      // chunk 0 = 0..1 (one word). - would make it zero. No-op.
      final pins = editEnd(
        pins: const [1],
        currentChunk: 0,
        wordCount: 10,
        chunkSize: 4,
        delta: -1,
      );
      expect(pins, [1]);
    });

    test('+ on last chunk cannot extend past wordCount (no-op)', () {
      // wordCount=10, chunkSize=4 → boundaries [0,4,8]. Last chunk is index 2.
      final pins = editEnd(
        pins: const [],
        currentChunk: 2,
        wordCount: 10,
        chunkSize: 4,
        delta: 1,
      );
      expect(pins, isEmpty);
    });

    test('+ to absorb final 1-word chunk pins wordCount as terminator', () {
      // pins=[9], wordCount=10. boundaries=[0,9]. chunk 1 = 9..10 (1 word).
      // + on chunk 0 → newEnd=10 = wordCount. Pin migrates to 10.
      final pins = editEnd(
        pins: const [9],
        currentChunk: 0,
        wordCount: 10,
        chunkSize: 4,
        delta: 1,
      );
      expect(pins, [10]);
      // After: 1 chunk total, the entire body.
      final b = computeBoundaries(
        pinnedEnds: pins,
        wordCount: 10,
        chunkSize: 4,
      );
      expect(b, [0]);
    });

    test('- on a single-chunk piece (terminator pin) splits off final word', () {
      // pins=[10], wordCount=10. boundaries=[0]. - on chunk 0.
      final pins = editEnd(
        pins: const [10],
        currentChunk: 0,
        wordCount: 10,
        chunkSize: 4,
        delta: -1,
      );
      expect(pins, [9]);
      final b = computeBoundaries(
        pinnedEnds: pins,
        wordCount: 10,
        chunkSize: 4,
      );
      expect(b, [0, 9]); // chunk 0 = 0..9, chunk 1 = 9..10 (1 word).
    });

    test('+ that lands on existing pin position dedupes (drops chunk)', () {
      // pins=[5, 6], wordCount=10. boundaries=[0,5,6]. chunk 1 = 5..6 (1 word).
      // + on chunk 0 → newEnd=6, but 6 already pinned. Set dedupes; chunk 1
      // disappears.
      final pins = editEnd(
        pins: const [5, 6],
        currentChunk: 0,
        wordCount: 10,
        chunkSize: 4,
        delta: 1,
      );
      expect(pins, [6]);
      final b = computeBoundaries(
        pinnedEnds: pins,
        wordCount: 10,
        chunkSize: 4,
      );
      expect(b, [0, 6]);
    });
  });
}
