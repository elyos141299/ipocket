import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Hemat Daya (B7): cakupan Wi-Fi via SET_WIFI_COVERAGE (PASTI;
/// nilai selain "long_mode" SEBAGIAN — pola nama *_mode dari
/// perangkat) dan waktu tidur BACA-SAJA (enum nilai kirim
/// SET_WIFI_SLEEP_INFO ada di set.js yang tidak tersedia —
/// spek menandai BANGUN BACA-SAJA, jangan kirim).
class WifiPowerPage extends StatefulWidget {
  const WifiPowerPage({super.key});

  @override
  State<WifiPowerPage> createState() => _WifiPowerPageState();
}

class _WifiPowerPageState extends State<WifiPowerPage> {
  String? _coverage;
  String? _sleepRaw;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _coverageChoice = 'long_mode';

  static const Map<String, String> _coverageLabels = <String, String>{
    'short_mode': 'Dekat (hemat daya, jangkauan pendek)',
    'medium_mode': 'Sedang',
    'long_mode': 'Jauh (jangkauan terluas)',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = AppState.instance.api;
      final cov = await api.getWifiCoverage();
      final sleep = await api.getSleepInterval();
      if (!mounted) return;
      setState(() {
        _coverage = cov;
        _sleepRaw = sleep;
        if (cov != null && _coverageLabels.containsKey(cov)) {
          _coverageChoice = cov;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  /// Label ramah waktu tidur dari nilai mentah: angka dianggap
  /// menit (label opsi WebUI: Never, 5, 10, 20, 30 Menit, 1/2 Jam).
  String _sleepLabel(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final n = int.tryParse(raw);
    if (n == null) return raw;
    if (n == 0) return 'Tidak pernah tidur (Never)';
    if (n == 60) return '1 Jam';
    if (n == 120) return '2 Jam';
    return '$n Menit';
  }

  Future<void> _saveCoverage() async {
    final ok = await confirmAction(
      context,
      title: 'Ubah cakupan Wi-Fi?',
      body: 'Cakupan menentukan kekuatan pancar Wi-Fi. Mengubahnya '
          'bisa memutus koneksi sesaat. Lanjutkan?',
      actionLabel: 'Simpan',
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setWifiCoverage(_coverageChoice);
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Teks nilai cakupan saat ini dari perangkat, dengan label
  /// ramah bila nilainya dikenal.
  String get _coverageNowText {
    final cov = _coverage;
    if (cov == null) return '—';
    final label = _coverageLabels[cov];
    return label == null ? cov : '$cov ($label)';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Hemat Daya')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Cakupan Wi-Fi', top: AppSpace.sm),
          FormCard(
            children: <Widget>[
              SettingsDropdown<String>(
                label: 'Cakupan',
                value: _coverageChoice,
                helper: 'Nilai perangkat saat ini: $_coverageNowText.',
                items: _coverageLabels.entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _coverageChoice = v ?? _coverageChoice),
              ),
              const SizedBox(height: AppSpace.lg),
              SaveButton(
                onPressed: _saveCoverage,
                busy: _saving,
                label: 'Simpan Cakupan',
              ),
            ],
          ),
          const SectionLabel('Waktu Tidur Wi-Fi'),
          InfoCard(
            rows: <InfoRow>[
              InfoRow('Waktu tidur saat ini', _sleepLabel(_sleepRaw)),
              InfoRow('Nilai mentah perangkat', _sleepRaw ?? '—'),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Waktu tidur hanya ditampilkan: daftar nilai pastinya '
            'ada di berkas konfigurasi perangkat yang tidak bisa '
            'dibaca aplikasi, jadi aplikasi tidak menebak kiriman '
            'untuk pengaturan ini. Ubah lewat WebUI bila perlu.',
            style: AppText.hint,
          ),
        ],
      ),
    );
  }
}
