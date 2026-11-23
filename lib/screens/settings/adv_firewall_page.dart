import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../theme.dart';
import '../../widgets.dart';
import 'fw_dmz_page.dart';
import 'fw_filter_page.dart';
import 'fw_forward_page.dart';
import 'fw_portmap_page.dart';
import 'fw_url_page.dart';

/// Hub Firewall (D14): saklar FW_SYS (manajemen jarak jauh +
/// filter ping WAN) dan UPnP di halaman ini; fitur rule membuka
/// sub-halaman masing-masing. Format string rule persis spek.
class AdvFirewallPage extends StatefulWidget {
  const AdvFirewallPage({super.key});

  @override
  State<AdvFirewallPage> createState() => _AdvFirewallPageState();
}

class _AdvFirewallPageState extends State<AdvFirewallPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _remoteMgmt = false;
  bool _pingFilter = false;
  bool _upnp = false;

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
      final fw = await api.getFwSys();
      final upnp = await api.getUpnp();
      if (!mounted) return;
      setState(() {
        _remoteMgmt = fw.remoteManagement;
        _pingFilter = fw.wanPingFilter;
        _upnp = upnp;
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

  Future<void> _saveFwSys() async {
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setFwSys(
        remoteManagement: _remoteMgmt,
        wanPingFilter: _pingFilter,
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

  Future<void> _saveUpnp(bool v) async {
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setUpnp(v);
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) {
        setState(() => _upnp = v);
      } else {
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      showSnack(context, friendlyError(e));
      _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _open(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Firewall')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Dasar', top: AppSpace.sm),
          FormCard(
            children: <Widget>[
              SettingsSwitchRow(
                title: 'Manajemen jarak jauh',
                subtitle: 'WebUI bisa dibuka dari internet (WAN)',
                value: _remoteMgmt,
                onChanged: (v) => setState(() => _remoteMgmt = v),
              ),
              SettingsSwitchRow(
                title: 'Filter ping WAN',
                subtitle: 'Tolak ping dari internet ke MiFi',
                value: _pingFilter,
                onChanged: (v) => setState(() => _pingFilter = v),
              ),
              const SizedBox(height: AppSpace.md),
              SaveButton(
                onPressed: _saveFwSys,
                busy: _saving,
                label: 'Simpan Pengaturan Dasar',
              ),
            ],
          ),
          const SectionLabel('Rule & Fitur'),
          HubGroup(
            children: <Widget>[
              HubRow(
                icon: Icons.filter_alt_outlined,
                title: 'Filter Port',
                subtitle: 'Aturan izinkan/tolak IP & port',
                onTap: () => _open(const FwFilterPage()),
              ),
              HubRow(
                icon: Icons.swap_horiz,
                title: 'Port Forwarding',
                subtitle: 'Teruskan port WAN ke perangkat LAN',
                onTap: () => _open(const FwForwardPage()),
              ),
              HubRow(
                icon: Icons.alt_route,
                title: 'Port Mapping',
                subtitle: 'Petakan port luar ke port lain di LAN',
                onTap: () => _open(const FwPortMapPage()),
              ),
              HubRow(
                icon: Icons.open_in_full,
                title: 'DMZ',
                subtitle: 'Satu perangkat terbuka penuh ke WAN',
                onTap: () => _open(const FwDmzPage()),
              ),
              HubRow(
                icon: Icons.link_off,
                title: 'Filter URL',
                subtitle: 'Blokir alamat situs tertentu',
                onTap: () => _open(const FwUrlPage()),
              ),
            ],
          ),
          const SectionLabel('UPnP'),
          FormCard(
            children: <Widget>[
              SettingsSwitchRow(
                title: 'UPnP',
                subtitle: 'Aplikasi bisa membuka port otomatis',
                value: _upnp,
                onChanged: _saving ? (_) {} : _saveUpnp,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
