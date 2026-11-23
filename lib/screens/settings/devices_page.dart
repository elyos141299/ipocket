import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../models.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Perangkat Terhubung (B6): daftar dari station_list +
/// lan_station_list, nama dari cmd=hostNameList, blokir/lepas
/// blokir lewat pola setMacFilter daftar hitam persis spek, dan
/// ganti nama via EDIT_HOSTNAME {mac, hostname} + validasi WebUI.
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<HostNameEntry> _names = <HostNameEntry>[];
  MacFilterInfo? _macInfo;

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
    final state = AppState.instance;
    try {
      await state.refreshStatus();
      final api = state.api;
      final names = await api.getHostNames();
      final mac = await api.getMacFilter();
      if (!mounted) return;
      setState(() {
        _names = names;
        _macInfo = mac;
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

  String _nameFor(ConnectedDevice d) {
    final mac = d.macAddr.toUpperCase();
    for (final n in _names) {
      if (n.mac.toUpperCase() == mac && n.hostname.isNotEmpty) {
        return n.hostname;
      }
    }
    return d.displayName;
  }

  /// Nama host pendamping MAC di daftar hitam paralel ('' bila
  /// tidak ada / tidak sejajar).
  String _blockedHostFor(String mac) {
    final info = _macInfo;
    if (info == null) return '';
    final idx =
        info.blackList.indexWhere((e) => e.toUpperCase() == mac.toUpperCase());
    if (idx < 0 || idx >= info.blackHosts.length) return '';
    return info.blackHosts[idx];
  }

  bool _isBlocked(String mac) {
    final info = _macInfo;
    if (info == null || info.aclMode != '2') return false;
    return info.blackList.any((e) => e.toUpperCase() == mac.toUpperCase());
  }

  /// Bangun ulang daftar hitam (MAC + hostname paralel) lalu
  /// kirim pola B6 persis.
  Future<void> _setBlocked(ConnectedDevice d, bool block) async {
    final info = _macInfo;
    if (info == null) return;
    final macs = List<String>.from(info.blackList);
    final hosts = List<String>.from(info.blackHosts);
    // Samakan panjang kedua daftar paralel.
    while (hosts.length < macs.length) {
      hosts.add('');
    }
    final idx =
        macs.indexWhere((e) => e.toUpperCase() == d.macAddr.toUpperCase());
    if (block && idx < 0) {
      macs.add(d.macAddr);
      hosts.add(_nameFor(d) == '—' ? '' : _nameFor(d));
    } else if (!block && idx >= 0) {
      macs.removeAt(idx);
      if (idx < hosts.length) hosts.removeAt(idx);
    } else {
      return;
    }
    final ok = await confirmAction(
      context,
      title: block ? 'Blokir perangkat ini?' : 'Lepas blokir?',
      body: block
          ? '${_nameFor(d)} (${d.macAddr}) tidak akan bisa '
              'menyambung ke Wi-Fi iPocket sampai blokir dilepas. '
              'Perangkat yang sedang kamu pakai untuk membuka '
              'aplikasi ini JANGAN diblokir. Lanjutkan?'
          : '${_nameFor(d)} (${d.macAddr}) boleh menyambung lagi '
              'ke Wi-Fi iPocket. Lanjutkan?',
      actionLabel: block ? 'Blokir' : 'Lepas Blokir',
      danger: block,
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api
          .setBlacklist(macs: macs, hosts: hosts);
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

  static final RegExp _forbidden = RegExp(r'''[*$\[&:;,<>'"\\`￥]''');

  Future<void> _rename(ConnectedDevice d) async {
    final ctl = TextEditingController(text: _nameFor(d) == '—' ? '' : _nameFor(d));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Nama Perangkat'),
        content: SettingsTextField(
          controller: ctl,
          label: 'Nama baru',
          helper: 'Tanpa spasi di awal/akhir; tanpa karakter '
              '* \$ [ & : , ; < > \' " \\ ` ￥',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (name == null) return;
    if (name.isEmpty || name.trim() != name) {
      showSnack(context, 'Nama tidak boleh kosong / berawalan-spasi.');
      return;
    }
    if (_forbidden.hasMatch(name)) {
      showSnack(context, 'Nama mengandung karakter yang dilarang perangkat.');
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.editHostName(d.macAddr, name);
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

  Widget _deviceTile(ConnectedDevice d, bool isWifi) {
    final blocked = _isBlocked(d.macAddr);
    return ListTile(
      leading: IconBox(
        isWifi ? Icons.wifi : Icons.cable,
        color: blocked ? AppColors.danger : AppColors.accent,
      ),
      title: Text(
        _nameFor(d),
        style: AppText.rowTitle.copyWith(
          color: blocked ? AppColors.danger : AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        <String>[
          if (d.ipAddr.isNotEmpty) d.ipAddr,
          if (d.macAddr.isNotEmpty) d.macAddr,
          isWifi ? 'WiFi' : 'Kabel',
          if (blocked) 'DIBLOKIR',
        ].join(' • '),
        style: AppText.rowSubtitle,
      ),
      trailing: PopupMenuButton<String>(
        enabled: !_saving,
        onSelected: (v) {
          if (v == 'rename') _rename(d);
          if (v == 'block') _setBlocked(d, true);
          if (v == 'unblock') _setBlocked(d, false);
        },
        itemBuilder: (ctx) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'rename',
            child: Text('Ganti nama'),
          ),
          if (isWifi && !blocked)
            const PopupMenuItem<String>(
              value: 'block',
              child: Text('Blokir perangkat'),
            ),
          if (isWifi && blocked)
            const PopupMenuItem<String>(
              value: 'unblock',
              child: Text('Lepas blokir'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perangkat Terhubung'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final wifi = state.wifiStations;
          final lan = state.lanStations;
          final blockedMacs = (_macInfo?.aclMode == '2')
              ? _macInfo!.blackList
              : <String>[];
          final connectedMacs = <String>{
            for (final d in wifi) d.macAddr.toUpperCase(),
            for (final d in lan) d.macAddr.toUpperCase(),
          };
          final blockedOffline = blockedMacs
              .where((m) => !connectedMacs.contains(m.toUpperCase()))
              .toList();
          return SettingsPageShell(
            loading: _loading,
            error: _error,
            loggedIn: state.loggedIn,
            onRetry: _load,
            children: <Widget>[
              const SectionLabel('Sedang Terhubung', top: AppSpace.sm),
              if (wifi.isEmpty && lan.isEmpty)
                const Card(
                  child: Padding(
                    padding: AppSpace.cardInner,
                    child: Text(
                      'Tidak ada perangkat terbaca saat ini.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                HubGroup(
                  children: <Widget>[
                    for (final d in wifi) _deviceTile(d, true),
                    for (final d in lan) _deviceTile(d, false),
                  ],
                ),
              if (blockedOffline.isNotEmpty) ...<Widget>[
                const SectionLabel('Diblokir (tidak terhubung)'),
                HubGroup(
                  children: <Widget>[
                    for (var i = 0; i < blockedOffline.length; i++)
                      ListTile(
                        leading: const IconBox(
                          Icons.block,
                          color: AppColors.danger,
                        ),
                        title: Text(
                          _blockedHostFor(blockedOffline[i]).isNotEmpty
                              ? _blockedHostFor(blockedOffline[i])
                              : blockedOffline[i],
                          style: AppText.rowTitle,
                        ),
                        subtitle: Text(
                          blockedOffline[i],
                          style: AppText.rowSubtitle,
                        ),
                        trailing: TextButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  final mac = blockedOffline[i];
                                  _setBlocked(
                                    ConnectedDevice(
                                      hostname: '',
                                      ipAddr: '',
                                      macAddr: mac,
                                      devType: 'wifi',
                                    ),
                                    false,
                                  );
                                },
                          child: const Text('Lepas'),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpace.md),
              const Text(
                'Blokir memakai Filter MAC mode Daftar Hitam: '
                'mengaktifkan blokir pertama kali akan mengganti '
                'mode Filter MAC menjadi Daftar Hitam.',
                style: AppText.hint,
              ),
            ],
          );
        },
      ),
    );
  }
}
