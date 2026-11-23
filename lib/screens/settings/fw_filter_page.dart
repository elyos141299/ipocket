import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Filter Port (D14): GET IPPortFilterRules_0..9 (+v6), saklar &
/// kebijakan via BASIC_SETTING (nilai kebijakan diteruskan apa
/// adanya — enum-nya tidak terbaca), tambah via
/// ADD_IP_PORT_FILETER_V4V6, hapus v4 via DEL_IP_PORT_FILETER_V4V6.
/// Rule IPv6 ditampilkan baca-saja (format delete_id v6 tidak
/// pasti dari spek).
class FwFilterPage extends StatefulWidget {
  const FwFilterPage({super.key});

  @override
  State<FwFilterPage> createState() => _FwFilterPageState();
}

class _FwFilterPageState extends State<FwFilterPage> {
  PortFilterData? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  bool _enabled = false;

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
      final d = await AppState.instance.api.getPortFilter();
      if (!mounted) return;
      setState(() {
        _data = d;
        _enabled = d.enabled;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat Filter Port: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggle(bool v) async {
    final d = _data;
    if (d == null) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setPortFilterBasic(
        enabled: v,
        defaultPolicy: d.defaultPolicy,
      );
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) {
        setState(() => _enabled = v);
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Gagal menghubungi MiFi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(PortFilterRule rule) async {
    final ok = await confirmAction(
      context,
      title: 'Hapus rule ini?',
      body: '${rule.summary}'
          '${rule.comment.isNotEmpty ? '\nCatatan: ${rule.comment}' : ''}',
      actionLabel: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api
          .deletePortFilterRulesV4(<int>[rule.index]);
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

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const _FilterAddPage()),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final d = _data;
    final rules = d?.rulesV4 ?? <PortFilterRule>[];
    final rules6 = d?.rulesV6 ?? <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Filter Port')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          FormCard(
            children: <Widget>[
              SettingsSwitchRow(
                title: 'Filter port aktif',
                subtitle: 'Kebijakan default perangkat: '
                    '${d?.defaultPolicy.isEmpty ?? true ? '—' : d!.defaultPolicy}',
                value: _enabled,
                onChanged: _saving ? (_) {} : _toggle,
              ),
            ],
          ),
          const SectionLabel('Rule IPv4'),
          if (rules.isEmpty)
            const Card(
              child: Padding(
                padding: AppSpace.cardInner,
                child: Text(
                  'Belum ada rule.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            HubGroup(
              children: <Widget>[
                for (final r in rules)
                  ListTile(
                    leading: IconBox(
                      r.accept ? Icons.check_circle : Icons.block,
                      color: r.accept
                          ? AppColors.success
                          : AppColors.danger,
                    ),
                    title: Text(
                      r.comment.isNotEmpty
                          ? r.comment
                          : 'Rule ${r.index + 1}',
                      style: AppText.rowTitle,
                    ),
                    subtitle: Text(r.summary, style: AppText.rowSubtitle),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.danger,
                      ),
                      onPressed: _saving ? null : () => _delete(r),
                    ),
                  ),
              ],
            ),
          if (rules6.isNotEmpty) ...<Widget>[
            const SectionLabel('Rule IPv6 (baca-saja)'),
            InfoCard(
              rows: <InfoRow>[
                for (var i = 0; i < rules6.length; i++)
                  InfoRow('Rule ${i + 1}', rules6[i]),
              ],
            ),
          ],
          const SizedBox(height: AppSpace.lg),
          OutlinedButton.icon(
            onPressed: _saving ? null : _add,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Rule'),
          ),
        ],
      ),
    );
  }
}

/// Form tambah rule filter port (ADD_IP_PORT_FILETER_V4V6).
class _FilterAddPage extends StatefulWidget {
  const _FilterAddPage();

  @override
  State<_FilterAddPage> createState() => _FilterAddPageState();
}

class _FilterAddPageState extends State<_FilterAddPage> {
  final TextEditingController _macCtl = TextEditingController();
  final TextEditingController _sipCtl = TextEditingController();
  final TextEditingController _dipCtl = TextEditingController();
  final TextEditingController _sFromCtl = TextEditingController();
  final TextEditingController _sToCtl = TextEditingController();
  final TextEditingController _dFromCtl = TextEditingController();
  final TextEditingController _dToCtl = TextEditingController();
  final TextEditingController _commentCtl = TextEditingController();

  String _ipVersion = '4';
  String _protocol = 'TCP';
  String _action = '1';
  bool _saving = false;

  @override
  void dispose() {
    _macCtl.dispose();
    _sipCtl.dispose();
    _dipCtl.dispose();
    _sFromCtl.dispose();
    _sToCtl.dispose();
    _dFromCtl.dispose();
    _dToCtl.dispose();
    _commentCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.addPortFilterRule(
        ipVersion: _ipVersion,
        macAddress: _macCtl.text.trim(),
        dipAddress: _dipCtl.text.trim(),
        sipAddress: _sipCtl.text.trim(),
        dFromPort: _dFromCtl.text.trim(),
        dToPort: _dToCtl.text.trim(),
        sFromPort: _sFromCtl.text.trim(),
        sToPort: _sToCtl.text.trim(),
        action: _action,
        protocol: _protocol,
        comment: _commentCtl.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Gagal menghubungi MiFi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Rule Filter Port')),
      body: ListView(
        padding: AppSpace.page,
        children: <Widget>[
          FormCard(
            children: <Widget>[
              SettingsDropdown<String>(
                label: 'Versi IP',
                value: _ipVersion,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: '4', child: Text('IPv4')),
                  DropdownMenuItem(value: '6', child: Text('IPv6')),
                ],
                onChanged: (v) =>
                    setState(() => _ipVersion = v ?? _ipVersion),
              ),
              const SizedBox(height: AppSpace.md),
              SettingsTextField(
                controller: _sipCtl,
                label: 'IP sumber (kosong = semua)',
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SettingsTextField(
                      controller: _sFromCtl,
                      label: 'Port sumber dari',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: SettingsTextField(
                      controller: _sToCtl,
                      label: 'Port sumber s.d.',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              SettingsTextField(
                controller: _dipCtl,
                label: 'IP tujuan',
              ),
              const SizedBox(height: AppSpace.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SettingsTextField(
                      controller: _dFromCtl,
                      label: 'Port tujuan dari',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: SettingsTextField(
                      controller: _dToCtl,
                      label: 'Port tujuan s.d.',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              SettingsTextField(
                controller: _macCtl,
                label: 'Alamat MAC (opsional)',
              ),
              const SizedBox(height: AppSpace.md),
              SettingsDropdown<String>(
                label: 'Protokol',
                value: _protocol,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: 'TCP', child: Text('TCP')),
                  DropdownMenuItem(value: 'UDP', child: Text('UDP')),
                  DropdownMenuItem(value: 'TCP/UDP', child: Text('TCP/UDP')),
                  DropdownMenuItem(value: 'ICMP', child: Text('ICMP')),
                ],
                onChanged: (v) =>
                    setState(() => _protocol = v ?? _protocol),
              ),
              const SizedBox(height: AppSpace.md),
              SettingsDropdown<String>(
                label: 'Aksi',
                value: _action,
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: '1', child: Text('Terima')),
                  DropdownMenuItem(value: '0', child: Text('Tolak')),
                ],
                onChanged: (v) => setState(() => _action = v ?? _action),
              ),
              const SizedBox(height: AppSpace.md),
              SettingsTextField(
                controller: _commentCtl,
                label: 'Catatan',
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(onPressed: _save, busy: _saving, label: 'Tambah Rule'),
        ],
      ),
    );
  }
}
