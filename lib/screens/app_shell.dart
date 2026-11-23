import 'package:flutter/material.dart';

import 'diagnostics_screen.dart';
import 'settings_screen.dart';
import 'sms_screen.dart';
import 'status_screen.dart';

/// Kerangka utama: AppBar "iPocket" + navigasi bawah 4 tab.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('iPocket')),
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          // `active` memberi tahu dashboard kapan tab-nya tampil,
          // untuk menyalakan/mematikan auto-refresh 5 detik.
          StatusScreen(active: _index == 0),
          const SmsScreen(),
          const DiagnosticsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        // Tab bar tema gelap v1.4: latar panel gelap, indikator
        // aktif pink Advan, ikon & label putih (redup saat tidak
        // aktif, putih penuh saat aktif).
        backgroundColor: const Color(0xFF1E1A24),
        indicatorColor: const Color(0xFFEC008D),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.signal_cellular_alt, color: Colors.white60),
            selectedIcon:
                Icon(Icons.signal_cellular_alt, color: Colors.white),
            label: 'Status',
          ),
          NavigationDestination(
            icon: Icon(Icons.sms, color: Colors.white60),
            selectedIcon: Icon(Icons.sms, color: Colors.white),
            label: 'SMS',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal, color: Colors.white60),
            selectedIcon: Icon(Icons.terminal, color: Colors.white),
            label: 'Diagnostik',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings, color: Colors.white60),
            selectedIcon: Icon(Icons.settings, color: Colors.white),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
