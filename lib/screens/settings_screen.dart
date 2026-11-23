import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'settings/adv_firewall_page.dart';
import 'settings/app_gateway_page.dart';
import 'settings/adv_fota_page.dart';
import 'settings/adv_pin_page.dart';
import 'settings/adv_router_page.dart';
import 'settings/adv_sntp_page.dart';
import 'settings/devices_page.dart';
import 'settings/net_apn_page.dart';
import 'settings/net_data_page.dart';
import 'settings/net_mode_page.dart';
import 'settings/net_select_page.dart';
import 'settings/system_page.dart';
import 'settings/wifi_advanced_page.dart';
import 'settings/wifi_mac_page.dart';
import 'settings/wifi_main_page.dart';
import 'settings/wifi_power_page.dart';
import 'settings/wifi_quick_page.dart';
import 'settings/wifi_wps_page.dart';

void _openPage(BuildContext context, Widget page) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => page),
  );
}

/// Tab Tools v3.0 (dulu tab "Pengaturan" v2.0) — meniru struktur
/// tpMiFi: grid ikon 4 kolom menuju grup-grup pengaturan.
/// Isi & perilaku sub-halamannya IDENTIK v2.0.2 (paritas WebUI
/// Gelombang B/C/D); yang berubah hanya kulit & tata letak.
/// Tile SMS / Diagnostik melompat ke tab yang bersangkutan lewat
/// [onJumpToTab] dari AppShell (indeks tab: 2 = SMS, 3 =
/// Diagnostik).
///
/// v3.1.1: formulir gateway TIDAK lagi menempel di bawah grid
/// (terlihat seperti tempelan + label field menimpa tepi) —
/// kini tile "Gateway" membuka halaman khusus AppGatewayPage.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key, this.onJumpToTab});

  final ValueChanged<int>? onJumpToTab;

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
                          'pengaturan perangkat.',
                          style: AppText.rowSubtitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SectionLabel('Tools', top: AppSpace.sm),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
              children: <Widget>[
                _toolTile(
                  icon: Icons.wifi,
                  label: 'Wi-Fi',
                  onTap: () => _openPage(context, const _WifiHubPage()),
                ),
                _toolTile(
                  icon: Icons.public,
                  label: 'Jaringan',
                  onTap: () => _openPage(context, const _NetHubPage()),
                ),
                _toolTile(
                  icon: Icons.devices,
                  label: 'Perangkat',
                  onTap: () => _openPage(context, const DevicesPage()),
                ),
                _toolTile(
                  icon: Icons.battery_saver_outlined,
                  label: 'Baterai',
                  onTap: () => _openPage(context, const WifiPowerPage()),
                ),
                _toolTile(
                  icon: Icons.security,
                  label: 'Firewall',
                  onTap: () =>
                      _openPage(context, const AdvFirewallPage()),
                ),
                _toolTile(
                  icon: Icons.settings,
                  label: 'Sistem',
                  onTap: () => _openPage(context, const _SystemHubPage()),
                ),
                _toolTile(
                  icon: Icons.sms,
                  label: 'SMS',
                  onTap: () => onJumpToTab?.call(2),
                ),
                _toolTile(
                  icon: Icons.terminal,
                  label: 'Diagnostik',
                  onTap: () => onJumpToTab?.call(3),
                ),
                _toolTile(
                  icon: Icons.router,
                  label: 'Gateway',
                  onTap: () =>
                      _openPage(context, const AppGatewayPage()),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
          ],
        );
      },
    );
  }

  /// Satu tile grid Tools ala tpMiFi: kotak navy membulat bertepi
  /// berisi ikon cyan, label kecil di bawahnya.
  /// v3.1.1: dibungkus PressScale — tile menyusut tipis (0,97)
  /// saat ditekan, di atas ripple InkWell-nya.
  Widget _toolTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return PressScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kerangka halaman hub: daftar HubRow dalam satu HubGroup —
/// dipakai hub Wi-Fi, Jaringan, dan Sistem.
class _HubPage extends StatelessWidget {
  const _HubPage({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: AppSpace.page,
        children: <Widget>[HubGroup(children: rows)],
      ),
    );
  }
}

/// Hub Wi-Fi: sub-halaman Wi-Fi v2.0 yang sama persis.
class _WifiHubPage extends StatelessWidget {
  const _WifiHubPage();

  @override
  Widget build(BuildContext context) {
    return _HubPage(
      title: 'Wi-Fi',
      rows: <Widget>[
        HubRow(
          icon: Icons.rocket_launch_outlined,
          title: 'Pengaturan Cepat',
          subtitle: 'Wizard APN + Wi-Fi sekali jalan',
          onTap: () => _openPage(context, const WifiQuickPage()),
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
          onTap: () => _openPage(context, const WifiAdvancedPage()),
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
    );
  }
}

/// Hub Jaringan: sub-halaman jaringan v2.0 yang sama persis
/// (Router & DHCP ikut grup ini agar tidak ada fitur hilang).
class _NetHubPage extends StatelessWidget {
  const _NetHubPage();

  @override
  Widget build(BuildContext context) {
    return _HubPage(
      title: 'Jaringan',
      rows: <Widget>[
        HubRow(
          icon: Icons.settings_ethernet,
          title: 'Mode Koneksi',
          subtitle: 'Otomatis / manual & roaming',
          onTap: () => _openPage(context, const NetModePage()),
        ),
        HubRow(
          icon: Icons.cell_tower,
          title: 'Pilih Jaringan',
          subtitle: 'Pindai & pilih operator manual',
          onTap: () => _openPage(context, const NetSelectPage()),
        ),
        HubRow(
          icon: Icons.public,
          title: 'APN',
          subtitle: 'Profil akses internet operator',
          onTap: () => _openPage(context, const NetApnPage()),
        ),
        HubRow(
          icon: Icons.data_usage,
          title: 'Manajemen Data',
          subtitle: 'Batas pemakaian & peringatan',
          onTap: () => _openPage(context, const NetDataPage()),
        ),
        HubRow(
          icon: Icons.router,
          title: 'Router & DHCP',
          subtitle: 'IP LAN, netmask, server DHCP',
          onTap: () => _openPage(context, const AdvRouterPage()),
        ),
      ],
    );
  }
}

/// Hub Sistem: Info Perangkat & daya & sandi (satu halaman
/// SystemPage v2.0) + SNTP, PIN SIM, Pembaruan Firmware.
class _SystemHubPage extends StatelessWidget {
  const _SystemHubPage();

  @override
  Widget build(BuildContext context) {
    return _HubPage(
      title: 'Sistem',
      rows: <Widget>[
        HubRow(
          icon: Icons.power_settings_new,
          title: 'Sistem & Perangkat',
          subtitle: 'Info, mulai ulang, matikan, reset, sandi',
          onTap: () => _openPage(context, const SystemPage()),
        ),
        HubRow(
          icon: Icons.schedule,
          title: 'Waktu (SNTP)',
          subtitle: 'Sinkronisasi waktu perangkat',
          onTap: () => _openPage(context, const AdvSntpPage()),
        ),
        HubRow(
          icon: Icons.sim_card_outlined,
          title: 'PIN SIM',
          subtitle: 'Status PIN & sisa upaya (baca-saja)',
          onTap: () => _openPage(context, const AdvPinPage()),
        ),
        HubRow(
          icon: Icons.system_update_alt,
          title: 'Pembaruan Firmware',
          subtitle: 'Periksa & atur pembaruan otomatis',
          onTap: () => _openPage(context, const AdvFotaPage()),
        ),
      ],
    );
  }
}
