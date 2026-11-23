import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

// Palet dashboard (UI-REFERENCE.md): biru muda bersih.
const Color _primary = Color(0xFF0288D1);
const Color _accent = Color(0xFF38BDF8);
const Color _ink = Color(0xFF0B2B40);

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
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[_accent, _primary],
                  ),
                ),
                child: const Center(
                  child: Text(
                    'i',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
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
        _usageCard(context, s),
        const SizedBox(height: 12),
        _tilesGrid(context, state, s),
        const SizedBox(height: 12),
        _detailCard(context, s),
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
          colors: <Color>[_accent, _primary],
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

  Widget _usageCard(BuildContext context, DeviceStatus s) {
    final totalMonthly = (s.monthlySent ?? 0) + (s.monthlyReceived ?? 0);
    final hasMonthly = s.monthlySent != null || s.monthlyReceived != null;
    // Perangkat user tidak mengatur batas data: ring digambar
    // proporsional terhadap patokan tampilan 10 GB (lihat README).
    const quotaBytes = 10 * 1024 * 1024 * 1024;
    final fraction =
        hasMonthly ? (totalMonthly / quotaBytes).clamp(0.0, 1.0) : 0.0;
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
                      hasMonthly ? _fmtBytes(totalMonthly) : '—',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Pemakaian Bulan Ini',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Ring: patokan 10 GB',
                      style: TextStyle(color: Colors.black38, fontSize: 11),
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
    final wifiCount = s.stationCount;
    final lanCount = s.lanStationCount;
    final clientsTotal = (wifiCount == null && lanCount == null)
        ? null
        : (wifiCount ?? 0) + (lanCount ?? 0);
    final capTotal = state.smsCapacity?.total;
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
          value: s.batteryPercent == null ? '—' : '${s.batteryPercent}%',
          label: s.batteryCharging == null
              ? 'Battery'
              : (s.batteryCharging!
                  ? 'Battery • mengisi daya'
                  : 'Battery'),
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
          value: clientsTotal?.toString() ?? '—',
          label: 'Clients online '
              '(WiFi ${wifiCount ?? '—'} • kabel ${lanCount ?? '—'})',
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
    if (p == null) return Icons.battery_unknown;
    if (p >= 90) return Icons.battery_full;
    if (p >= 70) return Icons.battery_5_bar;
    if (p >= 50) return Icons.battery_4_bar;
    if (p >= 30) return Icons.battery_3_bar;
    if (p >= 15) return Icons.battery_2_bar;
    if (p > 0) return Icons.battery_1_bar;
    return Icons.battery_0_bar;
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
            Icon(icon, color: _primary, size: 26),
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

  Widget _detailCard(BuildContext context, DeviceStatus s) {
    final rows = <List<String>>[
      <String>['SSID', _or(s.ssid)],
      <String>['IP LAN', _or(s.lanIp)],
      <String>['Status koneksi', _or(s.connectionLabel)],
      <String>[
        'Sinyal',
        s.signalDbm == null
            ? '—'
            : '${s.signalDbm} dBm (${s.signalDbmSource ?? '?'}) • '
                'bar ${s.signalBar ?? '—'}/5',
      ],
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
        s.stationCount?.toString() ?? '—',
      ],
      <String>[
        'Perangkat kabel',
        s.lanStationCount?.toString() ?? '—',
      ],
      <String>['Batas akses maksimum', _or(s.maxAccessNum)],
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
      ..color = const Color(0xFFD9EEF9)
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
