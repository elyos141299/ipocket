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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
