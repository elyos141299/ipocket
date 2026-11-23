import 'package:flutter/material.dart';

import '../app_state.dart';

/// Layar SMS: daftar pesan dari sms_data_total (content sudah di-decode
/// dari hex UTF-16BE di model). Fallback sms_page_data ditampilkan apa
/// adanya bila strukturnya tidak dikenal.
class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = AppState.instance;
      if (s.smsList == null && s.smsRawFallback == null && !s.busy) {
        s.loadSms();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: state.busy ? null : () => state.loadSms(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Muat SMS'),
                  ),
                  const SizedBox(width: 12),
                  if (state.smsList != null)
                    Text('${state.smsList!.length} pesan'),
                ],
              ),
            ),
            if (state.busy) const LinearProgressIndicator(),
            Expanded(child: _body(context, state)),
          ],
        );
      },
    );
  }

  Widget _body(BuildContext context, AppState state) {
    if (state.smsRawFallback != null) {
      // Hasil sms_page_data apa adanya (struktur tidak dikenal).
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          state.smsRawFallback!,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      );
    }
    final list = state.smsList;
    if (list == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('SMS belum dimuat. Tekan "Muat SMS".'),
        ),
      );
    }
    if (list.isEmpty) {
      return const Center(child: Text('Tidak ada SMS di perangkat.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final m = list[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.message),
            title: Text(m.number.isEmpty ? '—' : m.number),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (m.date.isNotEmpty) Text(m.date),
                const SizedBox(height: 4),
                Text(m.content),
              ],
            ),
          ),
        );
      },
    );
  }
}
