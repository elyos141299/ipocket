import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../theme.dart';

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
              padding: const EdgeInsets.all(AppSpace.md),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: state.busy ? null : () => state.runFullTest(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Jalankan Tes Lengkap'),
                  ),
                  FilledButton.icon(
                    onPressed: state.busy ? null : () => state.runDiscovery(),
                    icon: const Icon(Icons.search),
                    label: const Text('Jalankan Penemuan API'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        state.busy ? null : () => state.runDiscoveryAdvanced(),
                    icon: const Icon(Icons.manage_search),
                    label: const Text('Penemuan API Lanjutan'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        state.busy ? null : () => state.runDiscoveryFinal(),
                    icon: const Icon(Icons.travel_explore),
                    label: const Text('Penemuan API Final'),
                  ),
                  FilledButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => state.runTargetedDiscovery(),
                    icon: const Icon(Icons.find_in_page),
                    label: const Text('Penemuan Terarah JS'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        state.busy ? null : () => state.runFieldProbe(),
                    icon: const Icon(Icons.radar),
                    label: const Text('Probe Field Kosong'),
                  ),
                  FilledButton.icon(
                    onPressed:
                        state.busy ? null : () => state.runMonthlyProbe(),
                    icon: const Icon(Icons.battery_charging_full),
                    label: const Text('Probe Baterai & Bulanan'),
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
                padding: const EdgeInsets.all(AppSpace.md),
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
