import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Port Mapping (D14): GET PortMapRules_0..9, saklar via
/// ADD_PORT_MAP {portMapEnabled}, tambah ADD_PORT_MAP + field
/// rule, hapus DEL_PORT_MAP {delete_id: "i;"}.
class FwPortMapPage extends StatefulWidget {
  const FwPortMapPage({super.key});

  @override
  State<FwPortMapPage> createState() => _FwPortMapPageState();
}

class _FwPortMapPageState extends State<FwPortMapPage> {
  PortMapData? _data;
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
      final d = await AppState.instance.api.getPortMap();
      if (!mounted) return;
      setState(() {
        _data = d;
        _enabled = d.enabled;
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

  Future<void> _toggle(bool v) async {
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setPortMapEnabled(v);
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) {
        setState(() => _enabled = v);
        _load();
      }
    } catch (e) {
      if (!mounted) return;
      showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(PortMapRule rule) async {
    final ok = await confirmAction(
      context,
      title: 'Hapus rule ini?',
      body: 'Port ${rule.fromPort} → ${rule.ip}:${rule.toPort} '
          '(${rule.protocol})'
          '${rule.comment.isNotEmpty ? '\nCatatan: ${rule.comment}' : ''}',
      actionLabel: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api
          .deletePortMapRules(<int>[rule.index]);
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

  Future<void> _add() async {
    final ipCtl = TextEditingController();
    final fromCtl = TextEditingController();
    final toCtl = TextEditingController();
    final commentCtl = TextEditingController();
    var protocol = 'TCP';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Tambah Port Mapping'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SettingsTextField(
                  controller: fromCtl,
                  label: 'Port luar (sumber)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: ipCtl,
                  label: 'IP tujuan (LAN)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: toCtl,
                  label: 'Port tujuan',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpace.md),
                SettingsDropdown<String>(
                  label: 'Protokol',
                  value: protocol,
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'TCP', child: Text('TCP')),
                    DropdownMenuItem(value: 'UDP', child: Text('UDP')),
                    DropdownMenuItem(
                      value: 'TCP/UDP',
                      child: Text('TCP/UDP'),
                    ),
                  ],
                  onChanged: (v) =>
                      setLocal(() => protocol = v ?? protocol),
                ),
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: commentCtl,
                  label: 'Catatan',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Tambah'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) {
      ipCtl.dispose();
      fromCtl.dispose();
      toCtl.dispose();
      commentCtl.dispose();
      return;
    }
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.addPortMapRule(
        fromPort: fromCtl.text.trim(),
        ipAddress: ipCtl.text.trim(),
        toPort: toCtl.text.trim(),
        protocol: protocol,
        comment: commentCtl.text.trim(),
      );
      if (!mounted) return;
      showSnack(context, r.message ?? '');
      if (r.ok) _load();
    } catch (e) {
      if (!mounted) return;
      showSnack(context, friendlyError(e));
    } finally {
      ipCtl.dispose();
      fromCtl.dispose();
      toCtl.dispose();
      commentCtl.dispose();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final rules = _data?.rules ?? <PortMapRule>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Port Mapping')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          FormCard(
            children: <Widget>[
              SettingsSwitchRow(
                title: 'Port mapping aktif',
                value: _enabled,
                onChanged: _saving ? (_) {} : _toggle,
              ),
            ],
          ),
          const SectionLabel('Rule'),
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
                    leading: const IconBox(Icons.alt_route),
                    title: Text(
                      'Port ${r.fromPort} → ${r.ip}:${r.toPort}',
                      style: AppText.rowTitle,
                    ),
                    subtitle: Text(
                      <String>[
                        r.protocol,
                        if (r.comment.isNotEmpty) r.comment,
                      ].join(' • '),
                      style: AppText.rowSubtitle,
                    ),
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
