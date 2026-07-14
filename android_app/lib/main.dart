import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(const ClipSyncApp());
}

class ClipSyncApp extends StatelessWidget {
  const ClipSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ClipSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
