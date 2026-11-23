import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// WPS (B3): status dari getWpsInfo; mulai WPS via WIFI_WPS_SET
/// (SSID1) — field wps_pin hanya dikirim pada mode PIN, pemisah
/// PIN dibuang persis aturan WebUI.
class WifiWpsPage extends StatefulWidget {
  const WifiWpsPage({super.key});

  @override
  State<WifiWpsPage> createState() => _WifiWpsPageState();
}

class _WifiWpsPageState extends State<WifiWpsPage> {
  final TextEditingController _pinCtl = TextEditingController();

  WpsInfo? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _mode = 'PBC';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pinCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AppState.instance.api.getWps();
      if (!mounted) return;
      setState(() {
        _data = d;
        if (d.wpsType == 'PIN' || d.wpsType == 'PBC') _mode = d.wpsType;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat status WPS: $e';
        _loading = false;
      });
    }
  }

  Future<void> _start() async {
    final d = _data;
    if (d == null) return;
    if (_mode == 'PIN' && _pinCtl.text.replaceAll(RegExp(r'[\s-]'), '').length < 8) {
      showSnack(context, 'PIN WPS harus 8 digit (boleh ditulis 1234-5678).');
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.startWps(
        ssid: d.wpsSsid.isNotEmpty ? d.wpsSsid : d.ssid,
        mode: _mode,
        pin: _pinCtl.text,
      );
      if (!mounted) return;
      showSnack(
        context,
        r.ok
            ? 'WPS dimulai — sambungkan perangkatmu sekarang (jendela ±2 menit).'
            : (r.message ?? ''),
      );
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
      appBar: AppBar(title: const Text('WPS')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Status', top: AppSpace.sm),
          InfoCard(
            rows: <InfoRow>[
              InfoRow('WPS', d == null || d.wpsFlag.isEmpty ? '—' : d.wpsFlag),
              InfoRow('Mode terakhir', d?.wpsType.isEmpty ?? true ? '—' : d!.wpsType),
              InfoRow('SSID', d?.ssid.isEmpty ?? true ? '—' : d!.ssid),
              InfoRow('Radio Wi-Fi', d == null ? '—' : (d.radioOn ? 'Menyala' : 'Mati')),
            ],
          ),
          const SectionLabel('Mulai WPS'),
          FormCard(
            children: <Widget>[
              SettingsDropdown<String>(
                label: 'Metode',
                value: _mode,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'PBC',
                    child: Text('PBC — tekan tombol di perangkat'),
                  ),
                  DropdownMenuItem(
                    value: 'PIN',
                    child: Text('PIN — masukkan PIN perangkat'),
                  ),
                ],
                onChanged: (v) => setState(() => _mode = v ?? _mode),
              ),
              if (_mode == 'PIN') ...<Widget>[
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: _pinCtl,
                  label: 'PIN WPS',
                  helper: '8 digit; pemisah "-" di tengah boleh ditulis.',
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: AppSpace.lg),
              SaveButton(
                onPressed: _start,
                busy: _saving,
                label: 'Mulai WPS',
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Setelah WPS dimulai, perangkat baru punya waktu '
            '±2 menit untuk menyambung tanpa sandi Wi-Fi.',
            style: AppText.hint,
          ),
        ],
      ),
    );
  }
}
