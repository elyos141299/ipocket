import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Pembaruan Firmware / FOTA (D16): periksa via IF_UPGRADE
/// {select_op:"check", ota_manual_check_roam_state:1}, status
/// dari grup fota_*, dan pengaturan otomatis via
/// SetUpgAutoSetting. Aksi select_op lanjutan (unduh/batal)
/// SEBAGIAN di spek — tidak ditawarkan.
class AdvFotaPage extends StatefulWidget {
  const AdvFotaPage({super.key});

  @override
  State<AdvFotaPage> createState() => _AdvFotaPageState();
}

class _AdvFotaPageState extends State<AdvFotaPage> {
  final TextEditingController _intervalCtl = TextEditingController();

  FotaInfo? _status;
  FotaAutoInfo? _auto;
  bool _loading = true;
  bool _saving = false;
  bool _checking = false;
  String? _error;
  bool _autoMode = false;
  bool _roam = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _intervalCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = AppState.instance.api;
      final st = await api.getFotaStatus();
      final au = await api.getFotaAuto();
      if (!mounted) return;
      setState(() {
        _status = st;
        _auto = au;
        _autoMode = au.updateMode == '1';
        _roam = au.allowRoaming == '1';
        _intervalCtl.text = au.intervalDay;
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

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      await AppState.instance.api.fotaCheck();
      // Beri waktu perangkat memperbarui status, lalu muat ulang.
      await Future<void>.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      final st = await AppState.instance.api.getFotaStatus();
      if (!mounted) return;
      setState(() => _status = st);
      showSnack(context, 'Pemeriksaan selesai: ${st.newVersionLabel}.');
    } catch (e) {
      if (!mounted) return;
      showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _saveAuto() async {
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setFotaAuto(
        mode: _autoMode ? '1' : '0',
        intervalDay: _intervalCtl.text.trim(),
        roamPermission: _roam ? '1' : '0',
      );
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

  String _upgradeStateLabel(String v) {
    switch (v) {
      case 'idle':
        return 'Siaga';
      case 'downloading':
        return 'Mengunduh…';
      case 'download_failed':
        return 'Unduhan gagal';
      case 'low_battery':
        return 'Baterai rendah';
      case 'prepare_install':
        return 'Menyiapkan pemasangan';
      case 'verify_failed':
        return 'Verifikasi gagal';
      default:
        return v.isEmpty ? '—' : v;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final st = _status;
    return Scaffold(
      appBar: AppBar(title: const Text('Pembaruan Firmware')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Status Pembaruan', top: AppSpace.sm),
          InfoCard(
            rows: <InfoRow>[
              InfoRow('Ketersediaan', st?.newVersionLabel ?? '—'),
              InfoRow(
                'Keadaan',
                _upgradeStateLabel(st?.upgradeState ?? ''),
              ),
              InfoRow(
                'Paket terunduh',
                st?.packageDownloaded.isEmpty ?? true
                    ? '—'
                    : st!.packageDownloaded,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.lg),
          FilledButton.icon(
            onPressed: _checking ? null : _check,
            icon: _checking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.system_update_alt),
            label: const Text('Periksa Pembaruan'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SectionLabel('Pembaruan Otomatis'),
          FormCard(
            children: <Widget>[
              SettingsSwitchRow(
                title: 'Periksa & pasang otomatis',
                value: _autoMode,
                onChanged: (v) => setState(() => _autoMode = v),
              ),
              const SizedBox(height: AppSpace.md),
              SettingsTextField(
                controller: _intervalCtl,
                label: 'Interval periksa (hari)',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpace.sm),
              SettingsSwitchRow(
                title: 'Izinkan saat roaming',
                value: _roam,
                onChanged: (v) => setState(() => _roam = v),
              ),
              const SizedBox(height: AppSpace.lg),
              SaveButton(
                onPressed: _saveAuto,
                busy: _saving,
                label: 'Simpan Pengaturan Otomatis',
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Bila ada paket pembaruan, pemasangannya dilakukan '
            'perangkat mengikuti pengaturan otomatis di atas.',
            style: AppText.hint,
          ),
        ],
      ),
    );
  }
}
