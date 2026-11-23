import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Router & DHCP (D13): POST DHCP_SETTING utuh +
/// dhcp_reboot_flag:1 — perangkat mulai ulang setelah simpan,
/// dan IP LAN baru bisa membuat aplikasi kehilangan gateway.
class AdvRouterPage extends StatefulWidget {
  const AdvRouterPage({super.key});

  @override
  State<AdvRouterPage> createState() => _AdvRouterPageState();
}

class _AdvRouterPageState extends State<AdvRouterPage> {
  final TextEditingController _ipCtl = TextEditingController();
  final TextEditingController _maskCtl = TextEditingController();
  final TextEditingController _startCtl = TextEditingController();
  final TextEditingController _endCtl = TextEditingController();
  final TextEditingController _leaseCtl = TextEditingController();

  DhcpInfo? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _dhcpOn = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ipCtl.dispose();
    _maskCtl.dispose();
    _startCtl.dispose();
    _endCtl.dispose();
    _leaseCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AppState.instance.api.getDhcp();
      if (!mounted) return;
      setState(() {
        _data = d;
        _ipCtl.text = d.lanIp;
        _maskCtl.text = d.lanNetmask;
        _startCtl.text = d.dhcpStart;
        _endCtl.text = d.dhcpEnd;
        _leaseCtl.text = d.dhcpLeaseHours?.toString() ?? '';
        _dhcpOn = d.dhcpEnabled;
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
    final ipChanged = _ipCtl.text.trim() != (_data?.lanIp ?? '');
    final ok = await confirmAction(
      context,
      title: 'Simpan & mulai ulang MiFi?',
      body: 'Perangkat akan MULAI ULANG setelah pengaturan ini '
          'disimpan (dhcp_reboot_flag). Koneksi terputus ±1 menit.'
          '${ipChanged ? '\n\n⚠️ Kamu MENGUBAH alamat IP LAN — setelah reboot, gateway aplikasi harus diganti ke IP baru itu di hub Pengaturan, kalau tidak aplikasi tidak bisa menjangkau MiFi.' : ''}'
          '\n\nLanjutkan?',
      actionLabel: 'Simpan & Ulang',
      danger: ipChanged,
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setDhcp(
        lanIp: _ipCtl.text.trim(),
        lanNetmask: _maskCtl.text.trim(),
        serverEnabled: _dhcpOn,
        dhcpStart: _startCtl.text.trim(),
        dhcpEnd: _endCtl.text.trim(),
        dhcpLease: _leaseCtl.text.trim(),
      );
      if (!mounted) return;
      showSnack(
        context,
        r.ok
            ? 'Tersimpan — MiFi mulai ulang. Tunggu ±1 menit lalu '
                'sambungkan ulang${ipChanged ? ' dan perbarui gateway aplikasi' : ''}.'
            : (r.message ?? ''),
      );
    } catch (e) {
      if (!mounted) return;
      showSnack(
        context,
        'Tidak ada respons utuh — wajar bila perangkat '
        'langsung mulai ulang. Tunggu ±1 menit lalu sambungkan ulang.',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Router & DHCP')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('LAN', top: AppSpace.sm),
          FormCard(
            children: <Widget>[
              SettingsTextField(
                controller: _ipCtl,
                label: 'Alamat IP LAN',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpace.md),
              SettingsTextField(
                controller: _maskCtl,
                label: 'Subnet mask',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'MAC perangkat: ${d?.macAddress.isEmpty ?? true ? '—' : d!.macAddress}',
                style: AppText.hint,
              ),
            ],
          ),
          const SectionLabel('Server DHCP'),
          FormCard(
            children: <Widget>[
              SettingsSwitchRow(
                title: 'Server DHCP',
                subtitle: 'Bagi alamat IP otomatis ke perangkat',
                value: _dhcpOn,
                onChanged: (v) => setState(() => _dhcpOn = v),
              ),
              if (_dhcpOn) ...<Widget>[
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: _startCtl,
                  label: 'IP awal',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: _endCtl,
                  label: 'IP akhir',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: _leaseCtl,
                  label: 'Masa sewa (jam)',
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(
            onPressed: _save,
            busy: _saving,
            label: 'Simpan & Mulai Ulang',
          ),
        ],
      ),
    );
  }
}
