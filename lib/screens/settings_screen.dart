import 'package:flutter/material.dart';

import '../app_state.dart';

/// Layar Pengaturan sederhana: satu field gateway.
/// Nilai hanya disimpan di memori selama aplikasi berjalan.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _gwController;

  @override
  void initState() {
    super.initState();
    _gwController = TextEditingController(text: AppState.instance.gateway);
  }

  @override
  void dispose() {
    _gwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Gateway disimpan (hanya selama aplikasi berjalan).',
                ),
              ),
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
      ],
    );
  }
}
