import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// APN (C11): daftar profil dari APN_configtmp0..19 (pemisah
/// "($)"); simpan / jadikan default / hapus via APN_PROC_EX
/// persis spek. ppp_auth_mode: opsi tulis NONE/CHAP/PAP dari
/// inspeksi live (ejaan SEBAGIAN — nilai perangkat ditampilkan
/// apa adanya dan dipertahankan bila tidak diubah).
class NetApnPage extends StatefulWidget {
  const NetApnPage({super.key});

  @override
  State<NetApnPage> createState() => _NetApnPageState();
}

class _NetApnPageState extends State<NetApnPage> {
  ApnData? _data;
  bool _loading = true;
  bool _saving = false;
  String? _error;

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
      final d = await AppState.instance.api.getApn();
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat profil APN: $e';
        _loading = false;
      });
    }
  }

  Future<void> _edit(ApnProfile? profile) async {
    final d = _data;
    if (d == null) return;
    final index = profile?.index ?? d.firstEmptyIndex;
    if (index < 0) {
      showSnack(context, 'Slot profil penuh (20). Hapus dulu profil lama.');
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => _ApnEditPage(
          index: index,
          profile: profile,
          ipv6Profile: d.ipv6Profile(index),
        ),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _setDefault(ApnProfile p) async {
    final d = _data;
    if (d == null) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.setDefaultApn(
        apnMode: d.apnMode.isEmpty ? 'manual' : d.apnMode,
        pdpType: p.pdpType,
        index: p.index,
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

  Future<void> _delete(ApnProfile p) async {
    final ok = await confirmAction(
      context,
      title: 'Hapus profil APN?',
      body: 'Profil "${p.profileName}" akan dihapus dari '
          'perangkat. Lanjutkan?',
      actionLabel: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.deleteApn(p.index);
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
    final profiles = d?.profiles ?? <ApnProfile>[];
    final currentIdx = int.tryParse(d?.currentIndex ?? '');
    return Scaffold(
      appBar: AppBar(title: const Text('APN')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Profil APN', top: AppSpace.sm),
          if (profiles.isEmpty)
            const Card(
              child: Padding(
                padding: AppSpace.cardInner,
                child: Text(
                  'Tidak ada profil APN terbaca dari perangkat.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            HubGroup(
              children: <Widget>[
                for (final p in profiles)
                  ListTile(
                    leading: IconBox(
                      p.index == currentIdx
                          ? Icons.check_circle
                          : Icons.public,
                      color: p.index == currentIdx
                          ? AppColors.success
                          : AppColors.accent,
                    ),
                    title: Text(
                      p.profileName.isEmpty ? '(tanpa nama)' : p.profileName,
                      style: AppText.rowTitle,
                    ),
                    subtitle: Text(
                      <String>[
                        if (p.wanApn.isNotEmpty) p.wanApn,
                        p.pdpType,
                        if (p.index == currentIdx) 'AKTIF',
                      ].join(' • '),
                      style: AppText.rowSubtitle,
                    ),
                    trailing: PopupMenuButton<String>(
                      enabled: !_saving,
                      onSelected: (v) {
                        if (v == 'edit') _edit(p);
                        if (v == 'default') _setDefault(p);
                        if (v == 'delete') _delete(p);
                      },
                      itemBuilder: (ctx) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Ubah profil'),
                        ),
                        if (p.index != currentIdx)
                          const PopupMenuItem<String>(
                            value: 'default',
                            child: Text('Jadikan default'),
                          ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Hapus profil'),
                        ),
                      ],
                    ),
                    onTap: () => _edit(p),
                  ),
              ],
            ),
          const SizedBox(height: AppSpace.lg),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _edit(null),
            icon: const Icon(Icons.add),
            label: const Text('Tambah Profil APN'),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            'Mode APN perangkat: ${d?.apnMode ?? '—'} • '
            'Indeks aktif: ${d?.currentIndex ?? '—'}',
            style: AppText.hint,
          ),
        ],
      ),
    );
  }
}

/// Form ubah/tambah profil APN (APN_PROC_EX save).
class _ApnEditPage extends StatefulWidget {
  const _ApnEditPage({
    required this.index,
    required this.profile,
    required this.ipv6Profile,
  });

  final int index;
  final ApnProfile? profile;
  final ApnProfile? ipv6Profile;

  @override
  State<_ApnEditPage> createState() => _ApnEditPageState();
}

class _ApnEditPageState extends State<_ApnEditPage> {
  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _apnCtl = TextEditingController();
  final TextEditingController _userCtl = TextEditingController();
  final TextEditingController _pwCtl = TextEditingController();
  final TextEditingController _dns1Ctl = TextEditingController();
  final TextEditingController _dns2Ctl = TextEditingController();

  String _pdpType = 'IP';
  String _auth = 'NONE';
  bool _saving = false;

  static const List<String> _authModes = <String>['NONE', 'CHAP', 'PAP'];
  static const List<String> _pdpTypes = <String>['IP', 'IPv6', 'IPv4v6'];

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    if (p != null) {
      _nameCtl.text = p.profileName;
      _apnCtl.text = p.wanApn;
      _userCtl.text = p.username;
      _pwCtl.text = p.password;
      _dns1Ctl.text = p.dns1;
      _dns2Ctl.text = p.dns2;
      if (_pdpTypes.contains(p.pdpType)) _pdpType = p.pdpType;
      final a = p.authMode.toUpperCase();
      if (_authModes.contains(a)) _auth = a;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _apnCtl.dispose();
    _userCtl.dispose();
    _pwCtl.dispose();
    _dns1Ctl.dispose();
    _dns2Ctl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtl.text.trim().isEmpty) {
      showSnack(context, 'Nama profil wajib diisi.');
      return;
    }
    final v6 = widget.ipv6Profile;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.saveApn(
        index: widget.index,
        profileName: _nameCtl.text.trim(),
        wanApn: _apnCtl.text.trim(),
        pdpType: _pdpType,
        authMode: _auth,
        username: _userCtl.text,
        password: _pwCtl.text,
        ipv6WanApn: v6?.wanApn ?? _apnCtl.text.trim(),
        ipv6AuthMode: (v6?.authMode.toUpperCase().isNotEmpty ?? false)
            ? v6!.authMode.toUpperCase()
            : _auth,
        ipv6Username: v6?.username ?? _userCtl.text,
        ipv6Password: v6?.password ?? _pwCtl.text,
        dnsMode: widget.profile?.dnsMode ?? '',
        dns1: _dns1Ctl.text.trim(),
        dns2: _dns2Ctl.text.trim(),
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
      appBar: AppBar(
        title: Text(
          widget.profile == null ? 'Tambah Profil APN' : 'Ubah Profil APN',
        ),
      ),
      body: ListView(
        padding: AppSpace.page,
        children: <Widget>[
          FormCard(
            children: <Widget>[
              SettingsTextField(
                controller: _nameCtl,
                label: 'Nama profil',
              ),
              const SizedBox(height: AppSpace.md),
              SettingsTextField(
                controller: _apnCtl,
                label: 'APN',
              ),
              const SizedBox(height: AppSpace.md),
              SettingsDropdown<String>(
                label: 'Jenis PDP',
                value: _pdpType,
                items: _pdpTypes
                    .map(
                      (t) => DropdownMenuItem<String>(
                        value: t,
                        child: Text(t == 'IP' ? 'IPv4 saja (IP)' : t),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _pdpType = v ?? _pdpType),
              ),
              const SizedBox(height: AppSpace.md),
              SettingsDropdown<String>(
                label: 'Otentikasi',
                value: _auth,
                items: _authModes
                    .map(
                      (t) => DropdownMenuItem<String>(
                        value: t,
                        child: Text(t),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _auth = v ?? _auth),
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
              if (_pdpType == 'IPv4v6') ...<Widget>[
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: _dns1Ctl,
                  label: 'DNS utama (manual)',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpace.md),
                SettingsTextField(
                  controller: _dns2Ctl,
                  label: 'DNS cadangan (manual)',
                  keyboardType: TextInputType.number,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Untuk jenis IPv6/IPv4v6, nilai IPv6 diambil dari '
            'profil IPv6 pada indeks yang sama bila ada; selain '
            'itu disamakan dengan nilai di atas.',
            style: AppText.hint,
          ),
          const SizedBox(height: AppSpace.xl),
          SaveButton(onPressed: _save, busy: _saving),
        ],
      ),
    );
  }
}
