import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Wi-Fi Lanjutan (B4): negara, kanal, dan batas akses
/// (MAX_Access_num) — simpan via SET_WIFI_INFO. Mode, band, dan
/// rate ditampilkan apa adanya dan diteruskan utuh saat simpan
/// (enum-nya tidak terbaca penuh dari perangkat).
class WifiAdvancedPage extends StatefulWidget {
  const WifiAdvancedPage({super.key});

  @override
  State<WifiAdvancedPage> createState() => _WifiAdvancedPageState();
}

class _WifiAdvancedPageState extends State<WifiAdvancedPage> {
  WifiAdvance? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  String _country = '';
  String _channel = 'auto';
  int _maxAccess = 3;

  /// Pilihan negara ringkas (kode WebUI); nilai perangkat selalu
  /// ditambahkan agar tidak pernah hilang.
  static const List<String> _countries = <String>[
    'ID', 'US', 'GB', 'JP', 'SG', 'MY', 'AU', 'DE', 'FR', 'NL',
    'KR', 'CN', 'HK', 'TW', 'TH', 'VN', 'PH', 'IN',
  ];

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
      final d = await AppState.instance.api.getWifiAdvance();
      if (!mounted) return;
      setState(() {
        _data = d;
        _country = d.countryCode;
        _channel = d.channel.isEmpty ? 'auto' : d.channel;
        _maxAccess = (d.maxAccess > 0 ? d.maxAccess : d.maxStation)
            .clamp(1, d.maxStation);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat Wi-Fi Lanjutan: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final d = _data;
    if (d == null) return;
    final ok = await confirmAction(
      context,
      title: 'Simpan Wi-Fi Lanjutan?',
      body: 'Wi-Fi MiFi akan putus sebentar lalu menyambung ulang '
          'dengan pengaturan baru. Lanjutkan?',
      actionLabel: 'Simpan',
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setWifiAdvance(
        base: d,
        countryCode: _country,
        channel: _channel,
        maxAccessNum: _maxAccess,
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
    final countryOptions = <String>{
      if (_country.isNotEmpty) _country,
      ..._countries,
    }.toList();
    final channelOptions = <String>[
      'auto',
      for (var c = 1; c <= 13; c++) '$c',
      if (_channel.isNotEmpty &&
          _channel != 'auto' &&
          int.tryParse(_channel) == null)
        _channel,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Lanjutan')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Radio', top: AppSpace.sm),
          FormCard(
            children: <Widget>[
              SettingsDropdown<String>(
                label: 'Negara / wilayah',
                value: _country.isEmpty ? countryOptions.first : _country,
                items: countryOptions
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _country = v ?? _country),
              ),
              const SizedBox(height: AppSpace.md),
              SettingsDropdown<String>(
                label: 'Kanal (frekuensi)',
                value: channelOptions.contains(_channel)
                    ? _channel
                    : channelOptions.first,
                items: channelOptions
                    .map(
                      (c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(c == 'auto' ? 'Otomatis' : 'Kanal $c'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _channel = v ?? _channel),
              ),
            ],
          ),
          const SectionLabel('Batas Akses'),
          FormCard(
            children: <Widget>[
              SettingsDropdown<int>(
                label: 'Jumlah perangkat maksimum',
                value: _maxAccess,
                helper: 'Sama dengan batas akses di Wi-Fi Utama.',
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
          const SectionLabel('Dari Perangkat (baca-saja)'),
          InfoCard(
            rows: <InfoRow>[
              InfoRow('Mode nirkabel', d?.mode.isEmpty ?? true ? '—' : d!.mode),
              InfoRow('Band', d == null ? '—' : (d.band == 'a' ? '5 GHz' : '2.4 GHz')),
              InfoRow('Rate (HT MCS)', d?.rate.isEmpty ?? true ? '—' : d!.rate),
              InfoRow(
                'Lebar pita',
                d?.bandwidth.isEmpty ?? true ? '—' : d!.bandwidth,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(onPressed: _save, busy: _saving),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Mode, band, dan rate diteruskan apa adanya dari '
            'perangkat saat menyimpan — halaman ini hanya mengubah '
            'negara, kanal, dan batas akses.',
            style: AppText.hint,
          ),
        ],
      ),
    );
  }
}
