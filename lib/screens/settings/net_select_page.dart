import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../settings_models.dart';
import '../../theme.dart';
import '../../widgets.dart';

/// Pilih Jaringan (C10): SCAN_NETWORK + polling
/// m_netselect_status tiap 1000 ms selama "manual_selecting",
/// hasil dari m_netselect_contents; pilih via SET_NETWORK
/// {NetworkNumber, Rat (0/2/7), nSubrat} + polling
/// m_netselect_result (maks ±120 kali). Preferensi bearer
/// (net_select) hanya DITAMPILKAN — enum SET_BEARER_PREFERENCE
/// GELAP di spek, jadi tidak dibuat pemilih.
class NetSelectPage extends StatefulWidget {
  const NetSelectPage({super.key});

  @override
  State<NetSelectPage> createState() => _NetSelectPageState();
}

class _NetSelectPageState extends State<NetSelectPage> {
  RawMap? _prefill;
  bool _loading = true;
  String? _error;

  bool _scanning = false;
  bool _selecting = false;
  String _phase = '';
  List<NetSelectEntry> _results = <NetSelectEntry>[];
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await AppState.instance.api.getNetSelectPrefill();
      if (!mounted) return;
      setState(() {
        _prefill = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat info jaringan: $e';
        _loading = false;
      });
    }
  }

  Future<void> _scan() async {
    final api = AppState.instance.api;
    setState(() {
      _scanning = true;
      _results = <NetSelectEntry>[];
      _phase = 'Memulai pindai…';
    });
    try {
      await api.scanNetwork();
      // Polling status tiap 1000 ms selama manual_selecting.
      for (var k = 0; k < 90 && !_disposed; k++) {
        final st = await api.netSelectStatus();
        if (_disposed) return;
        setState(() => _phase = 'Memindai jaringan… (${st ?? '…'})');
        if (st != 'manual_selecting') break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (_disposed) return;
      final entries = await api.netSelectContents();
      if (!mounted) return;
      setState(() {
        _results = entries;
        _phase = entries.isEmpty
            ? 'Pindai selesai — tidak ada jaringan terbaca.'
            : 'Pindai selesai: ${entries.length} jaringan.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = 'Pindai gagal: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _select(NetSelectEntry entry) async {
    if (entry.rat != 0 && entry.rat != 2 && entry.rat != 7) {
      showSnack(context, 'Jaringan ini tidak bisa dipilih (RAT ${entry.rat}).');
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Pindah jaringan?',
      body: 'Sambungkan ke ${entry.displayName} (${entry.ratLabel}, '
          '${entry.numeric})? Koneksi data akan putus dan menyambung '
          'ulang ke jaringan ini. Lanjutkan?',
      actionLabel: 'Pindah',
    );
    if (!ok) return;
    final api = AppState.instance.api;
    setState(() {
      _selecting = true;
      _phase = 'Meminta pindah ke ${entry.displayName}…';
    });
    try {
      await api.setNetwork(entry);
      String? result;
      for (var k = 0; k < 120 && !_disposed; k++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        result = await api.netSelectResult();
        if (_disposed) return;
        setState(() => _phase = 'Menunggu hasil… (${result ?? '…'})');
        if (result == 'manual_success' || result == 'manual_fail') break;
      }
      if (!mounted) return;
      if (result == 'manual_success') {
        showSnack(context, 'Berhasil pindah ke ${entry.displayName}.');
        await AppState.instance.refreshStatus();
        _load();
      } else {
        showSnack(
          context,
          'Perpindahan gagal / belum terkonfirmasi '
          '(hasil: ${result ?? 'tidak terbaca'}). Periksa log Diagnostik.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      showSnack(context, 'Gagal menghubungi MiFi: $e');
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    final p = _prefill;
    final busy = _scanning || _selecting;
    return Scaffold(
      appBar: AppBar(title: const Text('Pilih Jaringan')),
      body: SettingsPageShell(
        loading: _loading,
        error: _error,
        loggedIn: state.loggedIn,
        onRetry: _load,
        children: <Widget>[
          const SectionLabel('Jaringan Saat Ini', top: AppSpace.sm),
          InfoCard(
            rows: <InfoRow>[
              InfoRow(
                'Mode jaringan',
                p?.s('current_network_mode') ?? '—',
              ),
              InfoRow(
                'Preferensi (net_select)',
                p?.s('net_select') ?? '—',
              ),
              InfoRow(
                'Mode pilih',
                p?.s('net_select_mode') ?? '—',
              ),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          const Text(
            'Preferensi jaringan hanya ditampilkan — daftar nilai '
            'pastinya tidak terbaca dari perangkat, jadi aplikasi '
            'tidak menebak kiriman untuk pengaturan itu.',
            style: AppText.hint,
          ),
          const SectionLabel('Pindai Jaringan'),
          FilledButton.icon(
            onPressed: busy ? null : _scan,
            icon: const Icon(Icons.radar),
            label: const Text('Pindai Jaringan Sekitar'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (_phase.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpace.md),
            Row(
              children: <Widget>[
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                if (busy) const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: Text(_phase, style: AppText.rowSubtitle),
                ),
              ],
            ),
          ],
          if (_results.isNotEmpty) ...<Widget>[
            const SectionLabel('Hasil Pindai'),
            HubGroup(
              children: <Widget>[
                for (final e in _results)
                  ListTile(
                    leading: const IconBox(Icons.cell_tower),
                    title: Text(e.displayName, style: AppText.rowTitle),
                    subtitle: Text(
                      '${e.ratLabel} • ${e.numeric}'
                      '${e.state != 0 ? ' • status ${e.state}' : ''}',
                      style: AppText.rowSubtitle,
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.textFaint,
                      size: 20,
                    ),
                    onTap: busy ? null : () => _select(e),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
