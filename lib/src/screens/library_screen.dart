import 'package:flutter/material.dart';

import '../piece.dart';
import '../storage.dart';
import 'add_edit_screen.dart';
import 'reader_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  Future<void> _openReader(Piece piece) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(piece: piece, storage: widget.storage),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _addPiece() async {
    final piece = await Navigator.of(context).push<Piece>(
      MaterialPageRoute(
        builder: (_) => AddEditScreen(
          defaultChunkSize: widget.storage.data.defaultChunkSize,
        ),
      ),
    );
    if (piece == null) return;
    setState(() {
      widget.storage.data.pieces.insert(0, piece);
    });
    widget.storage.scheduleSave();
  }

  Future<void> _editPiece(Piece piece) async {
    final updated = await Navigator.of(context).push<Piece>(
      MaterialPageRoute(
        builder: (_) => AddEditScreen(
          defaultChunkSize: widget.storage.data.defaultChunkSize,
          existing: piece,
        ),
      ),
    );
    if (updated == null) return;
    setState(() {});
    widget.storage.scheduleSave();
  }

  Future<void> _confirmDelete(Piece piece) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete piece?'),
        content: Text('"${piece.title}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    setState(() {
      widget.storage.data.pieces.removeWhere((p) => p.id == piece.id);
    });
    widget.storage.scheduleSave();
  }

  Future<void> _showActions(Piece piece) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (action == 'edit') await _editPiece(piece);
    if (action == 'delete') await _confirmDelete(piece);
  }

  @override
  Widget build(BuildContext context) {
    final pieces = widget.storage.data.pieces;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chonker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(storage: widget.storage),
                ),
              );
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: pieces.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No pieces yet.\nTap + to add one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          : ListView.separated(
              itemCount: pieces.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = pieces[i];
                return ListTile(
                  title: Text(
                    p.title.isEmpty ? '(untitled)' : p.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    p.firstLinePreview(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    '${p.chunkCount}',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  onTap: () => _openReader(p),
                  onLongPress: () => _showActions(p),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPiece,
        child: const Icon(Icons.add),
      ),
    );
  }
}
