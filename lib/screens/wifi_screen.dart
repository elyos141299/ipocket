import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'settings/wifi_advanced_page.dart';
import 'settings/wifi_mac_page.dart';
import 'settings/wifi_main_page.dart';
import 'settings/wifi_quick_page.dart';
import 'settings/wifi_wps_page.dart';

void _openPage(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => page),
  );
}

/// Tab Wi-Fi v4.0 (SUPER SIMPEL) — dulu hub Wi-Fi di dalam tab
/// Tools v3.x; kini berdiri sebagai tab sendiri. Isinya daftar
/// halaman pengaturan Wi-Fi yang sama persis seperti sebelumnya:
/// Pengaturan Cepat, Wi-Fi Utama, Wi-Fi Lanjutan, WPS, Filter
/// MAC — perilaku & wire kelima halaman TIDAK berubah.
class WifiScreen extends StatelessWidget {
  const WifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return ListView(
          padding: AppSpace.page,
          children: <Widget>[
            if (!state.loggedIn)
              const Card(
                child: Padding(
                  padding: AppSpace.cardInner,
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.lock_outline, color: AppColors.accent),
                      SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          'Masuk dulu di tab Beranda untuk membuka '
                          'pengaturan Wi-Fi.',
                          style: AppText.rowSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SectionLabel('Wi-Fi', top: AppSpace.sm),
            HubGroup(
              children: <Widget>[
                HubRow(
                  icon: Icons.rocket_launch_outlined,
                  title: 'Pengaturan Cepat',
                  subtitle: 'Wizard APN + Wi-Fi sekali jalan',
                  onTap: () =>
                      _openPage(context, const WifiQuickPage()),
                ),
                HubRow(
                  icon: Icons.wifi,
                  title: 'Wi-Fi Utama',
                  subtitle: 'SSID, sandi, keamanan, batas akses',
                  onTap: () => _openPage(context, const WifiMainPage()),
                ),
                HubRow(
                  icon: Icons.tune,
                  title: 'Wi-Fi Lanjutan',
                  subtitle: 'Negara, kanal, batas akses',
                  onTap: () =>
                      _openPage(context, const WifiAdvancedPage()),
                ),
                HubRow(
                  icon: Icons.wifi_protected_setup,
                  title: 'WPS',
                  subtitle: 'Sambung perangkat dengan PIN / PBC',
                  onTap: () => _openPage(context, const WifiWpsPage()),
                ),
                HubRow(
                  icon: Icons.filter_alt_outlined,
                  title: 'Filter MAC',
                  subtitle: 'Daftar putih / daftar hitam perangkat',
                  onTap: () => _openPage(context, const WifiMacPage()),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
          ],
        );
      },
    );
  }
}
