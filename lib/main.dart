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
      // Tema v2.0: token desain terpusat di theme.dart — GELAP +
      // PUTIH (keputusan user sejak v1.4), pink Advan #EC008D
      // hanya aksen kecil. Lihat AppColors/AppSpace/AppRadius.
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}
