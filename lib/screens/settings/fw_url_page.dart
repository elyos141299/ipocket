import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../friendly_error.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Filter URL (D14): GET cmd=websURLFilters (satu string ";"),
/// tambah URL_FILTER_ADD {addURLFilter}, hapus URL_FILTER_DELETE
/// {url_filter_delete_id: "i;"}. Tanpa saklar induk (sesuai
/// WebUI); maksimum aturan ±10 dari konfigurasi perangkat.
class FwUrlPage extends StatefulWidget {
  const FwUrlPage({super.key});

  @override
  State<FwUrlPage> createState() => _FwUrlPageState();
}

class _FwUrlPageState extends State<FwUrlPage> {
  List<String> _urls = <String>[];
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
      final urls = await AppState.instance.api.getUrlFilters();
      if (!mounted) return;
      setState(() {
        _urls = urls;
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

  Future<void> _add() async {
    final ctl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah URL Diblokir'),
        content: SettingsTextField(
          controller: ctl,
          label: 'URL / domain',
          helper: 'Contoh: contoh-situs.com',
          keyboardType: TextInputType.url,
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
    if (url == null || url.isEmpty) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.addUrlFilter(url);
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

  Future<void> _delete(int index) async {
    final ok = await confirmAction(
      context,
      title: 'Hapus URL ini?',
      body: '"${_urls[index]}" tidak akan diblokir lagi.',
      actionLabel: 'Hapus',
      danger: true,
    );
    if (!ok) return;
    setState(() => _saving = true);
    try {
      final r = await AppState.instance.api.deleteUrlFilters(<int>[index]);
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

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Filter URL')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('URL Diblokir', top: AppSpace.sm),
          if (_urls.isEmpty)
            const Card(
              child: Padding(
                padding: AppSpace.cardInner,
                child: Text(
                  'Belum ada URL yang diblokir.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            HubGroup(
              children: <Widget>[
                for (var i = 0; i < _urls.length; i++)
                  ListTile(
                    leading: const IconBox(Icons.link_off),
                    title: Text(_urls[i], style: AppText.rowTitle),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppColors.danger,
                      ),
                      onPressed: _saving ? null : () => _delete(i),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: AppSpace.lg),
          OutlinedButton.icon(
            onPressed: _saving ? null : _add,
            icon: const Icon(Icons.add),
            label: const Text('Tambah URL'),
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Maksimum ±10 aturan mengikuti konfigurasi perangkat.',
            style: AppText.hint,
          ),
        ],
      ),
    );
  }
}
