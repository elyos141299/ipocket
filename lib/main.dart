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
        // Tema branding Advan: pink magenta #EC008D.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEC008D),
        ),
        scaffoldBackgroundColor: const Color(0xFFFBF8FA),
        cardColor: Colors.white,
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
