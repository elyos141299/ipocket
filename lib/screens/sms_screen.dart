import 'package:flutter/material.dart';

import '../app_state.dart';

/// Layar SMS: daftar pesan asli dari sms_data_total (content sudah
/// di-decode dari hex UTF-16BE di model) + baris kapasitas dari
/// sms_capacity_info. READ-ONLY — kirim & hapus menyusul.
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
      if (s.loggedIn && s.smsList == null && !s.busy) {
        s.refreshSms();
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
                    onPressed: (!state.loggedIn || state.busy)
                        ? null
                        : () => state.refreshSms(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Segarkan'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_capacityText(state))),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Kirim & hapus SMS menyusul di pembaruan berikutnya.',
                  style: TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ),
            ),
            if (state.busy) const LinearProgressIndicator(),
            Expanded(child: _body(context, state)),
          ],
        );
      },
    );
  }

  String _capacityText(AppState state) {
    final cap = state.smsCapacity;
    if (cap == null || cap.total == null) return '';
    final used = cap.used ?? state.smsList?.length;
    if (used == null) return 'Kapasitas ${cap.total} pesan';
    return 'Terpakai $used dari ${cap.total} pesan';
  }

  Widget _body(BuildContext context, AppState state) {
    if (!state.loggedIn) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Masuk dulu di tab Status untuk melihat SMS di MiFi-mu.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final list = state.smsList;
    if (list == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('SMS belum dimuat. Tekan "Segarkan".'),
        ),
      );
    }
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada SMS di perangkat.\n'
            'Pesan yang masuk ke nomor SIM MiFi akan tampil di sini.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final m = list[i];
        final unread = m.isUnread;
        return Card(
          child: ListTile(
            leading: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(
                  Icons.message,
                  color: unread
                      ? const Color(0xFF0288D1)
                      : Colors.black38,
                ),
                if (unread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF0288D1),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              m.number.isEmpty ? '—' : m.number,
              style: TextStyle(
                fontWeight: unread ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (m.date.isNotEmpty) Text(m.date),
                const SizedBox(height: 4),
                Text(
                  m.content,
                  style: TextStyle(
                    fontWeight:
                        unread ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
