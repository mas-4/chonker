import 'package:flutter/material.dart';

import '../storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.storage});

  final StorageService storage;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _chunk;

  @override
  void initState() {
    super.initState();
    _chunk = TextEditingController(
      text: widget.storage.data.defaultChunkSize.toString(),
    );
  }

  @override
  void dispose() {
    _chunk.dispose();
    super.dispose();
  }

  void _save() {
    final v = int.tryParse(_chunk.text.trim());
    if (v == null || v < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a positive integer.')),
      );
      return;
    }
    widget.storage.data.defaultChunkSize = v;
    widget.storage.scheduleSave();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _chunk,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Default chunk size (words)',
                helperText: 'Applied to newly added pieces.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
