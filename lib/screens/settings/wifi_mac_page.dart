import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Filter MAC (B5): GET getMacFilterInfo; POST WIFI_MAC_FILTER
/// dengan hanya daftar sesuai mode terpilih (pola pemanggil
/// WebUI). Enum mode: "1" = Daftar Putih, "2" = Daftar Hitam;
/// nilai nonaktif tidak eksplisit di JS (SEBAGIAN) — mode lain
/// ditampilkan apa adanya dan tidak diubah dari halaman ini.
///
/// ⚠️ RISIKO TERTINGGI: mode Putih tanpa MAC-mu sendiri di daftar
/// = kamu terkunci dari Wi-Fi sendiri. Karena itu mode Putih
/// memakai konfirmasi keras + daftar ditampilkan sebelum simpan.
class WifiMacPage extends StatefulWidget {
  const WifiMacPage({super.key});

  @override
  State<WifiMacPage> createState() => _WifiMacPageState();
}

class _WifiMacPageState extends State<WifiMacPage> {
  MacFilterInfo? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _mode = '2';
  List<String> _white = <String>[];
  List<String> _black = <String>[];

  static final RegExp _macRe =
      RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$');

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
      final d = await AppState.instance.api.getMacFilter();
      if (!mounted) return;
      setState(() {
        _data = d;
        _mode = (d.aclMode == '1' || d.aclMode == '2') ? d.aclMode : '2';
        _white = List<String>.from(d.whiteList);
        _black = List<String>.from(d.blackList);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat Filter MAC: $e';
        _loading = false;
      });
    }
  }

  List<String> get _activeList => _mode == '1' ? _white : _black;

  void _setActiveList(List<String> v) {
    if (_mode == '1') {
      _white = v;
    } else {
      _black = v;
    }
  }

  Future<void> _addMac() async {
    final ctl = TextEditingController();
    final mac = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Alamat MAC'),
        content: SettingsTextField(
          controller: ctl,
          label: 'Alamat MAC',
          helper: 'Format AA:BB:CC:DD:EE:FF',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctl.text.trim()),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    ctl.dispose();
    if (mac == null || mac.isEmpty) return;
    if (!_macRe.hasMatch(mac)) {
      showSnack(context, 'Format MAC tidak valid (AA:BB:CC:DD:EE:FF).');
      return;
    }
    final norm = mac.toUpperCase().replaceAll('-', ':');
    if (_activeList.any((e) => e.toUpperCase() == norm)) {
      showSnack(context, 'MAC itu sudah ada di daftar.');
      return;
    }
    if (_activeList.length >= 10) {
      showSnack(context, 'Daftar penuh (maksimum 10 entri).');
      return;
    }
    setState(() {
      final next = List<String>.from(_activeList)..add(norm);
      _setActiveList(next);
    });
  }

  Future<void> _save() async {
    final d = _data;
    if (d == null) return;
    if (_mode == '1') {
      // Konfirmasi KERAS mode Putih: tampilkan daftar final dan
      // MAC perangkat user sendiri dari GET.
      final ownMac = d.clientMac;
      final containsOwn = ownMac.isNotEmpty &&
          _white.any((e) => e.toUpperCase() == ownMac.toUpperCase());
      final ok = await confirmAction(
        context,
        title: '⚠️ Aktifkan Daftar Putih?',
        body: 'Mode Daftar Putih berarti HANYA MAC di daftar ini '
            'yang boleh menyambung ke Wi-Fi. MAC lain — termasuk '
            'HP ini bila tidak ada di daftar — AKAN TERKUNCI '
            'KELUAR.\n\n'
            'MAC perangkat ini (dari perangkat): '
            '${ownMac.isEmpty ? 'tidak terbaca' : ownMac}'
            '${containsOwn ? ' — ADA di daftar ✓' : ' — TIDAK ADA di daftar! Tambahkan dulu sebelum menyimpan.'}\n\n'
            'Daftar final (${_white.length}):\n'
            '${_white.isEmpty ? '(kosong — SEMUA perangkat akan terkunci!)' : _white.join('\n')}',
        actionLabel: 'Saya Paham, Simpan',
        danger: true,
      );
      if (!ok) return;
    } else {
      final ok = await confirmAction(
        context,
        title: 'Simpan Filter MAC?',
        body: 'Mode Daftar Hitam: MAC di daftar ini tidak bisa '
            'menyambung ke Wi-Fi.\n\n'
            'Daftar final (${_black.length}):\n'
            '${_black.isEmpty ? '(kosong)' : _black.join('\n')}',
        actionLabel: 'Simpan',
      );
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setMacFilterPage(
        aclMode: _mode,
        whiteList: _white,
        blackList: _black,
      );
      if (!mounted) return;
      showSnack(context, r.message ?? '');
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
    final rawMode = d?.aclMode ?? '';
    final otherMode = rawMode.isNotEmpty && rawMode != '1' && rawMode != '2';
    return Scaffold(
      appBar: AppBar(title: const Text('Filter MAC')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Mode Filter', top: AppSpace.sm),
          FormCard(
            children: <Widget>[
              SettingsDropdown<String>(
                label: 'Mode',
                value: _mode,
                helper: otherMode
                    ? 'Perangkat saat ini di mode "$rawMode" '
                        '(nonaktif) — memilih mode di sini dan '
                        'menyimpan akan mengaktifkannya.'
                    : null,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: '2',
                    child: Text('Daftar Hitam — blokir MAC di daftar'),
                  ),
                  DropdownMenuItem(
                    value: '1',
                    child: Text('Daftar Putih — hanya MAC di daftar'),
                  ),
                ],
                onChanged: (v) => setState(() => _mode = v ?? _mode),
              ),
              if (d != null && d.clientMac.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppSpace.md),
                Text(
                  'MAC perangkat yang sedang kamu pakai: ${d.clientMac}',
                  style: AppText.hint,
                ),
              ],
            ],
          ),
          SectionLabel(
            _mode == '1' ? 'Daftar Putih' : 'Daftar Hitam',
          ),
          Card(
            child: Column(
              children: <Widget>[
                if (_activeList.isEmpty)
                  const Padding(
                    padding: AppSpace.cardInner,
                    child: Text(
                      'Daftar kosong.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                else
                  for (var i = 0; i < _activeList.length; i++)
                    ListTile(
                      leading: const IconBox(Icons.computer_outlined),
                      title: Text(_activeList[i], style: AppText.rowTitle),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline,
                          color: AppColors.danger,
                        ),
                        tooltip: 'Hapus dari daftar',
                        onPressed: () => setState(() {
                          final next = List<String>.from(_activeList)
                            ..removeAt(i);
                          _setActiveList(next);
                        }),
                      ),
                    ),
                const Divider(height: 1),
                ListTile(
                  leading: const IconBox(Icons.add),
                  title: const Text('Tambah alamat MAC'),
                  onTap: _addMac,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Maksimum 10 entri per daftar. Perubahan daftar sisi '
            'lain (yang tidak sedang dipilih) tidak dikirim halaman '
            'ini — persis perilaku WebUI.',
            style: AppText.hint,
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(onPressed: _save, busy: _saving),
        ],
      ),
    );
  }
}
