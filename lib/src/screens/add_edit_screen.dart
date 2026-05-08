import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../piece.dart';

class AddEditScreen extends StatefulWidget {
  const AddEditScreen({
    super.key,
    required this.defaultChunkSize,
    this.existing,
  });

  final int defaultChunkSize;
  final Piece? existing;

  @override
  State<AddEditScreen> createState() => _AddEditScreenState();
}

class _AddEditScreenState extends State<AddEditScreen> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _chunk;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _body = TextEditingController(text: e?.body ?? '');
    _chunk = TextEditingController(
      text: e == null ? '' : e.chunkSize.toString(),
    );
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _chunk.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    final body = _body.text;
    if (body.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Body cannot be empty.')),
      );
      return;
    }
    final overrideText = _chunk.text.trim();
    final chunkSize = overrideText.isEmpty
        ? widget.defaultChunkSize
        : (int.tryParse(overrideText) ?? widget.defaultChunkSize);
    if (chunkSize < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chunk size must be at least 1.')),
      );
      return;
    }

    final existing = widget.existing;
    if (existing == null) {
      final piece = Piece.fresh(
        id: const Uuid().v4(),
        title: title,
        body: body,
        chunkSize: chunkSize,
      );
      Navigator.of(context).pop(piece);
      return;
    }

    final bodyChanged = existing.body != body;
    existing.title = title;
    existing.body = body;
    existing.chunkSize = chunkSize;
    existing.updatedAt = DateTime.now().toUtc();
    // Body change invalidates pin word-indices. ChunkSize change does NOT —
    // pins are absolute word indices, and unpinned regions just re-flow at
    // the new size.
    if (bodyChanged) {
      existing.clearPins();
    }
    Navigator.of(context).pop(existing);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit piece' : 'New piece'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _body,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Body',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.multiline,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _chunk,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Chunk size override',
                hintText: 'Default: ${widget.defaultChunkSize}',
                border: const OutlineInputBorder(),
              ),
            ),
            if (isEdit) ...[
              const SizedBox(height: 8),
              Text(
                'Editing the body resets pinned chunk edits. Chunk size '
                'changes preserve pins (only flow-regions re-flow).',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
