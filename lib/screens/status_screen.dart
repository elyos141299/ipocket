import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

// Palet dashboard: branding Advan — pink magenta #EC008D,
// aksen pink terang, tinta nyaris hitam hangat.
const Color _primary = Color(0xFFEC008D);
const Color _accent = Color(0xFFF95FB4);
const Color _ink = Color(0xFF16121A);
const Color _headerDark = Color(0xFF16121A);
const Color _headerDeep = Color(0xFF2A1530);
const Color _tileBg = Color(0xFFFCE4F1);
const Color _tileIcon = Color(0xFFC2187A);

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

/// Dashboard utama: kartu sambutan + login sebelum masuk; setelah
/// masuk tampil header perangkat, lingkaran pemakaian data bulanan,
/// kecepatan live, 4 tile ringkasan, dan detail label-nilai.
/// Auto-refresh 15 detik selama tab ini tampil dan sudah login.
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
      _autoTimer = Timer.periodic(const Duration(seconds: 15), (_) {
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
              'Diperbarui otomatis tiap 15 detik.',
              style: TextStyle(color: Colors.black54),
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
        _connectionButton(context, state, s),
        const SizedBox(height: 12),
        _usageCard(context, s),
        const SizedBox(height: 12),
        _tilesGrid(context, state, s),
        const SizedBox(height: 12),
        _detailCard(context, state, s),
        const SizedBox(height: 12),
        _devicesCard(context, state),
      ]);
    }
    return widgets;
  }

  Widget _headerCard(BuildContext context, DeviceStatus? s) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_headerDark, _headerDeep],
        ),
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
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_or(s?.networkProvider)} • ${_or(s?.networkType)}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 2),
                Text(
                  _or(s?.connectionLabel),
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              _signalBars(s?.signalBar, color: Colors.white),
              const SizedBox(height: 4),
              Text(
                s?.signalDbm == null ? '—' : '${s!.signalDbm} dBm',
                style: const TextStyle(
                  color: Colors.white,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Icon(
              connected ? Icons.link : Icons.link_off,
              color: connected ? _tileIcon : Colors.black45,
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
              )
            else
              FilledButton.icon(
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
              ),
          ],
        ),
      ),
    );
  }

  Widget _usageCard(BuildContext context, DeviceStatus s) {
    final hasMonthly = s.monthlySent != null || s.monthlyReceived != null;
    final totalMonthly = (s.monthlySent ?? 0) + (s.monthlyReceived ?? 0);
    final hasSession = s.txBytes != null || s.rxBytes != null;
    final totalSession = (s.txBytes ?? 0) + (s.rxBytes ?? 0);
    // Perangkat user tidak mengatur batas data: ring digambar
    // proporsional terhadap patokan tampilan 10 GB (lihat README).
    // Bila data bulanan (data_counter) kosong — seperti terbukti di
    // perangkat user — lingkaran menampilkan total SESI berjalan
    // (realtime_tx_bytes + realtime_rx_bytes) dengan label jujur.
    const quotaBytes = 10 * 1024 * 1024 * 1024;
    final int? displayTotal =
        hasMonthly ? totalMonthly : (hasSession ? totalSession : null);
    final fraction = displayTotal == null
        ? 0.0
        : (displayTotal / quotaBytes).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            CustomPaint(
              painter: _RingPainter(fraction: fraction),
              child: SizedBox(
                width: 210,
                height: 210,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      displayTotal == null ? '—' : _fmtBytes(displayTotal),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasMonthly ? 'Pemakaian Bulan Ini' : 'Total Sesi Ini',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasMonthly
                          ? 'Ring: patokan 10 GB'
                          : 'data bulanan belum terbaca dari perangkat',
                      style:
                          const TextStyle(color: Colors.black38, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                _speedItem(
                  Icons.arrow_downward,
                  _fmtRate(s.rxRate),
                  'Unduh sekarang',
                ),
                _speedItem(
                  Icons.arrow_upward,
                  _fmtRate(s.txRate),
                  'Unggah sekarang',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedItem(IconData icon, String value, String label) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 18, color: _primary),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ],
        ),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }

  Widget _tilesGrid(BuildContext context, AppState state, DeviceStatus s) {
    // Jumlah klien dari daftar ASLI (panggilan terpisah tanpa
    // multi_data, diisi refreshStatus) — hitungan dari status
    // gabungan selalu kosong untuk field array (probe v1.1).
    final wifiCount = state.wifiStations.length;
    final lanCount = state.lanStations.length;
    final clientsTotal = wifiCount + lanCount;
    final capTotal = state.smsCapacity?.total;
    // Baterai: persen asli (battery_vol_percent) hanya bila terisi;
    // selain itu tampilkan teks LEVEL dari battery_pers (skala 0–3,
    // 3 = Penuh) — battery_pers terbukti BUKAN persen.
    final batteryValue = s.batteryPercent != null
        ? '${s.batteryPercent}%'
        : (s.batteryLevelLabel ?? '—');
    final batteryLabel =
        s.batteryCharging == true ? 'Battery · Mengisi' : 'Battery';
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: <Widget>[
        _tile(
          icon: _batteryIcon(s),
          value: batteryValue,
          label: batteryLabel,
        ),
        _tile(
          icon: Icons.sms,
          value: s.smsUnread?.toString() ?? '—',
          label: capTotal == null
              ? 'SMS belum dibaca'
              : 'SMS belum dibaca • kapasitas $capTotal',
        ),
        _tile(
          icon: Icons.devices,
          value: clientsTotal.toString(),
          label: 'Clients online '
              '(WiFi $wifiCount • kabel $lanCount)',
        ),
        _tile(
          icon: Icons.sd_storage,
          value: 'Tidak tersedia',
          label: 'SD Sharing — fitur nonaktif di perangkat ini',
        ),
      ],
    );
  }

  IconData _batteryIcon(DeviceStatus s) {
    if (s.batteryCharging == true) return Icons.battery_charging_full;
    final p = s.batteryPercent;
    if (p != null) {
      if (p >= 90) return Icons.battery_full;
      if (p >= 70) return Icons.battery_5_bar;
      if (p >= 50) return Icons.battery_4_bar;
      if (p >= 30) return Icons.battery_3_bar;
      if (p >= 15) return Icons.battery_2_bar;
      if (p > 0) return Icons.battery_1_bar;
      return Icons.battery_0_bar;
    }
    // Tanpa persen asli: ikon mengikuti level 0–3 (battery_pers).
    final l = s.batteryLevel;
    if (l == null) return Icons.battery_unknown;
    if (l >= 3) return Icons.battery_full;
    if (l == 2) return Icons.battery_5_bar;
    if (l == 1) return Icons.battery_2_bar;
    return Icons.battery_0_bar;
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

  Widget _tile({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _tileBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _tileIcon, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
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
                  style: TextStyle(color: Colors.black54),
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
            color: active ? color : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}

/// Marka logo untuk layar masuk: glyph WiFi gradasi pink Advan
/// di atas kotak gelap membulat — meniru Logo B (ikon aplikasi).
/// Digambar dengan CustomPaint TANPA aset biner, karena
/// push-files menolak file biner dan ikon PNG hanya ditanam ke
/// AppIcon oleh workflow. Logo lama huruf "i" ditinggalkan
/// di v1.3.
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
          colors: <Color>[_headerDeep, _headerDark],
        ),
      ),
      child: CustomPaint(painter: _WifiGlyphPainter()),
    );
  }
}

/// Painter glyph WiFi: tiga busur konsentris menghadap ke atas
/// + titik di pusat busur, gradasi pink #F95FB4 → #EC008D,
/// ujung busur bulat (round cap).
class _WifiGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Pusat busur = posisi titik WiFi (agak di bawah tengah,
    // karena busur menjulang ke atas dari titik ini).
    final center = Offset(size.width / 2, size.height * 0.68);
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[_accent, _primary],
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

/// Ring pemakaian data: lingkaran latar tipis + busur proporsional.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction});

  /// 0.0–1.0, proporsi pemakaian terhadap patokan ring.
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final bg = Paint()
      ..color = const Color(0xFFEAE4E8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, bg);

    if (fraction > 0) {
      final fg = Paint()
        ..color = _primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * fraction, false, fg);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
