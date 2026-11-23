import 'package:flutter/material.dart';

import '../app_state.dart';

/// Layar Pengaturan: gateway aplikasi, plus (Gelombang A) aksi
/// perangkat — mulai ulang (REBOOT_DEVICE) dan ganti kata sandi
/// login (CHANGE_PASSWORD). Semua nilai hanya di memori selama
/// aplikasi berjalan.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _gwController;
  late final TextEditingController _oldPwController;
  late final TextEditingController _newPwController;
  late final TextEditingController _confirmPwController;
  bool _showOld = false;
  bool _showNew = false;

  @override
  void initState() {
    super.initState();
    _gwController = TextEditingController(text: AppState.instance.gateway);
    _oldPwController = TextEditingController();
    _newPwController = TextEditingController();
    _confirmPwController = TextEditingController();
  }

  @override
  void dispose() {
    _gwController.dispose();
    _oldPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _reboot(AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mulai ulang MiFi?'),
        content: const Text(
          'Perangkat akan MATI lalu menyala lagi (±1 menit). '
          'Koneksi internet dan WiFi iPocket terputus selama itu, '
          'dan sesi aplikasi ini kemungkinan berakhir. Lanjutkan?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mulai Ulang'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    _snack(await state.rebootDevice());
  }

  Future<void> _changePassword(AppState state) async {
    final oldPw = _oldPwController.text;
    final newPw = _newPwController.text;
    final confirmPw = _confirmPwController.text;
    if (oldPw.isEmpty || newPw.isEmpty) {
      _snack('Kata sandi lama dan baru wajib diisi.');
      return;
    }
    if (newPw != confirmPw) {
      _snack('Konfirmasi kata sandi baru tidak sama.');
      return;
    }
    if (newPw == oldPw) {
      _snack('Kata sandi baru harus berbeda dari yang lama.');
      return;
    }
    final msg = await state.changePassword(oldPw, newPw);
    _oldPwController.clear();
    _newPwController.clear();
    _confirmPwController.clear();
    _snack(msg);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            TextField(
              controller: _gwController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Alamat gateway MiFi',
                helperText:
                    'Contoh: 192.168.0.1 — alamat MiFi iPocket di jaringanmu.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                state.setGateway(_gwController.text);
                _snack(
                  'Gateway disimpan (hanya selama aplikasi berjalan).',
                );
              },
              icon: const Icon(Icons.save),
              label: const Text('Simpan'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Catatan: gateway dan password admin tidak disimpan permanen. '
              'Keduanya kembali ke nilai awal (192.168.0.1 / admin) setiap '
              'aplikasi ditutup.',
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Perangkat',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            if (!state.loggedIn)
              const Text(
                'Masuk dulu di tab Status untuk memakai aksi perangkat.',
                style: TextStyle(color: Colors.black54),
              )
            else ...<Widget>[
              OutlinedButton.icon(
                onPressed:
                    state.busy ? null : () => _reboot(state),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Mulai Ulang Perangkat'),
              ),
              const SizedBox(height: 24),
              Text(
                'Ganti Kata Sandi Login',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kata sandi ini adalah sandi admin MiFi (yang dipakai '
                'masuk WebUI & aplikasi ini). Setelah berhasil, kamu '
                'akan diarahkan masuk lagi dengan sandi baru.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _oldPwController,
                obscureText: !_showOld,
                decoration: InputDecoration(
                  labelText: 'Kata sandi saat ini',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showOld ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _showOld = !_showOld),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPwController,
                obscureText: !_showNew,
                decoration: InputDecoration(
                  labelText: 'Kata sandi baru',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showNew ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPwController,
                obscureText: !_showNew,
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi kata sandi baru',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    state.busy ? null : () => _changePassword(state),
                icon: const Icon(Icons.lock_reset),
                label: const Text('Ganti Kata Sandi'),
              ),
            ],
          ],
        );
      },
    );
  }
}
