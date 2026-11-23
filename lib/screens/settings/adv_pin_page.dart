import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// PIN SIM (D17) — BACA-SAJA sesuai tabel keputusan spek:
/// builder ENTER_PIN/ENTER_PUK/ENABLE_PIN/DISABLE_PIN memang
/// pasti, tetapi halaman PIN di perangkat ini nonaktif total
/// (inspeksi live: Status PIN Nonaktif, semua kontrol disabled),
/// jadi aplikasi hanya menampilkan status & sisa upaya.
class AdvPinPage extends StatefulWidget {
  const AdvPinPage({super.key});

  @override
  State<AdvPinPage> createState() => _AdvPinPageState();
}

class _AdvPinPageState extends State<AdvPinPage> {
  PinInfo? _data;
  bool _loading = true;
  String? _error;

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
      final d = await AppState.instance.api.getPin();
      if (!mounted) return;
      setState(() {
        _data = d;
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

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('PIN SIM')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Status PIN', top: AppSpace.sm),
          InfoCard(
            rows: <InfoRow>[
              InfoRow(
                'Status PIN',
                d?.pinStatus.isEmpty ?? true ? '—' : d!.pinStatus,
              ),
              InfoRow(
                'Sisa upaya PIN',
                d?.pinRemain.isEmpty ?? true ? '—' : d!.pinRemain,
              ),
              InfoRow(
                'Sisa upaya PUK',
                d?.pukRemain.isEmpty ?? true ? '—' : d!.pukRemain,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Halaman PIN di perangkat ini nonaktif (sesuai WebUI), '
            'jadi aplikasi hanya menampilkan status. Pengelolaan '
            'PIN tidak ditawarkan agar tidak mengunci SIM-mu.',
            style: AppText.hint,
          ),
        ],
      ),
    );
  }
}
