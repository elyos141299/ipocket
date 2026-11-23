import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// DMZ (D14): GET DMZEnable/DMZIPAddress; POST DMZ_SETTING —
/// DMZIPAddress hanya dikirim bila DMZ aktif (persis spek).
class FwDmzPage extends StatefulWidget {
  const FwDmzPage({super.key});

  @override
  State<FwDmzPage> createState() => _FwDmzPageState();
}

class _FwDmzPageState extends State<FwDmzPage> {
  final TextEditingController _ipCtl = TextEditingController();

  DmzInfo? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ipCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AppState.instance.api.getDmz();
      if (!mounted) return;
      setState(() {
        _data = d;
        _enabled = d.enabled;
        _ipCtl.text = d.ipAddress;
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

  Future<void> _save() async {
    if (_enabled && _ipCtl.text.trim().isEmpty) {
      showSnack(context, 'Alamat IP DMZ wajib diisi saat DMZ aktif.');
      return;
    }
    if (_enabled) {
      final ok = await confirmAction(
        context,
        title: 'Aktifkan DMZ?',
        body: 'Perangkat ${_ipCtl.text.trim()} akan terbuka PENUH '
            'ke internet — semua port yang tidak diatur firewall '
            'diteruskan ke perangkat itu. Ini berisiko keamanan. '
            'Lanjutkan?',
        actionLabel: 'Aktifkan DMZ',
        danger: true,
      );
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api
          .setDmz(enabled: _enabled, ip: _ipCtl.text.trim());
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

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('DMZ')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          FormCard(
            children: <Widget>[
              SettingsSwitchRow(
                title: 'DMZ aktif',
                subtitle: 'Satu perangkat LAN terbuka penuh ke WAN',
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              if (_enabled) ...<Widget>[
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: _ipCtl,
                  label: 'Alamat IP DMZ (LAN)',
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'DMZ membuka perangkat tujuan ke semua port dari '
            'internet. Aktifkan hanya bila benar-benar perlu.',
            style: AppText.hint,
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(onPressed: _save, busy: _saving),
        ],
      ),
    );
  }
}
