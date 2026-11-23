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
        // Tema v1.4: GELAP + PUTIH (permintaan user 23 Nov 2026 —
        // tema terang v1.2/v1.3 kurang disukai). Latar sangat
        // gelap, kartu/panel gelap, teks putih mengikuti skema
        // gelap. Pink Advan #EC008D hanya aksen kecil lewat seed:
        // tombol utama, state aktif, toggle ON, fokus field,
        // indikator progres.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEC008D),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121016),
        cardColor: const Color(0xFF1E1A24),
        dividerColor: const Color(0x1FFFFFFF),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF262030),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        useMaterial3: true,
      ),
      home: const AppShell(),
    );
  }
}
