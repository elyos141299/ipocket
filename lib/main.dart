import 'package:flutter/material.dart';

import 'screens/app_shell.dart';
import 'theme.dart';

void main() {
  runApp(const IPocketApp());
}

class IPocketApp extends StatelessWidget {
  const IPocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iPocket',
      // Tema v3.0: token desain terpusat di theme.dart — rombak
      // total gaya tpMiFi + palet Speedtest by Ookla (navy gelap,
      // aksen cyan). Lihat AppColors/AppSpace/AppRadius.
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}
