import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../chunker.dart';
import '../piece.dart';
import '../storage.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({
    super.key,
    required this.piece,
    required this.storage,
  });

  final Piece piece;
  final StorageService storage;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  static const _bg = Color(0xFF000000);
  static const _fg = Color(0xFFF0F0F0);

  late final List<String> _words;
  late final Map<int, String> _lineBreaks;
  late List<int> _boundaries;
  late final PageController _controller;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _words = splitWords(widget.piece.body);
    _lineBreaks = computeLineBreaks(widget.piece.body);
    _recomputeBoundaries();
    final clamped = widget.piece.lastChunkIndex.clamp(
      0,
      _boundaries.isEmpty ? 0 : _boundaries.length - 1,
    );
    _currentPage = clamped;
    widget.piece.lastChunkIndex = clamped;
    _controller = PageController(initialPage: clamped);

    WakelockPlus.enable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    WakelockPlus.disable();
    widget.storage.flush();
    super.dispose();
  }

  void _recomputeBoundaries() {
    _boundaries = computeBoundaries(
      pinnedEnds: widget.piece.pinnedEnds,
      wordCount: _words.length,
      chunkSize: widget.piece.chunkSize,
    );
  }

  static const _markerStyle = TextStyle(color: Color(0x55F0F0F0));

  TextSpan _chunkSpan(int idx) {
    final r = chunkRange(
      boundaries: _boundaries,
      chunkIndex: idx,
      wordCount: _words.length,
    );
    if (r.start >= r.end) return const TextSpan(text: '');
    final children = <InlineSpan>[TextSpan(text: _words[r.start])];
    for (var i = r.start + 1; i < r.end; i++) {
      final brk = _lineBreaks[i];
      if (brk != null) {
        children.add(TextSpan(
          text: brk == '\n\n' ? ' ¶ ' : ' / ',
          style: _markerStyle,
        ));
      } else {
        children.add(const TextSpan(text: ' '));
      }
      children.add(TextSpan(text: _words[i]));
    }
    return TextSpan(children: children);
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
      widget.piece.lastChunkIndex = page;
      widget.piece.updatedAt = DateTime.now().toUtc();
    });
    widget.storage.scheduleSave();
  }

  // Edits the end of the current chunk by [delta] (+1 or -1) and updates pins.
  // Chunks past the edit re-flow at chunkSize (until the next pin), so they
  // don't cascade-shrink.
  //
  // The "end" of the current chunk is `boundaries[n+1]` when present; for the
  // last chunk it is implicitly `wordCount`. A pin at `wordCount` is allowed
  // and acts as a flow-terminator (see chunker.dart).
  void _editEndBy(int delta) {
    final n = _currentPage;
    final start = _boundaries[n];
    final end = (n + 1 < _boundaries.length)
        ? _boundaries[n + 1]
        : _words.length;
    final newEnd = end + delta;

    if (newEnd <= start) return; // chunks must have ≥ 1 word
    if (newEnd > _words.length) return; // can't extend past end of body

    // Freeze all preceding chunk boundaries as pins so that adding a pin for
    // the current chunk doesn't let flow collapse pages 0..n-1 into one chunk.
    final pins = widget.piece.pinnedEnds.toSet();
    for (var k = 1; k <= n; k++) {
      pins.add(_boundaries[k]);
    }
    pins
      ..remove(end)
      ..add(newEnd);
    widget.piece.pinnedEnds = pins.toList()..sort();
    widget.piece.updatedAt = DateTime.now().toUtc();
    _recomputeBoundaries();

    // Clamp current page if the edit collapsed chunks below it.
    if (_currentPage >= _boundaries.length) {
      _currentPage = _boundaries.length - 1;
      widget.piece.lastChunkIndex = _currentPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(_currentPage);
        }
      });
    }
    setState(() {});
    widget.storage.scheduleSave();
  }

  void _shrink() => _editEndBy(-1);
  void _grow() => _editEndBy(1);

  Future<void> _jumpToPage() async {
    final controller =
        TextEditingController(text: (_currentPage + 1).toString());
    final total = _boundaries.length;
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Jump to chunk'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'Chunk number (1 – $total)'),
          onSubmitted: (s) {
            final v = int.tryParse(s);
            if (v == null) return;
            Navigator.of(ctx).pop(v - 1);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v == null) return;
              Navigator.of(ctx).pop(v - 1);
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
    if (target == null) return;
    final clamped = target.clamp(0, total - 1);
    _controller.jumpToPage(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final total = _boundaries.length;
    final hasContent = total > 0 && _words.isNotEmpty;

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(
          children: [
            if (hasContent)
              PageView.builder(
                controller: _controller,
                itemCount: total,
                onPageChanged: _onPageChanged,
                itemBuilder: (_, i) => _ChunkView(span: _chunkSpan(i)),
              )
            else
              const Center(
                child: Text(
                  '(empty piece)',
                  style: TextStyle(color: _fg, fontSize: 20),
                ),
              ),

            // Page counter (top-center, low opacity, long-press to jump).
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onLongPress: hasContent ? _jumpToPage : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      hasContent ? '${_currentPage + 1} / $total' : '0 / 0',
                      style: TextStyle(
                        color: _fg.withValues(alpha: 0.4),
                        fontSize: 14,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // − bottom-left
            Positioned(
              left: 4,
              bottom: 4,
              child: _RoundButton(
                icon: Icons.remove,
                onTap: hasContent ? _shrink : null,
              ),
            ),

            // + bottom-right
            Positioned(
              right: 4,
              bottom: 4,
              child: _RoundButton(
                icon: Icons.add,
                onTap: hasContent ? _grow : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Single chunk laid out to fill nearly all available area. Padding is small
/// (text passes behind the corner buttons; the buttons' soft circles still
/// keep them visible).
class _ChunkView extends StatelessWidget {
  const _ChunkView({required this.span});

  final TextSpan span;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 28, 12, 28),
      child: SizedBox.expand(
        child: AutoSizeText.rich(
          span,
          textAlign: TextAlign.center,
          // Many lines allowed: lets the algorithm grow the font to fill
          // vertical space when chunks have lots of words. Without this,
          // a low maxLines caps height usage and leaves big margins.
          maxLines: 40,
          minFontSize: 18,
          stepGranularity: 1,
          // Never break a word across lines. Without this, AutoSizeText treats
          // a mid-word wrap (e.g. "abrepta" / "s") as a valid fit and keeps the
          // font large; instead, shrink the font until the longest word fits on
          // a single line. There is no continuation hyphen, so broken words are
          // silently misleading.
          wrapWords: false,
          style: const TextStyle(
            color: Color(0xFFF0F0F0),
            fontSize: 360, // upper bound; auto_size shrinks to fit
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 56,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 32,
              color: const Color(0xFFF0F0F0),
            ),
          ),
        ),
      ),
    );
  }
}
