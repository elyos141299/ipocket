import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

/// Layar SMS PENUH (Gelombang A): daftar dari sms_data_total
/// (content di-decode hex UTF-16BE di model), kirim (SEND_SMS),
/// simpan draf (SAVE_SMS), hapus per pesan (DELETE_SMS), tandai
/// dibaca saat dibuka (SET_MSG_READ), hapus semua
/// (ALL_DELETE_SMS), dan pengaturan SMS (SET_MESSAGE_CENTER).
/// Semua aksi tulis mencatat respons mentah ke log Diagnostik
/// lewat klien, dan daftar disegarkan setelah sukses.
class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  static const Color _primary = Color(0xFFEC008D);

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

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<bool> _confirm({
    required String title,
    required String body,
    required String actionLabel,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  // ---------- Dialog tulis SMS ----------

  Future<void> _showCompose() async {
    final numberCtl = TextEditingController();
    final messageCtl = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tulis SMS'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: numberCtl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor tujuan',
                hintText: '08xxxxxxxxxx',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageCtl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Isi pesan',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop('draft'),
            child: const Text('Simpan Draf'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('send'),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
    final number = numberCtl.text.trim();
    final message = messageCtl.text;
    numberCtl.dispose();
    messageCtl.dispose();
    if (action == null) return;
    if (number.isEmpty || message.trim().isEmpty) {
      _snack('Nomor tujuan dan isi pesan wajib diisi.');
      return;
    }
    final state = AppState.instance;
    final msg = action == 'send'
        ? await state.sendSms(number, message)
        : await state.saveSmsDraft(number, message);
    _snack(msg);
  }

  // ---------- Dialog pengaturan SMS ----------

  Future<void> _showSettings() async {
    // Nilai awal dari katalog WebUI perangkat: nomor pusat
    // +62816124. Validitas: urutan pilihan WebUI (12 Jam, 1 Hari,
    // 1 Minggu, Maksimum) dipetakan ke save_time "0".."3" —
    // pemetaan nilai persisnya tidak terbaca dari dump com.js,
    // hasil POST tercatat mentah di log untuk verifikasi.
    // Laporan pengiriman: default awal OFF — inspeksi live
    // 23 Nov 2026 membuktikan keadaan perangkat sebenarnya
    // "Nonaktif" (v1.2 keliru default ON).
    final centerCtl = TextEditingController(text: '+62816124');
    var validity = '3'; // Maksimum
    var deliveryReport = false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Pengaturan SMS'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: centerCtl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor pusat pesan (SMSC)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: validity,
                decoration: const InputDecoration(
                  labelText: 'Validitas pesan',
                  border: OutlineInputBorder(),
                ),
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem(value: '0', child: Text('12 Jam')),
                  DropdownMenuItem(value: '1', child: Text('1 Hari')),
                  DropdownMenuItem(value: '2', child: Text('1 Minggu')),
                  DropdownMenuItem(value: '3', child: Text('Maksimum')),
                ],
                onChanged: (v) =>
                    setLocal(() => validity = v ?? validity),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Laporan pengiriman'),
                value: deliveryReport,
                onChanged: (v) => setLocal(() => deliveryReport = v),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    final center = centerCtl.text.trim();
    centerCtl.dispose();
    if (saved != true) return;
    if (center.isEmpty) {
      _snack('Nomor pusat pesan wajib diisi.');
      return;
    }
    final msg = await AppState.instance.saveSmsSettings(
      saveTime: validity,
      messageCenter: center,
      statusSave: deliveryReport ? '1' : '0',
    );
    _snack(msg);
  }

  // ---------- Bangun layar ----------

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final canWrite = state.loggedIn && !state.busy;
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: canWrite ? () => state.refreshSms() : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Segarkan'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_capacityText(state))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: canWrite ? _showCompose : null,
                    icon: const Icon(Icons.edit),
                    label: const Text('Tulis SMS'),
                  ),
                  OutlinedButton.icon(
                    onPressed: canWrite ? _showSettings : null,
                    icon: const Icon(Icons.settings),
                    label: const Text('Pengaturan SMS'),
                  ),
                  OutlinedButton.icon(
                    onPressed: canWrite
                        ? () async {
                            final ok = await _confirm(
                              title: 'Hapus semua SMS?',
                              body: 'SEMUA SMS di perangkat akan '
                                  'dihapus permanen. Lanjutkan?',
                              actionLabel: 'Hapus Semua',
                            );
                            if (ok) _snack(await state.deleteAllSms());
                          }
                        : null,
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Hapus Semua'),
                  ),
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
            onTap: unread && !state.busy
                ? () => state.markSmsRead(m)
                : null,
            leading: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(
                  Icons.message,
                  color: unread ? _primary : Colors.black38,
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
                        color: _primary,
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
                if (unread)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Ketuk untuk tandai sudah dibaca',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Hapus SMS ini',
              onPressed: state.busy
                  ? null
                  : () async {
                      final ok = await _confirm(
                        title: 'Hapus SMS ini?',
                        body: 'SMS dari ${m.number.isEmpty ? '—' : m.number} '
                            'akan dihapus permanen dari perangkat.',
                        actionLabel: 'Hapus',
                      );
                      if (ok) _snack(await state.deleteSms(m));
                    },
            ),
          ),
        );
      },
    );
  }
}
