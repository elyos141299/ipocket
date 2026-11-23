import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';

/// Layar Diagnostik: catatan semua request aplikasi (URL lengkap,
/// status HTTP, badan respons mentah dipotong ±2000 karakter) dalam
/// teks monospace yang bisa disalin/discreenshot untuk verifikasi API.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final text = state.log.entries.isEmpty
            ? 'Belum ada catatan. Jalankan Tes Lengkap, atau muat Status/SMS.'
            : state.log.asText;
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: state.busy ? null : () => state.runFullTest(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Jalankan Tes Lengkap'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Log disalin.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin Log'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => state.clearLog(),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Bersihkan'),
                  ),
                ],
              ),
            ),
            if (state.busy) const LinearProgressIndicator(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SelectableText(
                  text,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
