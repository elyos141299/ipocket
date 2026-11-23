import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Mode Koneksi (C9): SET_CONNECTION_MODE {ConnectionMode,
/// roam_setting_option}. Enum ConnectionMode pasti
/// ("auto_dial"/"manual_dial"); nilai roam dari checkbox
/// (SEBAGIAN). Catatan LIVE: halaman ini terkunci di WebUI unit
/// ini — bila perangkat menolak, hasil mentahnya tampil di log.
class NetModePage extends StatefulWidget {
  const NetModePage({super.key});

  @override
  State<NetModePage> createState() => _NetModePageState();
}

class _NetModePageState extends State<NetModePage> {
  ConnectionModeInfo? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _mode = 'auto_dial';
  bool _roaming = false;

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
      final d = await AppState.instance.api.getConnectionMode();
      if (!mounted) return;
      setState(() {
        _data = d;
        if (d.mode == 'auto_dial' || d.mode == 'manual_dial') {
          _mode = d.mode;
        }
        _roaming = d.roamingAllowed;
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
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api
          .setConnectionMode(mode: _mode, roaming: _roaming);
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
      appBar: AppBar(title: const Text('Mode Koneksi')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Mode Sambung Data', top: AppSpace.sm),
          FormCard(
            children: <Widget>[
              SettingsDropdown<String>(
                label: 'Mode koneksi',
                value: _mode,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'auto_dial',
                    child: Text('Otomatis — sambung sendiri'),
                  ),
                  DropdownMenuItem(
                    value: 'manual_dial',
                    child: Text('Manual — sambung dari aplikasi'),
                  ),
                ],
                onChanged: (v) => setState(() => _mode = v ?? _mode),
              ),
              const SizedBox(height: AppSpace.sm),
              SettingsSwitchRow(
                title: 'Sambung otomatis saat roaming',
                subtitle: 'Tetap terhubung di jaringan operator lain',
                value: _roaming,
                onChanged: (v) => setState(() => _roaming = v),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Di WebUI perangkat ini halaman Pengaturan Jaringan '
            'tampil terkunci; bila perangkat menolak simpan, '
            'hasilnya tercatat di log Diagnostik.',
            style: AppText.hint,
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(onPressed: _save, busy: _saving),
        ],
      ),
    );
  }
}
