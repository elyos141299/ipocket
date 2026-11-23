import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'settings/devices_page.dart';
import 'settings/system_page.dart';
import 'settings/wifi_power_page.dart';

// Palet Beranda dari token terpusat theme.dart v3.0 — navy
// Ookla + cyan. Nama lokal dipertahankan agar isi layar ringkas.
const Color _primary = AppColors.primary;
const Color _accent = AppColors.accent;
const Color _ink = AppColors.textPrimary;
const Color _inkSoft = AppColors.textSecondary;
const Color _inkFaint = AppColors.textFaint;
const Color _headerTop = AppColors.header;
const Color _headerBottom = AppColors.bg;
const Color _tileIcon = AppColors.accent;

String _or(String? v) => (v == null || v.isEmpty) ? '—' : v;

String _fmtRate(int? v) {
  if (v == null) return '—';
  if (v < 1024) return '$v B/s';
  if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB/s';
  return '${(v / (1024 * 1024)).toStringAsFixed(2)} MB/s';
}

String _fmtBytes(int? v) {
  if (v == null) return '—';
  if (v < 1024) return '$v B';
  if (v < 1024 * 1024) return '${(v / 1024).toStringAsFixed(1)} KB';
  if (v < 1024 * 1024 * 1024) {
    return '${(v / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(v / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String _fmtUptime(int? seconds) {
  if (seconds == null) return '—';
  final d = Duration(seconds: seconds);
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) return '$h jam $m menit';
  if (m > 0) return '$m menit $s detik';
  return '$s detik';
}

