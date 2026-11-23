import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Pengaturan Cepat (B2): QUICK_SETUP_EX — profil APN aktif +
/// Wi-Fi dalam satu kali simpan, mengikuti objek utuh spek.
/// Di unit ini langkah APN wizard tampil disabled di WebUI;
/// wire-nya pasti dan ditampilkan apa adanya.
class WifiQuickPage extends StatefulWidget {
  const WifiQuickPage({super.key});

  @override
  State<WifiQuickPage> createState() => _WifiQuickPageState();
}

class _WifiQuickPageState extends State<WifiQuickPage> {
  final TextEditingController _profileCtl = TextEditingController();
  final TextEditingController _apnCtl = TextEditingController();
  final TextEditingController _userCtl = TextEditingController();
  final TextEditingController _pwCtl = TextEditingController();
  final TextEditingController _ssidCtl = TextEditingController();
  final TextEditingController _passCtl = TextEditingController();

  QuickSetupInfo? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _authApn = 'NONE';
  bool _broadcast = true;
  String _authMode = 'WPA2PSK';
  bool _showPass = false;

  static const List<String> _apnAuthModes = <String>['NONE', 'CHAP', 'PAP'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _profileCtl.dispose();
    _apnCtl.dispose();
    _userCtl.dispose();
    _pwCtl.dispose();
    _ssidCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AppState.instance.api.getQuickSetup();
      if (!mounted) return;
      setState(() {
        _data = d;
        _profileCtl.text = d.profileName;
        _apnCtl.text = d.wanApn;
        _userCtl.text = d.pppUsername;
        _pwCtl.text = d.pppPassword;
        _ssidCtl.text = d.ssid;
        _passCtl.text = d.passPhrase;
        _broadcast = d.hideSsid != '1';
        _authMode =
            kAuthModes.contains(d.authMode) ? d.authMode : 'WPA2PSK';
        final apnAuth = d.pppAuthMode.toUpperCase();
        _authApn = _apnAuthModes.contains(apnAuth) ? apnAuth : 'NONE';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat Pengaturan Cepat: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final d = _data;
    if (d == null) return;
    if (_ssidCtl.text.trim().isEmpty) {
      showSnack(context, 'Nama SSID wajib diisi.');
      return;
    }
    if (isWpaFamily(_authMode) && _passCtl.text.length < 8) {
      showSnack(context, 'Sandi Wi-Fi minimal 8 karakter untuk mode WPA.');
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Simpan Pengaturan Cepat?',
      body: 'APN dan Wi-Fi akan ditulis sekaligus. Wi-Fi MiFi akan '
          'putus sebentar lalu menyambung ulang dengan pengaturan '
          'baru; bila SSID/sandi berubah, sambungkan HP secara '
          'manual. Lanjutkan?',
      actionLabel: 'Simpan',
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setQuickSetup(
        base: d,
        profileName: _profileCtl.text.trim(),
        wanApn: _apnCtl.text.trim(),
        pppAuthMode: _authApn,
        pppUsername: _userCtl.text,
        pppPassword: _pwCtl.text,
        ssidName: _ssidCtl.text.trim(),
        ssidBroadcast: _broadcast,
        authMode: _authMode,
        passPhrase: _passCtl.text,
      );
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Tidak ada respons utuh ($e) — wajar bila Wi-Fi langsung menyambung ulang.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Cepat')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Profil APN Aktif', top: AppSpace.sm),
          FormCard(
            children: <Widget>[
              SettingsTextField(
                controller: _profileCtl,
                label: 'Nama profil',
              ),
              const SizedBox(height: AppSpace.md),
              SettingsTextField(
                controller: _apnCtl,
                label: 'APN',
              ),
              const SizedBox(height: AppSpace.md),
              SettingsDropdown<String>(
                label: 'Otentikasi',
                value: _authApn,
                items: _apnAuthModes
                    .map(
                      (m) => DropdownMenuItem<String>(
                        value: m,
                        child: Text(m),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _authApn = v ?? _authApn),
              ),
              const SizedBox(height: AppSpace.md),
              SettingsTextField(
                controller: _userCtl,
                label: 'Nama pengguna PPP',
              ),
              const SizedBox(height: AppSpace.md),
              SettingsTextField(
                controller: _pwCtl,
                label: 'Sandi PPP',
                obscure: true,
              ),
              if (d != null && d.pdpType.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpace.md),
                Text('Jenis PDP: ${d.pdpType}', style: AppText.hint),
              ],
            ],
          ),
          const SectionLabel('Wi-Fi'),
          FormCard(
            children: <Widget>[
              SettingsTextField(
                controller: _ssidCtl,
                label: 'Nama Wi-Fi (SSID)',
              ),
              const SizedBox(height: AppSpace.md),
              SettingsSwitchRow(
                title: 'Siarkan SSID',
                value: _broadcast,
                onChanged: (v) => setState(() => _broadcast = v),
              ),
              const SizedBox(height: AppSpace.sm),
              SettingsDropdown<String>(
                label: 'Mode keamanan',
                value: _authMode,
                items: kAuthModes
                    .map(
                      (m) => DropdownMenuItem<String>(
                        value: m,
                        child: Text(authModeLabel(m)),
                      ),
                    )
                    .toList(),
                onChanged: (v) =>
                    setState(() => _authMode = v ?? _authMode),
              ),
              if (isWpaFamily(_authMode)) ...<Widget>[
                const SizedBox(height: AppSpace.md),
                // v3.1.1: panel statis SettingsTextField.
                SettingsTextField(
                  controller: _passCtl,
                  label: 'Sandi Wi-Fi',
                  obscure: !_showPass,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showPass
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _showPass = !_showPass),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(onPressed: _save, busy: _saving),
        ],
      ),
    );
  }
}
