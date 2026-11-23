import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Layar SMS PENUH (Gelombang A): daftar dari sms_data_total
/// (content di-decode hex UTF-16BE di model), kirim (SEND_SMS),
/// simpan draf (SAVE_SMS), hapus per pesan (DELETE_SMS), tandai
/// dibaca saat dibuka (SET_MSG_READ), hapus semua (DELETE_SMS
/// massal berisi semua id — v3.1; ALL_DELETE_SMS lama terbukti
/// tidak menghapus apa pun), dan pengaturan SMS
/// (SET_MESSAGE_CENTER).
/// Semua aksi tulis mencatat respons mentah ke log Diagnostik
/// lewat klien, dan daftar disegarkan setelah sukses.
///
/// v3.1 — poles profesional: header rapi (kapasitas kiri +
/// tombol segarkan ikon kanan), satu baris aksi bertema
/// (Tulis SMS cyan, Pengaturan SMS outline navy, Hapus Semua
/// outline merah lembut), pesan sebagai kartu berjarak,
/// keadaan kosong terpusat berikon.
class SmsScreen extends StatefulWidget {
  const SmsScreen({super.key});

  @override
  State<SmsScreen> createState() => _SmsScreenState();
}

class _SmsScreenState extends State<SmsScreen> {
  static const Color _primary = AppColors.primary;

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
            // v3.1.1: panel statis SettingsTextField (bukan
            // lagi OutlineInputBorder label melayang).
            SettingsTextField(
              controller: numberCtl,
              label: 'Nomor tujuan',
              hint: '08xxxxxxxxxx',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            SettingsTextField(
              controller: messageCtl,
              label: 'Isi pesan',
              maxLines: 4,
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
              // v3.1.1: panel statis SettingsTextField +
              // SettingsDropdown (pola v3.1).
              SettingsTextField(
                controller: centerCtl,
                label: 'Nomor pusat pesan (SMSC)',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              SettingsDropdown<String>(
                label: 'Validitas pesan',
                value: validity,
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
        // Hapus Semua hanya aktif bila memang ada pesan —
        // daftar kosong membuatnya nonaktif (v3.1).
        final hasMessages = (state.smsList?.isNotEmpty ?? false);
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 2),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _capacityText(state),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: canWrite ? () => state.refreshSms() : null,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Segarkan',
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: canWrite ? _showCompose : null,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Tulis SMS'),
                  ),
                  OutlinedButton.icon(
                    onPressed: canWrite ? _showSettings : null,
                    icon: const Icon(Icons.settings, size: 18),
                    label: const Text('Pengaturan SMS'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: canWrite && hasMessages
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
                    icon: const Icon(Icons.delete_sweep, size: 18),
                    label: const Text('Hapus Semua'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.55),
                      ),
                      disabledForegroundColor:
                          AppColors.danger.withValues(alpha: 0.35),
                    ),
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
      return const EmptyState(
        icon: Icons.lock_outline,
        message: 'Masuk dulu di tab Beranda untuk melihat SMS '
            'di MiFi-mu.',
      );
    }
    final list = state.smsList;
    if (list == null) {
      return const EmptyState(
        icon: Icons.sms_outlined,
        message: 'SMS belum dimuat. Tekan tombol segarkan di atas.',
      );
    }
    if (list.isEmpty) {
      return const EmptyState(
        icon: Icons.sms_outlined,
        message: 'Belum ada SMS di perangkat.\n'
            'Pesan yang masuk ke nomor SIM MiFi akan tampil di sini.',
      );
    }
    return ListView.builder(
      padding: AppSpace.page,
      itemCount: list.length,
      itemBuilder: (context, i) {
        final m = list[i];
        final unread = m.isUnread;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.md),
          child: Card(
            child: ListTile(
            onTap: unread && !state.busy
                ? () => state.markSmsRead(m)
                : null,
            leading: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // v4.0: avatar pesan = lingkaran glassy
                // gradasi + ikon, selaras bahasa desain baru.
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppGradients.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Icon(
                    Icons.message,
                    size: 20,
                    color: unread ? _primary : AppColors.textFaint,
                  ),
                ),
                if (unread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _primary,
                        border: Border.all(
                          color: AppColors.card,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              m.number.isEmpty ? '—' : m.number,
              style: TextStyle(
                fontWeight: unread ? FontWeight.bold : FontWeight.w600,
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
                      style: TextStyle(fontSize: 11, color: AppColors.textFaint),
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
          ),
        );
      },
    );
  }
}
