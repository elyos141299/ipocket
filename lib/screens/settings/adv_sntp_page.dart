import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Waktu / SNTP (D15): GET grup getSntpParams lengkap; POST SNTP
/// persis spek — timezone dikirim sebagai gabungan
/// "<nilai>_<index>" yang dibelah API, TANPA field detik.
/// Zona waktu ditampilkan apa adanya (daftar 75 zona tidak
/// tersedia di API) dan diteruskan utuh saat simpan. Setelah
/// buka & simpan, SNTP_Getdatastatic dipanggil seperti WebUI.
class AdvSntpPage extends StatefulWidget {
  const AdvSntpPage({super.key});

  @override
  State<AdvSntpPage> createState() => _AdvSntpPageState();
}

class _AdvSntpPageState extends State<AdvSntpPage> {
  final List<TextEditingController> _serverCtls =
      List<TextEditingController>.generate(3, (_) => TextEditingController());
  final List<TextEditingController> _otherCtls =
      List<TextEditingController>.generate(3, (_) => TextEditingController());
  final TextEditingController _yearCtl = TextEditingController();
  final TextEditingController _monthCtl = TextEditingController();
  final TextEditingController _dayCtl = TextEditingController();
  final TextEditingController _hourCtl = TextEditingController();
  final TextEditingController _minuteCtl = TextEditingController();

  SntpInfo? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  String _mode = 'auto';
  bool _dst = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _serverCtls) {
      c.dispose();
    }
    for (final c in _otherCtls) {
      c.dispose();
    }
    _yearCtl.dispose();
    _monthCtl.dispose();
    _dayCtl.dispose();
    _hourCtl.dispose();
    _minuteCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = AppState.instance.api;
      await api.sntpRefreshTime();
      final d = await api.getSntp();
      if (!mounted) return;
      setState(() {
        _data = d;
        _mode = d.mode == 'manual' ? 'manual' : 'auto';
        _dst = d.dstEnabled;
        _serverCtls[0].text = d.server0;
        _serverCtls[1].text = d.server1;
        _serverCtls[2].text = d.server2;
        _otherCtls[0].text = d.other0;
        _otherCtls[1].text = d.other1;
        _otherCtls[2].text = d.other2;
        _yearCtl.text = d.year;
        _monthCtl.text = d.month;
        _dayCtl.text = d.day;
        _hourCtl.text = d.hour;
        _minuteCtl.text = d.minute;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat pengaturan waktu: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    final d = _data;
    if (d == null) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setSntp(
        mode: _mode,
        servers: _serverCtls.map((c) => c.text.trim()).toList(),
        otherServers: _otherCtls.map((c) => c.text.trim()).toList(),
        timezoneCombined: '${d.timezone}_${d.timezoneIndex}',
        dstEnabled: _dst,
        year: _yearCtl.text.trim(),
        month: _monthCtl.text.trim(),
        day: _dayCtl.text.trim(),
        hour: _hourCtl.text.trim(),
        minute: _minuteCtl.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) {
        await AppState.instance.api.sntpRefreshTime();
        _load();
      }
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
    return Scaffold(
      appBar: AppBar(title: const Text('Waktu (SNTP)')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Waktu Perangkat', top: AppSpace.sm),
          InfoCard(
            rows: <InfoRow>[
              InfoRow('Sekarang', d?.deviceTime ?? '—'),
              InfoRow(
                'Zona waktu',
                d == null || d.timezone.isEmpty
                    ? '—'
                    : '${d.timezone} (indeks ${d.timezoneIndex})',
              ),
              InfoRow(
                'Hasil proses terakhir',
                d?.processResult.isEmpty ?? true ? '—' : d!.processResult,
              ),
            ],
          ),
          const SectionLabel('Mode'),
          FormCard(
            children: <Widget>[
              SettingsDropdown<String>(
                label: 'Mode atur waktu',
                value: _mode,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(
                    value: 'auto',
                    child: Text('Otomatis (SNTP)'),
                  ),
                  DropdownMenuItem(
                    value: 'manual',
                    child: Text('Manual'),
                  ),
                ],
                onChanged: (v) => setState(() => _mode = v ?? _mode),
              ),
              const SizedBox(height: AppSpace.sm),
              SettingsSwitchRow(
                title: 'Daylight Saving (DST)',
                value: _dst,
                onChanged: (v) => setState(() => _dst = v),
              ),
            ],
          ),
          if (_mode == 'auto') ...<Widget>[
            const SectionLabel('Server SNTP'),
            FormCard(
              children: <Widget>[
                for (var i = 0; i < 3; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: AppSpace.md),
                  SettingsTextField(
                    controller: _serverCtls[i],
                    label: 'Server ${i + 1}',
                  ),
                ],
                const SizedBox(height: AppSpace.md),
                for (var i = 0; i < 3; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: AppSpace.md),
                  SettingsTextField(
                    controller: _otherCtls[i],
                    label: 'Server lain ${i + 1}',
                  ),
                ],
              ],
            ),
          ],
          if (_mode == 'manual') ...<Widget>[
            const SectionLabel('Atur Waktu Manual'),
            FormCard(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SettingsTextField(
                        controller: _dayCtl,
                        label: 'Tanggal',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: SettingsTextField(
                        controller: _monthCtl,
                        label: 'Bulan',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: SettingsTextField(
                        controller: _yearCtl,
                        label: 'Tahun',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SettingsTextField(
                        controller: _hourCtl,
                        label: 'Jam',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: SettingsTextField(
                        controller: _minuteCtl,
                        label: 'Menit',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.md),
          const Text(
            'Zona waktu diteruskan apa adanya dari perangkat '
            '(daftar zona lengkap hanya ada di WebUI).',
            style: AppText.hint,
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(onPressed: _save, busy: _saving),
        ],
      ),
    );
  }
}
