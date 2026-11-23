import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Wi-Fi Utama (B1): saklar Wi-Fi (SET_WIFI_INFO), SSID, siaran,
/// mode keamanan, sandi, batas akses user (MAX_Access_num),
/// NoForwarding & QR — simpan via SET_WIFI_SSID1_SETTINGS dengan
/// aturan kondisional AuthMode persis FULL-SPEC-BCD B1.
class WifiMainPage extends StatefulWidget {
  const WifiMainPage({super.key});

  @override
  State<WifiMainPage> createState() => _WifiMainPageState();
}

class _WifiMainPageState extends State<WifiMainPage> {
  final TextEditingController _ssidCtl = TextEditingController();
  final TextEditingController _passCtl = TextEditingController();
  final List<TextEditingController> _wepCtls =
      List<TextEditingController>.generate(4, (_) => TextEditingController());

  WifiBasic? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _wifiOn = true;
  bool _broadcast = true;
  String _authMode = 'WPA2PSK';
  int _maxAccess = 3;
  bool _noForwarding = false;
  bool _showQr = false;
  String _wepDefaultKey = '0';
  bool _showPass = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ssidCtl.dispose();
    _passCtl.dispose();
    for (final c in _wepCtls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AppState.instance.api.getWifiBasic();
      if (!mounted) return;
      setState(() {
        _data = d;
        _wifiOn = d.wifiEnabled;
        _broadcast = d.broadcast;
        _authMode =
            kAuthModes.contains(d.authMode) ? d.authMode : 'WPA2PSK';
        _maxAccess = (d.maxAccess > 0 ? d.maxAccess : d.maxStation)
            .clamp(1, d.maxStation);
        _noForwarding = d.noForwarding == '1';
        _showQr = d.showQrcode == '1';
        _wepDefaultKey =
            const <String>['0', '1', '2', '3'].contains(d.defaultKeyId)
                ? d.defaultKeyId
                : '0';
        _ssidCtl.text = d.ssid;
        _passCtl.text = d.passPhrase;
        _wepCtls[0].text = d.key1;
        _wepCtls[1].text = d.key2;
        _wepCtls[2].text = d.key3;
        _wepCtls[3].text = d.key4;
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

  Future<void> _toggleWifi(bool on) async {
    final d = _data;
    if (d == null) return;
    if (!on) {
      final ok = await confirmAction(
        context,
        title: 'Matikan Wi-Fi?',
        body: 'Wi-Fi iPocket akan MATI. Semua perangkat (termasuk '
            'HP ini) terputus dari MiFi dan aplikasi kehilangan '
            'koneksi. Menyalakannya lagi perlu akses lain ke '
            'perangkat (kabel USB / WebUI). Lanjutkan?',
        actionLabel: 'Matikan Wi-Fi',
        danger: true,
      );
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api
          .setWifiEnabled(enabled: on, mSsidEnable: d.mSsidEnable);
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) setState(() => _wifiOn = on);
    } catch (e) {
      if (!mounted) return;
      showSnack(
        context,
        on
            ? friendlyError(e)
            : 'Tidak ada respons utuh — wajar bila Wi-Fi '
                'langsung mati dan koneksi putus.',
      );
      if (!on) setState(() => _wifiOn = false);
    } finally {
      if (mounted) setState(() => _saving = false);
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
      title: 'Simpan pengaturan Wi-Fi?',
      body: 'Setelah disimpan, Wi-Fi MiFi akan putus sebentar lalu '
          'menyambung ulang dengan pengaturan baru. Bila nama SSID '
          'atau sandi berubah, kamu harus menyambungkan HP ke '
          'Wi-Fi secara manual dengan nama/sandi baru. Lanjutkan?',
      actionLabel: 'Simpan',
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setWifiBasic(
        ssid: _ssidCtl.text.trim(),
        broadcast: _broadcast,
        maxAccessNum: _maxAccess,
        authMode: _authMode,
        passPhrase: _passCtl.text,
        noForwarding: _noForwarding ? '1' : '0',
        showQrcode: _showQr ? '1' : '0',
        encrypType: d.encrypType,
        wepDefaultKey: _wepDefaultKey,
        wepKeys: _wepCtls.map((c) => c.text).toList(),
      );
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(
        context,
        'Tidak ada respons utuh — wajar bila Wi-Fi langsung '
        'menyambung ulang. Sambungkan kembali ke Wi-Fi lalu periksa.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool get _wepActive => _authMode == 'SHARED' || _data?.encrypType == 'WEP';

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Utama')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          FormCard(
            children: <Widget>[
              SettingsSwitchRow(
                title: 'Wi-Fi',
                subtitle: _wifiOn ? 'Menyala' : 'Mati',
                value: _wifiOn,
                onChanged: _saving ? (_) {} : _toggleWifi,
              ),
            ],
          ),
          const SectionLabel('Nama & Siaran'),
          FormCard(
            children: <Widget>[
              SettingsTextField(
                controller: _ssidCtl,
                label: 'Nama Wi-Fi (SSID)',
              ),
              const SizedBox(height: AppSpace.md),
              SettingsSwitchRow(
                title: 'Siarkan SSID',
                subtitle: 'Mati = nama Wi-Fi disembunyikan',
                value: _broadcast,
                onChanged: (v) => setState(() => _broadcast = v),
              ),
              SettingsSwitchRow(
                title: 'Isolasi klien (No Forwarding)',
                subtitle: 'Perangkat Wi-Fi tidak bisa saling melihat',
                value: _noForwarding,
                onChanged: (v) => setState(() => _noForwarding = v),
              ),
              SettingsSwitchRow(
                title: 'Tampilkan kode QR di WebUI',
                value: _showQr,
                onChanged: (v) => setState(() => _showQr = v),
              ),
            ],
          ),
          const SectionLabel('Keamanan'),
          FormCard(
            children: <Widget>[
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
                // v3.1.1: panel statis SettingsTextField (label
                // tetap di dalam panel) — bukan lagi TextField
                // label melayang.
                SettingsTextField(
                  controller: _passCtl,
                  label: 'Sandi Wi-Fi',
                  helper: 'Minimal 8 karakter.',
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
              if (_wepActive) ...<Widget>[
                const SizedBox(height: AppSpace.md),
                SettingsDropdown<String>(
                  label: 'Kunci WEP aktif',
                  value: _wepDefaultKey,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: '0', child: Text('Kunci 1')),
                    DropdownMenuItem(value: '1', child: Text('Kunci 2')),
                    DropdownMenuItem(value: '2', child: Text('Kunci 3')),
                    DropdownMenuItem(value: '3', child: Text('Kunci 4')),
                  ],
                  onChanged: (v) =>
                      setState(() => _wepDefaultKey = v ?? '0'),
                ),
                for (var k = 0; k < 4; k++) ...<Widget>[
                  const SizedBox(height: AppSpace.md),
                  SettingsTextField(
                    controller: _wepCtls[k],
                    label: 'Kunci WEP ${k + 1}',
                  ),
                ],
              ],
            ],
          ),
          const SectionLabel('Batas Akses'),
          FormCard(
            children: <Widget>[
              SettingsDropdown<int>(
                label: 'Jumlah perangkat maksimum',
                value: _maxAccess,
                helper: 'Batas yang kamu atur (kapabilitas perangkat: '
                    '${d?.maxStation ?? 32}).',
                items: List<DropdownMenuItem<int>>.generate(
                  d?.maxStation ?? 32,
                  (i) => DropdownMenuItem<int>(
                    value: i + 1,
                    child: Text('${i + 1} perangkat'),
                  ),
                ),
                onChanged: (v) =>
                    setState(() => _maxAccess = v ?? _maxAccess),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(onPressed: _save, busy: _saving),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Menyimpan akan memutus Wi-Fi sesaat. Bila SSID/sandi '
            'berubah, sambungkan ulang HP secara manual.',
            style: AppText.hint,
          ),
        ],
      ),
    );
  }
}
