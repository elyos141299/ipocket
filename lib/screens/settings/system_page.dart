import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Sistem & Perangkat (D18): Info Perangkat, Mulai Ulang
/// (REBOOT_DEVICE {}), Matikan (TURN_OFF_DEVICE {}), Setel Ulang
/// Pabrik (RESTORE_FACTORY_SETTINGS {}), dan Ganti Kata Sandi
/// Admin (CHANGE_PASSWORD — sudah ada sejak Gelombang A).
/// Semua perintah daya tanpa field, persis FULL-SPEC-BCD D18.
class SystemPage extends StatefulWidget {
  const SystemPage({super.key});

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  late final TextEditingController _oldPwController;
  late final TextEditingController _newPwController;
  late final TextEditingController _confirmPwController;
  bool _showOld = false;
  bool _showNew = false;

  RawMap? _extra;
  bool _loadingInfo = true;

  @override
  void initState() {
    super.initState();
    _oldPwController = TextEditingController();
    _newPwController = TextEditingController();
    _confirmPwController = TextEditingController();
    _loadInfo();
  }

  @override
  void dispose() {
    _oldPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  Future<void> _loadInfo() async {
    try {
      final x = await AppState.instance.api.getDeviceInfoExtra();
      if (!mounted) return;
      setState(() {
        _extra = x;
        _loadingInfo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingInfo = false);
    }
  }

  String _firstOf(List<String> keys) {
    final x = _extra;
    if (x == null) return '—';
    for (final k in keys) {
      final v = x.s(k);
      if (v != null) return v;
    }
    return '—';
  }

  Future<void> _reboot(AppState state) async {
    final ok = await confirmAction(
      context,
      title: 'Mulai ulang MiFi?',
      body: 'Perangkat akan MATI lalu menyala lagi (±1 menit). '
          'Koneksi internet dan WiFi iPocket terputus selama itu, '
          'dan sesi aplikasi ini kemungkinan berakhir. Lanjutkan?',
      actionLabel: 'Mulai Ulang',
    );
    if (!ok) return;
    showSnack(context, await state.rebootDevice());
  }

  Future<void> _turnOff(AppState state) async {
    final ok = await confirmAction(
      context,
      title: 'Matikan MiFi?',
      body: 'Perangkat akan MATI TOTAL dan aplikasi kehilangan '
          'koneksi. Menyalakannya lagi harus manual lewat tombol '
          'power di MiFi. Lanjutkan?',
      actionLabel: 'Matikan',
      danger: true,
    );
    if (!ok) return;
    showSnack(context, await state.turnOffDevice());
  }

  Future<void> _restore(AppState state) async {
    final ok1 = await confirmAction(
      context,
      title: 'Setel ulang pabrik?',
      body: 'SEMUA pengaturan MiFi kembali ke awal pabrik: nama & '
          'sandi WiFi, sandi admin, APN, dan semua pengaturan '
          'halaman ini akan HILANG. Perangkat lalu mulai ulang. '
          'Lanjutkan?',
      actionLabel: 'Lanjut',
      danger: true,
    );
    if (!ok1 || !mounted) return;
    final ok2 = await confirmAction(
      context,
      title: 'Yakin benar-benar reset?',
      body: 'Ini tidak bisa dibatalkan. Setelah reset kamu harus '
          'menyambung ke WiFi bawaan perangkat dan mengatur ulang '
          'dari awal.',
      actionLabel: 'Ya, Reset Pabrik',
      danger: true,
    );
    if (!ok2) return;
    showSnack(context, await state.restoreFactory());
  }

  Future<void> _changePassword(AppState state) async {
    final oldPw = _oldPwController.text;
    final newPw = _newPwController.text;
    final confirmPw = _confirmPwController.text;
    if (oldPw.isEmpty || newPw.isEmpty) {
      showSnack(context, 'Kata sandi lama dan baru wajib diisi.');
      return;
    }
    if (newPw != confirmPw) {
      showSnack(context, 'Konfirmasi kata sandi baru tidak sama.');
      return;
    }
    if (newPw == oldPw) {
      showSnack(context, 'Kata sandi baru harus berbeda dari yang lama.');
      return;
    }
    final msg = await state.changePassword(oldPw, newPw);
    _oldPwController.clear();
    _newPwController.clear();
    _confirmPwController.clear();
    showSnack(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final s = state.status;
        return Scaffold(
          appBar: AppBar(title: const Text('Sistem & Perangkat')),
          body: SettingsPageShell(
            loading: false,
            error: null,
            loggedIn: state.loggedIn,
            onRetry: () {},
            children: <Widget>[
              const SectionLabel('Info Perangkat', top: AppSpace.sm),
              InfoCard(
                rows: <InfoRow>[
                  const InfoRow('Model', 'Advan iPocket MF01'),
                  InfoRow(
                    'Versi perangkat lunak',
                    _loadingInfo
                        ? 'Memuat…'
                        : _firstOf(const <String>[
                            'sw_version',
                            'software_version',
                            'firmware_version',
                          ]),
                  ),
                  InfoRow(
                    'Versi perangkat keras',
                    _loadingInfo
                        ? 'Memuat…'
                        : _firstOf(const <String>[
                            'hw_version',
                            'hardware_version',
                          ]),
                  ),
                  InfoRow('IP LAN', s?.lanIp ?? _firstOf(const <String>['lan_ipaddr'])),
                  InfoRow('MAC LAN', _firstOf(const <String>['mac_address'])),
                  InfoRow('Operator', s?.networkProvider ?? '—'),
                  InfoRow('Jenis jaringan', s?.networkType ?? '—'),
                  InfoRow('SSID', state.wifiInfo?.ssid ?? s?.ssid ?? '—'),
                ],
              ),
              const SectionLabel('Daya'),
              HubGroup(
                children: <Widget>[
                  HubRow(
                    icon: Icons.restart_alt,
                    title: 'Mulai Ulang Perangkat',
                    subtitle: 'MiFi mati lalu menyala lagi (±1 menit)',
                    onTap: state.busy ? null : () => _reboot(state),
                  ),
                  HubRow(
                    icon: Icons.power_off_outlined,
                    title: 'Matikan Perangkat',
                    subtitle: 'Mati total — nyalakan lagi manual',
                    iconColor: AppColors.danger,
                    onTap: state.busy ? null : () => _turnOff(state),
                  ),
                  HubRow(
                    icon: Icons.factory_outlined,
                    title: 'Setel Ulang Pabrik',
                    subtitle: 'Semua pengaturan kembali ke awal',
                    iconColor: AppColors.danger,
                    onTap: state.busy ? null : () => _restore(state),
                  ),
                ],
              ),
              const SectionLabel('Ganti Kata Sandi Admin'),
              FormCard(
                children: <Widget>[
                  const Text(
                    'Kata sandi ini adalah sandi admin MiFi (yang '
                    'dipakai masuk WebUI & aplikasi ini). Setelah '
                    'berhasil, kamu akan diarahkan masuk lagi '
                    'dengan sandi baru.',
                    style: AppText.rowSubtitle,
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: _oldPwController,
                    obscureText: !_showOld,
                    decoration: InputDecoration(
                      labelText: 'Kata sandi saat ini',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showOld
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _showOld = !_showOld),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: _newPwController,
                    obscureText: !_showNew,
                    decoration: InputDecoration(
                      labelText: 'Kata sandi baru',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showNew
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _showNew = !_showNew),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                  TextField(
                    controller: _confirmPwController,
                    obscureText: !_showNew,
                    decoration: const InputDecoration(
                      labelText: 'Konfirmasi kata sandi baru',
                    ),
                  ),
                  const SizedBox(height: AppSpace.lg),
                  FilledButton.icon(
                    onPressed:
                        state.busy ? null : () => _changePassword(state),
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Ganti Kata Sandi'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.xl),
            ],
          ),
        );
      },
    );
  }
}
