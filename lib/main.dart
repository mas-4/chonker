import 'package:flutter/material.dart';

import 'src/screens/library_screen.dart';
import 'src/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.load();
  runApp(ChonkerApp(storage: storage));
}

class ChonkerApp extends StatelessWidget {
  const ChonkerApp({super.key, required this.storage});

  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chonker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF888888),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF101010),
      ),
      home: LibraryScreen(storage: storage),
    );
  }
}
