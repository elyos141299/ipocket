import 'package:flutter/material.dart';

import '../theme.dart';
import 'sms_screen.dart';
import 'status_screen.dart';
import 'wifi_screen.dart';

/// Kerangka utama v4.0 (SUPER SIMPEL) — AppBar bermerek +
/// navigasi bawah 3 tab SAJA: Beranda, Wi-Fi, SMS. (Keputusan
/// user: aplikasi dipangkas habis; tab Tools & Diagnostik
/// v3.x HILANG, begitu pula seluruh hub Jaringan/Firewall/
/// Sistem/Gateway/Hemat Daya dari aplikasi.)
///
/// Judul app bar: marka Logo A kecil + wordmark "iPocket"
/// tebal (w800), konsisten di semua tab (v3.1.1).
/// Perpindahan tab memudar + bergeser tipis (Stack +
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
      const WifiScreen(),
      const SmsScreen(),
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
        // Tab bar v4.0: latar navy pekat + indikator aktif
        // berbentuk PIL cyan transparan (Material You) dari
        // navigationBarTheme; ikon aktif cyan, nonaktif redup.
        backgroundColor: AppColors.tabBar,
        height: 68,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: AppColors.textFaint),
            selectedIcon: Icon(Icons.home, color: AppColors.primary),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_outlined, color: AppColors.textFaint),
            selectedIcon: Icon(Icons.wifi, color: AppColors.primary),
            label: 'Wi-Fi',
          ),
          NavigationDestination(
            icon: Icon(Icons.sms_outlined, color: AppColors.textFaint),
            selectedIcon: Icon(Icons.sms, color: AppColors.primary),
            label: 'SMS',
          ),
        ],
      ),
    );
  }
}
