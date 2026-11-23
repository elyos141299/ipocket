import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'settings/adv_firewall_page.dart';
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

/// Tab Pengaturan v2.0 — HUB bergaya Settings iPhone: grup-grup
/// berisi baris ikon + judul + chevron; tiap baris membuka
/// sub-halaman sendiri. Isi grup mengikuti paritas WebUI
/// (Gelombang B/C/D, FULL-SPEC-BCD.md):
/// Wi-Fi, Jaringan, Perangkat Terhubung, Lanjutan, Sistem.
/// Pengaturan aplikasi (gateway) tetap di sini seperti sebelumnya.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _gwController;

  @override
  void initState() {
    super.initState();
    _gwController = TextEditingController(text: AppState.instance.gateway);
  }

  @override
  void dispose() {
    _gwController.dispose();
    super.dispose();
  }

  void _open(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

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
                          'Masuk dulu di tab Status untuk membuka '
                          'pengaturan perangkat.',
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
                  onTap: () => _open(const WifiQuickPage()),
                ),
                HubRow(
                  icon: Icons.wifi,
                  title: 'Wi-Fi Utama',
                  subtitle: 'SSID, sandi, keamanan, batas akses',
                  onTap: () => _open(const WifiMainPage()),
                ),
                HubRow(
                  icon: Icons.tune,
                  title: 'Wi-Fi Lanjutan',
                  subtitle: 'Negara, kanal, batas akses',
                  onTap: () => _open(const WifiAdvancedPage()),
                ),
                HubRow(
                  icon: Icons.wifi_protected_setup,
                  title: 'WPS',
                  subtitle: 'Sambung perangkat dengan PIN / PBC',
                  onTap: () => _open(const WifiWpsPage()),
                ),
                HubRow(
                  icon: Icons.filter_alt_outlined,
                  title: 'Filter MAC',
                  subtitle: 'Daftar putih / daftar hitam perangkat',
                  onTap: () => _open(const WifiMacPage()),
                ),
                HubRow(
                  icon: Icons.battery_saver_outlined,
                  title: 'Hemat Daya',
                  subtitle: 'Cakupan Wi-Fi & waktu tidur',
                  onTap: () => _open(const WifiPowerPage()),
                ),
              ],
            ),
            const SectionLabel('Jaringan'),
            HubGroup(
              children: <Widget>[
                HubRow(
                  icon: Icons.settings_ethernet,
                  title: 'Mode Koneksi',
                  subtitle: 'Otomatis / manual & roaming',
                  onTap: () => _open(const NetModePage()),
                ),
                HubRow(
                  icon: Icons.cell_tower,
                  title: 'Pilih Jaringan',
                  subtitle: 'Pindai & pilih operator manual',
                  onTap: () => _open(const NetSelectPage()),
                ),
                HubRow(
                  icon: Icons.public,
                  title: 'APN',
                  subtitle: 'Profil akses internet operator',
                  onTap: () => _open(const NetApnPage()),
                ),
                HubRow(
                  icon: Icons.data_usage,
                  title: 'Manajemen Data',
                  subtitle: 'Batas pemakaian & peringatan',
                  onTap: () => _open(const NetDataPage()),
                ),
              ],
            ),
            const SectionLabel('Perangkat'),
            HubGroup(
              children: <Widget>[
                HubRow(
                  icon: Icons.devices,
                  title: 'Perangkat Terhubung',
                  subtitle: 'Daftar klien, blokir & ganti nama',
                  onTap: () => _open(const DevicesPage()),
                ),
              ],
            ),
            const SectionLabel('Lanjutan'),
            HubGroup(
              children: <Widget>[
                HubRow(
                  icon: Icons.router,
                  title: 'Router & DHCP',
                  subtitle: 'IP LAN, netmask, server DHCP',
                  onTap: () => _open(const AdvRouterPage()),
                ),
                HubRow(
                  icon: Icons.security,
                  title: 'Firewall',
                  subtitle: 'Filter port, forwarding, DMZ, URL, UPnP',
                  onTap: () => _open(const AdvFirewallPage()),
                ),
                HubRow(
                  icon: Icons.schedule,
                  title: 'Waktu (SNTP)',
                  subtitle: 'Sinkronisasi waktu perangkat',
                  onTap: () => _open(const AdvSntpPage()),
                ),
                HubRow(
                  icon: Icons.sim_card_outlined,
                  title: 'PIN SIM',
                  subtitle: 'Status PIN & sisa upaya (baca-saja)',
                  onTap: () => _open(const AdvPinPage()),
                ),
                HubRow(
                  icon: Icons.system_update_alt,
                  title: 'Pembaruan Firmware',
                  subtitle: 'Periksa & atur pembaruan otomatis',
                  onTap: () => _open(const AdvFotaPage()),
                ),
              ],
            ),
            const SectionLabel('Sistem'),
            HubGroup(
              children: <Widget>[
                HubRow(
                  icon: Icons.power_settings_new,
                  title: 'Sistem & Perangkat',
                  subtitle: 'Info, mulai ulang, matikan, reset, sandi',
                  onTap: () => _open(const SystemPage()),
                ),
              ],
            ),
            const SectionLabel('Aplikasi'),
            FormCard(
              children: <Widget>[
                SettingsTextField(
                  controller: _gwController,
                  label: 'Alamat gateway MiFi',
                  helper: 'Contoh: 192.168.0.1 — alamat MiFi di jaringanmu.',
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: AppSpace.md),
                FilledButton.icon(
                  onPressed: () {
                    state.setGateway(_gwController.text);
                    showSnack(
                      context,
                      'Gateway disimpan (hanya selama aplikasi berjalan).',
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Simpan Gateway'),
                ),
                const SizedBox(height: AppSpace.md),
                const Text(
                  'Catatan: gateway dan kata sandi admin tidak disimpan '
                  'permanen. Keduanya kembali ke nilai awal '
                  '(192.168.0.1 / admin) setiap aplikasi ditutup.',
                  style: AppText.hint,
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
