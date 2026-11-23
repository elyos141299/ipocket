import 'package:flutter/material.dart';

import 'screens/app_shell.dart';

void main() {
  runApp(const IPocketApp());
}

class IPocketApp extends StatelessWidget {
  const IPocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iPocket',
      theme: ThemeData(
        // Tema biru muda sesuai UI-REFERENCE.md.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0288D1),
        ),
        scaffoldBackgroundColor: const Color(0xFFF2F9FE),
        cardColor: Colors.white,
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
