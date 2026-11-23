import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Halaman "Gateway & Aplikasi" v3.1.1 — formulir alamat
/// gateway yang sebelumnya menempel sebagai kartu tempelan di
/// bawah grid tab Tools (keluhan user: terlihat tidak
/// profesional, label field menimpa tepi). Kini jadi halaman
/// khusus yang dibuka dari tile "Gateway" di grid Tools.
///
/// Perilaku TIDAK berubah dari v3.0: nilai awal dari
/// AppState.gateway, tombol simpan memanggil setGateway dan
/// menampilkan snackbar yang sama; gateway hanya disimpan
/// selama aplikasi berjalan.
class AppGatewayPage extends StatefulWidget {
  const AppGatewayPage({super.key});

  @override
  State<AppGatewayPage> createState() => _AppGatewayPageState();
}

class _AppGatewayPageState extends State<AppGatewayPage> {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Gateway & Aplikasi')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          return ListView(
            padding: AppSpace.page,
            children: <Widget>[
              FormCard(
                children: <Widget>[
                  SettingsTextField(
                    controller: _gwController,
                    label: 'Alamat gateway MiFi',
                    helper:
                        'Contoh: 192.168.0.1 — alamat MiFi di jaringanmu.',
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: AppSpace.md),
                  FilledButton.icon(
                    onPressed: () {
                      state.setGateway(_gwController.text);
                      showSnack(
                        context,
                        'Gateway disimpan (hanya selama aplikasi '
                        'berjalan).',
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Simpan Gateway'),
                  ),
                  const SizedBox(height: AppSpace.md),
                  const Text(
                    'Catatan: gateway dan kata sandi admin tidak '
                    'disimpan permanen. Keduanya kembali ke nilai '
                    'awal (192.168.0.1 / admin) setiap aplikasi '
                    'ditutup.',
                    style: AppText.hint,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
