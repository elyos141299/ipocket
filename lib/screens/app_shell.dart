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
          // untuk menyalakan/mematikan auto-refresh 15 detik.
          StatusScreen(active: _index == 0),
          const SmsScreen(),
          const DiagnosticsScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.signal_cellular_alt),
            label: 'Status',
          ),
          NavigationDestination(
            icon: Icon(Icons.sms),
            label: 'SMS',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal),
            label: 'Diagnostik',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }
}