/// Beranda v3.0 (dulu "Status"): kartu sambutan + login sebelum
/// masuk; setelah masuk tampil header perangkat, GAUGE setengah
/// lingkaran ala Ookla (total sesi + kecepatan live), 3 kartu
/// statistik yang bisa diketuk (Baterai/Sinyal/Perangkat), tombol
/// Sambung/Putus, kartu perangkat terhubung, dan detail SSID.
/// Struktur mengikuti tpMiFi; data & logika identik v2.0.
/// Auto-refresh 5 detik selama tab ini tampil dan sudah login.
class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key, this.active = true});

  /// True bila tab Status sedang tampil (dari AppShell).
  final bool active;

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  late final TextEditingController _pwController;
  bool _showPassword = false;
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _pwController =
        TextEditingController(text: AppState.instance.adminPassword);
    AppState.instance.addListener(_syncAutoRefresh);
    _syncAutoRefresh();
  }

  @override
  void didUpdateWidget(StatusScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAutoRefresh();
  }

  @override
  void dispose() {
    AppState.instance.removeListener(_syncAutoRefresh);
    _autoTimer?.cancel();
    _pwController.dispose();
    super.dispose();
  }

  /// Nyalakan/matikan timer auto-refresh mengikuti keadaan:
  /// hanya jalan saat tab tampil DAN sudah login.
  void _syncAutoRefresh() {
    final shouldRun = widget.active && AppState.instance.loggedIn;
    if (shouldRun && _autoTimer == null) {
      _autoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        final s = AppState.instance;
        if (widget.active && s.loggedIn && !s.busy) {
          s.refreshStatus();
        }
      });
    } else if (!shouldRun && _autoTimer != null) {
      _autoTimer?.cancel();
      _autoTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: state.loggedIn
              ? _dashboard(context, state)
              : <Widget>[_welcomeCard(context, state)],
        );
      },
    );
  }

  // ---------- Keadaan belum login ----------

  Widget _welcomeCard(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Center(child: WifiLogoMark(size: 72)),
            const SizedBox(height: 12),
            Text(
              'iPocket',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Panel pantau MiFi Advan iPocket MF01.\n'
              'Masuk dengan kata sandi admin perangkatmu.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pwController,
              obscureText: !_showPassword,
              onChanged: (v) => state.adminPassword = v,
              onSubmitted: (_) {
                if (!state.busy) state.login();
              },
              decoration: InputDecoration(
                labelText: 'Kata sandi admin MiFi',
                helperText: 'Hanya disimpan selama aplikasi berjalan.',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (state.loginMessage != null) ...<Widget>[
              Text(
                state.loginMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: state.busy ? null : () => state.login(),
              icon: const Icon(Icons.login),
              label: const Text('Masuk'),
            ),
            const SizedBox(height: 8),
            if (state.busy) const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Gateway: ${state.gateway} — pastikan HP terhubung ke '
              'WiFi iPocket.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Keadaan sudah login (dashboard) ----------

  List<Widget> _dashboard(BuildContext context, AppState state) {
    final s = state.status;
    final widgets = <Widget>[
      _headerCard(context, s),
      const SizedBox(height: 12),
      Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'Diperbarui otomatis tiap 5 detik.',
              style: TextStyle(color: _inkSoft),
            ),
          ),
          OutlinedButton.icon(
            onPressed: state.busy ? null : () => state.refreshStatus(),
            icon: const Icon(Icons.refresh),
            label: const Text('Segarkan'),
          ),
        ],
      ),
      const SizedBox(height: 12),
    ];
    if (state.busy) {
      widgets.add(const LinearProgressIndicator());
      widgets.add(const SizedBox(height: 12));
    }
    if (state.lastError != null) {
      widgets.add(Text(
        state.lastError!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ));
      widgets.add(const SizedBox(height: 8));
    }
    if (s == null) {
      widgets.add(const Text('Memuat status perangkat…'));
    } else {
      widgets.addAll(<Widget>[
        _gaugeCard(context, s),
        const SizedBox(height: 12),
        _statsRow(context, state, s),
        const SizedBox(height: 12),
        _connectionButton(context, state, s),
        const SizedBox(height: 12),
        _devicesCard(context, state),
        const SizedBox(height: 12),
        _detailCard(context, state, s),
      ]);
    }
    return widgets;
  }

  Widget _headerCard(BuildContext context, DeviceStatus? s) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_headerTop, _headerBottom],
        ),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Advan iPocket',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_or(s?.networkProvider)} • ${_or(s?.networkType)}',
                  style: const TextStyle(color: _inkSoft),
                ),
                const SizedBox(height: 2),
                Text(
                  _or(s?.connectionLabel),
                  style: const TextStyle(color: _inkSoft),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _signalBars(s?.signalBar),
              const SizedBox(height: 4),
              Text(
                s?.signalDbm == null ? '—' : '${s!.signalDbm} dBm',
                style: const TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// True bila data sedang tersambung, dari ppp_status
  /// ("ppp_connected"). "ppp_disconnected" juga mengandung kata
  /// "connected" — cek kata putusnya lebih dulu.
  bool _isConnected(DeviceStatus s) {
    final ppp = (s.pppStatus ?? '').toLowerCase();
    if (ppp.contains('disconnected')) return false;
    if (ppp.contains('connected')) return true;
    return s.connectionLabel == 'Terhubung';
  }

  /// Tombol Sambung/Putus (CONNECT_NETWORK / DISCONNECT_NETWORK)
  /// mengikuti keadaan koneksi saat ini.
  Widget _connectionButton(
    BuildContext context,
    AppState state,
    DeviceStatus s,
  ) {
    final connected = _isConnected(s);
    // v3.0: gaya pil outline cyan ala Ookla — label & perilaku
    // (toggleConnection + snackbar) sama persis seperti v2.0.
    final pillStyle = OutlinedButton.styleFrom(
      foregroundColor: _primary,
      side: const BorderSide(color: _primary, width: 1.4),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    );
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(
            connected ? Icons.link : Icons.link_off,
            color: connected ? _tileIcon : _inkFaint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              connected
                  ? 'Data tersambung'
                  : 'Data terputus',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
          if (connected)
            OutlinedButton.icon(
              onPressed: state.busy
                  ? null
                  : () async {
                      final msg = await state.toggleConnection(false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      }
                    },
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Putuskan'),
              style: pillStyle,
            )
          else
            OutlinedButton.icon(
              onPressed: state.busy
                  ? null
                  : () async {
                      final msg = await state.toggleConnection(true);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      }
                    },
              icon: const Icon(Icons.power_settings_new),
              label: const Text('Sambungkan'),
              style: pillStyle,
            ),
        ],
      ),
    );
  }

  /// Gauge Beranda v3.0 ala Ookla: busur setengah lingkaran
  /// gradasi cyan → biru → ungu; tengahnya total SESI berjalan
  /// (realtime_tx_bytes + realtime_rx_bytes) + kecepatan live
  /// ↓/↑. (Data bulanan tetap tampil di kartu detail di bawah —
  /// data_counter perangkat user terbukti kosong karena rencana
  /// Manajemen Data nonaktif.)
  Widget _gaugeCard(BuildContext context, DeviceStatus s) {
    final hasSession = s.txBytes != null || s.rxBytes != null;
    final totalSession = (s.txBytes ?? 0) + (s.rxBytes ?? 0);
    // Skala lunak gauge: fraksi busur = total sesi terhadap
    // patokan tampilan 1 GB, dibatasi maksimal 100% (cap) —
    // murni patokan visual, bukan batas data perangkat.
    const scaleBytes = 1024 * 1024 * 1024;
    final fraction =
        (totalSession / scaleBytes).clamp(0.0, 1.0).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          children: <Widget>[
            SizedBox(
              width: 260,
              height: 148,
              child: Stack(
                children: <Widget>[
                  CustomPaint(
                    size: const Size(260, 148),
                    painter: _GaugePainter(fraction: fraction),
                  ),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        const Text(
                          'TOTAL SESI INI',
                          style: TextStyle(
                            color: _inkSoft,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasSession ? _fmtBytes(totalSession) : '—',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '↓ ${_fmtRate(s.rxRate)}  •  '
                          '↑ ${_fmtRate(s.txRate)}',
                          style: const TextStyle(
                            color: _inkSoft,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Baris 3 kartu statistik Beranda v3.0 (ala mockup Ookla):
  /// BATERAI, SINYAL, PERANGKAT — masing-masing bisa diketuk
  /// menuju halaman terkait.
  Widget _statsRow(BuildContext context, AppState state, DeviceStatus s) {
    // Jumlah klien dari daftar ASLI (panggilan terpisah tanpa
    // multi_data, diisi refreshStatus) — hitungan dari status
    // gabungan selalu kosong untuk field array (probe v1.1).
    final wifiCount = state.wifiStations.length;
    final lanCount = state.lanStations.length;
    final clientsTotal = wifiCount + lanCount;
    // Baterai: persen asli (battery_vol_percent) hanya bila terisi
    // (lihat Probe Persen Baterai di Diagnostik); selain itu label
    // LEVEL dari battery_pers (skala 0–3, 3 = Penuh) — battery_pers
    // terbukti BUKAN persen, dan fallback 100% ala WebUI TIDAK
    // ditiru.
    final batteryValue = s.batteryPercent != null
        ? '${s.batteryPercent}%'
        : (s.batteryLevelLabel ?? '—');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
          child: _statCard(
            label: 'Baterai',
            value: batteryValue,
            sub: s.batteryCharging == true ? 'Mengisi' : null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const WifiPowerPage(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            label: 'Sinyal',
            value: s.signalDbm == null ? '—' : '${s.signalDbm} dBm',
            sub: s.signalBar == null ? null : 'Bar ${s.signalBar}/5',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SystemPage(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statCard(
            label: 'Perangkat',
            value: '$clientsTotal klien',
            sub: 'WiFi $wifiCount • kabel $lanCount',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DevicesPage(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Satu kartu statistik: label kecil uppercase sekunder, nilai
  /// besar, sublabel redup opsional. Seluruh kartu bisa diketuk.
  Widget _statCard({
    required String label,
    required String value,
    String? sub,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.card,
      borderRadius: AppRadius.cardBorder,
      child: InkWell(
        borderRadius: AppRadius.cardBorder,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardBorder,
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: _inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              if (sub != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 10.5, color: _inkFaint),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Teks baterai untuk baris detail: persen asli bila ada;
  /// selain itu "Level 3 (Penuh)" dari battery_pers (bukan "3%").
  String _batteryDetailText(DeviceStatus s) {
    final charging = s.batteryCharging == true ? ' · Mengisi' : '';
    final p = s.batteryPercent;
    if (p != null) return '$p%$charging';
    final l = s.batteryLevel;
    final label = s.batteryLevelLabel;
    if (l == null || label == null) return '—';
    // Di luar skala 0–3, label sudah berbentuk "Level N".
    if (l > 3) return '$label$charging';
    return 'Level $l ($label)$charging';
  }

  Widget _detailCard(BuildContext context, AppState state, DeviceStatus s) {
    final wifi = state.wifiInfo;
    final rows = <List<String>>[
      // SSID asli dari grup SSID1 — field `ssid` gabungan selalu
      // kosong (probe v1.1); fallback ke field gabungan bila grup
      // belum terbaca.
      <String>['SSID', _or(wifi?.ssid ?? s.ssid)],
      <String>['Mode keamanan WiFi', _or(wifi?.authMode)],
      <String>[
        'SSID disembunyikan',
        wifi?.ssidHidden == null
            ? '—'
            : (wifi!.ssidHidden! ? 'Ya' : 'Tidak'),
      ],
      <String>['IP LAN', _or(s.lanIp)],
      <String>['Status koneksi', _or(s.connectionLabel)],
      <String>[
        'Sinyal',
        s.signalDbm == null
            ? '—'
            : '${s.signalDbm} dBm (${s.signalDbmSource ?? '?'}) • '
                'bar ${s.signalBar ?? '—'}/5',
      ],
      <String>['Baterai', _batteryDetailText(s)],
      <String>['Waktu koneksi (sesi)', _fmtUptime(s.uptimeSeconds)],
      <String>[
        'Tersambung bulan ini',
        _fmtUptime(s.monthlyConnectedTime),
      ],
      <String>['Total unduh sesi', _fmtBytes(s.rxBytes)],
      <String>['Total unggah sesi', _fmtBytes(s.txBytes)],
      <String>[
        'Pemakaian bulan ini',
        '↓ ${_fmtBytes(s.monthlyReceived)} • ↑ ${_fmtBytes(s.monthlySent)}',
      ],
      <String>[
        'Perangkat nirkabel',
        state.wifiStations.length.toString(),
      ],
      <String>[
        'Perangkat kabel',
        state.lanStations.length.toString(),
      ],
      // Baris "Batas akses maksimum" DIHAPUS di v1.3: nilainya
      // MAX_Station_num = kapabilitas perangkat (32), menyesatkan —
      // setting WebUI sebenarnya 3 dan field sumbernya belum
      // ketemu (lihat addendum API-CONTRACT 14:20).
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: rows
              .map(
                (r) => ListTile(
                  dense: true,
                  title: Text(r[0]),
                  trailing: Text(
                    r[1],
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  /// Daftar perangkat terhubung (dari panggilan station_list /
  /// lan_station_list terpisah): nama host, IP, MAC, dan tipe.
  Widget _devicesCard(BuildContext context, AppState state) {
    final all = <({ConnectedDevice d, bool isWifi})>[
      for (final d in state.wifiStations) (d: d, isWifi: true),
      for (final d in state.lanStations) (d: d, isWifi: false),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'Perangkat Terhubung',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
            if (all.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'Tidak ada perangkat terbaca saat ini.',
                  style: TextStyle(color: _inkSoft),
                ),
              )
            else
              for (final e in all)
                ListTile(
                  dense: true,
                  leading: Icon(
                    e.isWifi ? Icons.wifi : Icons.cable,
                    color: _tileIcon,
                  ),
                  title: Text(e.d.displayName),
                  subtitle: Text(
                    <String>[
                      if (e.d.ipAddr.isNotEmpty) e.d.ipAddr,
                      if (e.d.macAddr.isNotEmpty) e.d.macAddr,
                      e.isWifi ? 'WiFi' : 'Kabel',
                      if (e.d.connectTime != null)
                        'tersambung ${e.d.connectTime}',
                    ].join(' • '),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _signalBars(int? bars, {Color color = _primary}) {
    final b = bars ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (i) {
        final active = i < b;
        return Container(
          width: 6,
          height: 6.0 + i * 3,
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: active ? color : AppColors.gaugeTrack,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

/// Marka logo untuk layar masuk: glyph WiFi gradasi cyan →
/// ungu (palet Ookla v3.0) di atas kotak navy membulat bertepi.
/// Digambar dengan CustomPaint TANPA aset biner, karena
/// push-files menolak file biner dan ikon PNG hanya ditanam ke
/// AppIcon oleh workflow. (Ikon aplikasi di home screen TIDAK
/// ikut berubah — ini hanya marka di dalam aplikasi.)
class WifiLogoMark extends StatelessWidget {
  const WifiLogoMark({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_headerTop, AppColors.panel],
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: CustomPaint(painter: _WifiGlyphPainter()),
    );
  }
}

/// Painter glyph WiFi: tiga busur konsentris menghadap ke atas
/// + titik di pusat busur, gradasi cyan #00E5FF → biru #2979FF →
/// ungu #B04DFF, ujung busur bulat (round cap).
class _WifiGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Pusat busur = posisi titik WiFi (agak di bawah tengah,
    // karena busur menjulang ke atas dari titik ini).
    final center = Offset(size.width / 2, size.height * 0.68);
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        AppColors.accent,
        AppColors.gradientMid,
        AppColors.gradientEnd,
      ],
    ).createShader(Offset.zero & size);
    final arcPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.085
      ..strokeCap = StrokeCap.round;
    // Busur 225° → 315° (lewat 270° = lurus ke atas).
    for (final r in <double>[0.16, 0.27, 0.38]) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: size.width * r),
        math.pi * 1.25,
        math.pi / 2,
        false,
        arcPaint,
      );
    }
    final dotPaint = Paint()..shader = shader;
    canvas.drawCircle(center, size.width * 0.055, dotPaint);
  }

  @override
  bool shouldRepaint(_WifiGlyphPainter oldDelegate) => false;
}

/// Gauge setengah lingkaran ala Ookla: busur latar #1B2650 +
/// busur nilai gradasi horizontal cyan → biru → ungu, ujung
/// bulat. Busur membentang 180° (kiri → atas → kanan) dengan
/// pusat di tengah-bawah kanvas.
class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.fraction});

  /// 0.0–1.0, proporsi total sesi terhadap skala lunak gauge.
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final center = Offset(size.width / 2, size.height - stroke / 2 - 2);
    final radius = math.min(size.width / 2, size.height) - stroke / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bg = Paint()
      ..color = AppColors.gaugeTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, bg);

    if (fraction > 0) {
      final fg = Paint()
        ..shader = const LinearGradient(
          colors: <Color>[
            AppColors.accent,
            AppColors.gradientMid,
            AppColors.gradientEnd,
          ],
        ).createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, math.pi, math.pi * fraction, false, fg);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
