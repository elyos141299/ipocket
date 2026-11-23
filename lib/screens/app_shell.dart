import 'package:flutter/material.dart';

import '../theme.dart';
import 'diagnostics_screen.dart';
import 'settings_screen.dart';
import 'sms_screen.dart';
import 'status_screen.dart';

/// Kerangka utama v3.0: AppBar bermerek + navigasi bawah 4 tab
/// ala tpMiFi — Beranda, Tools, SMS, Diagnostik. (Tab "Pengaturan"
/// v2.0 menjadi Tools; tab Status menjadi Beranda.)
///
/// v3.1.1: judul app bar bukan lagi teks polos — ada marka
/// Logo A kecil + wordmark "iPocket" tebal, konsisten di semua
/// tab. Perpindahan tab kini memudar + bergeser tipis (Stack +
/// AnimatedOpacity/AnimatedSlide, keadaan tiap tab tetap
/// tersimpan seperti IndexedStack lama lewat Offstage).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      // `active` memberi tahu Beranda kapan tab-nya tampil,
      // untuk menyalakan/mematikan auto-refresh 2 detik.
      StatusScreen(active: _index == 0),
      // Tile SMS/Diagnostik di grid Tools melompat ke tab
      // terkait lewat callback ini.
      ToolsScreen(onJumpToTab: (i) => setState(() => _index = i)),
      const SmsScreen(),
      const DiagnosticsScreen(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AppLogoMark(size: 28),
            const SizedBox(width: 10),
            const Text(
              'iPocket',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: <Widget>[
          for (var i = 0; i < screens.length; i++)
            Offstage(
              offstage: i != _index,
              child: TickerMode(
                enabled: i == _index,
                child: AnimatedOpacity(
                  opacity: i == _index ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: AnimatedSlide(
                    offset:
                        i == _index ? Offset.zero : const Offset(0, 0.015),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: screens[i],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        // Tab bar navy Ookla (v3.0): latar #0A0F28, indikator &
        // ikon aktif cyan, ikon nonaktif biru redup.
        backgroundColor: AppColors.tabBar,
        indicatorColor: AppColors.panel,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppColors.textFaint),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined,
                color: AppColors.textFaint),
            selectedIcon:
                Icon(Icons.grid_view, color: AppColors.primary),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.sms_outlined, color: AppColors.textFaint),
            selectedIcon: Icon(Icons.sms, color: AppColors.primary),
            label: 'SMS',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal, color: AppColors.textFaint),
            selectedIcon: Icon(Icons.terminal, color: AppColors.primary),
            label: 'Diagnostik',
          ),
        ],
      ),
    );
  }
}
