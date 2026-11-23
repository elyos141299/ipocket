import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Manajemen Data (C12): DATA_LIMIT_SETTING. Batas berbasis data
/// (ukuran bisa berformat "<n>_<pengali>" — pengali dipertahankan
/// apa adanya) atau berbasis waktu (jam). Field tanggal reset
/// memang TIDAK ada di wire perangkat — tidak ditampilkan.
class NetDataPage extends StatefulWidget {
  const NetDataPage({super.key});

  @override
  State<NetDataPage> createState() => _NetDataPageState();
}

class _NetDataPageState extends State<NetDataPage> {
  final TextEditingController _sizeCtl = TextEditingController();
  final TextEditingController _alertCtl = TextEditingController();

  DataLimitInfo? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _enabled = false;
  String _unit = 'data';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _sizeCtl.dispose();
    _alertCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AppState.instance.api.getDataLimit();
      if (!mounted) return;
      setState(() {
        _data = d;
        _enabled = d.enabled;
        _unit = d.isDataUnit ? 'data' : 'time';
        _sizeCtl.text = d.sizeNumber;
        _alertCtl.text = d.alertPercent;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat Manajemen Data: $e';
        _loading = false;
      });
    }
  }

  /// Petunjuk field ukuran untuk unit data, menyebut pengali
  /// format "<n>_<pengali>" bila perangkat memakainya.
  String _dataSizeHelper(DataLimitInfo? d) {
    final mult = d?.sizeMultiplier;
    if (mult == null) return 'Angka mengikuti satuan perangkat.';
    return 'Angka mengikuti satuan perangkat '
        '(pengali ×$mult dipertahankan).';
  }

  String _fmtBytes(int? v) {
    if (v == null) return '—';
    if (v < 1024) return '$v B';
    if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB';
    if (v < 1024 * 1024 * 1024) {
      return '${(v / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(v / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String _fmtDuration(int? seconds) {
    if (seconds == null) return '—';
    final d = Duration(seconds: seconds);
    if (d.inHours > 0) return '${d.inHours} jam ${d.inMinutes % 60} menit';
    if (d.inMinutes > 0) return '${d.inMinutes} menit';
    return '${d.inSeconds} detik';
  }

  Future<void> _save() async {
    final d = _data;
    if (d == null) return;
    var size = _sizeCtl.text.trim();
    if (_enabled) {
      if (size.isEmpty || int.tryParse(size) == null) {
        showSnack(context, 'Ukuran batas harus angka.');
        return;
      }
      final alert = _alertCtl.text.trim();
      if (alert.isNotEmpty &&
          (int.tryParse(alert) == null ||
              int.parse(alert) < 0 ||
              int.parse(alert) > 100)) {
        showSnack(context, 'Ambang peringatan harus 0–100 (%).');
        return;
      }
      // Pertahankan pengali format "<n>_<pengali>" untuk unit data.
      if (_unit == 'data' && d.sizeMultiplier != null) {
        size = '${size}_${d.sizeMultiplier}';
      }
    }
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setDataLimit(
        enabled: _enabled,
        unit: _unit,
        size: size,
        alertPercent: _alertCtl.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Gagal menghubungi MiFi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Manajemen Data')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Pemakaian Bulan Ini', top: AppSpace.sm),
          InfoCard(
            rows: <InfoRow>[
              InfoRow('Unduh', _fmtBytes(d?.monthlyRx)),
              InfoRow('Unggah', _fmtBytes(d?.monthlyTx)),
              InfoRow('Durasi tersambung', _fmtDuration(d?.monthlyTime)),
            ],
          ),
          const SectionLabel('Batas Pemakaian'),
          FormCard(
            children: <Widget>[
              SettingsSwitchRow(
                title: 'Aktifkan batas',
                subtitle: 'Peringatan saat pemakaian mendekati batas',
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              if (_enabled) ...<Widget>[
                const SizedBox(height: AppSpace.md),
                SettingsDropdown<String>(
                  label: 'Jenis batas',
                  value: _unit,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(
                      value: 'data',
                      child: Text('Berdasarkan data'),
                    ),
                    DropdownMenuItem(
                      value: 'time',
                      child: Text('Berdasarkan waktu'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _unit = v ?? _unit),
                ),
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: _sizeCtl,
                  label: _unit == 'data'
                      ? 'Ukuran batas (satuan perangkat)'
                      : 'Batas waktu (jam)',
                  helper: _unit == 'data'
                      ? _dataSizeHelper(d)
                      : 'Dalam jam pemakaian per bulan.',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: _alertCtl,
                  label: 'Ambang peringatan (%)',
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Perangkat ini tidak menyediakan tanggal reset bulanan '
            'lewat API-nya — batas berlaku mengikuti hitungan '
            'perangkat apa adanya.',
            style: AppText.hint,
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(onPressed: _save, busy: _saving),
        ],
      ),
    );
  }
}
