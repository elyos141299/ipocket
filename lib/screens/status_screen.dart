import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'settings/devices_page.dart';
import 'settings/system_page.dart';
import 'settings/wifi_power_page.dart';

// Palet Beranda dari token terpusat theme.dart v3.0 — navy
// Ookla + cyan. Nama lokal dipertahankan agar isi layar ringkas.
const Color _primary = AppColors.primary;
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

/// Beranda (dulu "Status"): halaman masuk profesional v3.1
/// (Logo A + kartu form) sebelum masuk; setelah masuk tampil
/// header perangkat, indikator LIVE, GAUGE setengah lingkaran
/// ala Ookla (total BULANAN asli + kecepatan live), 3 kartu
/// statistik yang bisa diketuk (Baterai/Sinyal/Perangkat),
/// tombol Sambung/Putus, kartu perangkat terhubung, dan detail
/// SSID. Struktur mengikuti tpMiFi; data & logika identik v2.0.
/// Auto-refresh 2 detik selama tab ini tampil dan sudah login
/// (v3.1: dipercepat dari 5 detik atas permintaan user, dengan
/// indikator LIVE menggantikan teks penjelasan interval).
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
      _autoTimer = Timer.periodic(const Duration(seconds: 2), (_) {
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
        if (!state.loggedIn) return _loginView(context, state);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: _dashboard(context, state),
        );
      },
    );
  }

  // ---------- Keadaan belum login ----------

  /// Halaman masuk v3.1 — mengikuti mockup yang disetujui user
  /// (v31-assets/login-mockup.png): latar gradasi navy, Logo A
  /// besar di tengah atas, nama + tagline, kartu form bertepi
  /// (label kecil + field sandi + tombol Masuk gradasi
  /// cyan→biru), pesan error sebagai BANNER rapi di atas kartu,
  /// petunjuk gateway kecil di bawah kartu, label versi redup
  /// di paling bawah. Perilaku login TIDAK berubah dari v3.0
  /// (controller, onChanged, onSubmitted, state.login sama).
  Widget _loginView(BuildContext context, AppState state) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_headerTop, _headerBottom],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Center(child: AppLogoMark(size: 148)),
            const SizedBox(height: 26),
            const Text(
              'iPocket',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Panel pantau MiFi Advan iPocket MF01',
              textAlign: TextAlign.center,
              style: TextStyle(color: _inkSoft, fontSize: 14.5),
            ),
            const SizedBox(height: 34),
            if (state.loginMessage != null) ...<Widget>[
              _loginErrorBanner(state.loginMessage!),
              const SizedBox(height: 14),
            ],
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: AppRadius.cardBorder,
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'KATA SANDI ADMIN',
                    style: TextStyle(
                      color: _inkSoft,
                      fontSize: 11.5,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pwController,
                    obscureText: !_showPassword,
                    onChanged: (v) => state.adminPassword = v,
                    onSubmitted: (_) {
                      if (!state.busy) state.login();
                    },
                    decoration: InputDecoration(
                      hintText: 'Kata sandi admin MiFi',
                      helperText:
                          'Hanya disimpan selama aplikasi berjalan.',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                            () => _showPassword = !_showPassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _loginButton(state),
                  if (state.busy) ...<Widget>[
                    const SizedBox(height: 14),
                    const LinearProgressIndicator(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Gateway ${state.gateway} — pastikan HP terhubung '
              'ke WiFi iPocket',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _inkFaint, fontSize: 12.5),
            ),
            const SizedBox(height: 44),
            const Text(
              'v3.2',
              textAlign: TextAlign.center,
              style: TextStyle(color: _inkFaint, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner error login: panel merah lembut bertepi + ikon +
  /// teks — tampil di ATAS kartu form (bukan teks polos di
  /// tengah form seperti v3.0).
  Widget _loginErrorBanner(String message) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: AppRadius.tileBorder,
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.error_outline,
            color: AppColors.danger,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tombol Masuk gradasi cyan → biru (Container gradasi +
  /// InkWell) mengikuti mockup — bukan FilledButton polos.
  /// v3.1.1: ripple InkWell sudah ada; ditambah PressScale agar
  /// tombol terasa menyusut tipis saat ditekan.
  Widget _loginButton(AppState state) {
    final busy = state.busy;
    return PressScale(
      child: Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.accent, AppColors.gradientMid],
        ),
        borderRadius: AppRadius.tileBorder,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: AppRadius.tileBorder,
          onTap: busy ? null : () => state.login(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.login,
                  color: Colors.white.withValues(alpha: busy ? 0.5 : 1),
                  size: 20,
                ),
                const SizedBox(width: 9),
                Text(
                  'Masuk',
                  style: TextStyle(
                    color:
                        Colors.white.withValues(alpha: busy ? 0.5 : 1),
                    fontSize: 16.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
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
      // v3.1: baris teks "Diperbarui otomatis tiap 5 detik" +
      // tombol Segarkan DIHAPUS atas permintaan user — diganti
      // indikator LIVE ringkas (titik hijau berdenyut + "LIVE").
      // v3.2: indikator yang sama berubah jadi OFFLINE (titik
      // merah redup, tanpa denyut) saat poll terakhir gagal.
      Row(
        children: <Widget>[
          _LiveIndicator(offline: state.statusOffline),
        ],
      ),
      const SizedBox(height: 12),
    ];
    if (state.busy) {
      widgets.add(const LinearProgressIndicator());
      widgets.add(const SizedBox(height: 12));
    }
    // v3.2: blok teks error mentah raksasa DIHAPUS total —
    // diganti banner ringkas berikon berisi pesan ramah +
    // tombol Coba Lagi. Data terakhir (kartu & gauge di bawah)
    // tetap tampil apa adanya.
    if (state.statusError != null) {
      widgets.add(_offlineBanner(context, state));
      widgets.add(const SizedBox(height: 12));
    }
    if (s == null) {
      widgets.add(Text(
        state.statusError != null
            ? 'Status belum bisa dimuat — periksa koneksi ke '
                'WiFi iPocket, lalu coba lagi.'
            : 'Memuat status perangkat…',
      ));
    } else {
      widgets.addAll(<Widget>[
        // v3.2: saklar Data Internet MENONJOL tepat di bawah
        // kartu perangkat, di atas gauge (permintaan user —
        // tombol Sambung/Putus lama dinilai kurang terlihat).
        _dataSwitchCard(context, state, s),
        const SizedBox(height: 12),
        _gaugeCard(context, s),
        const SizedBox(height: 12),
        _statsRow(context, state, s),
        const SizedBox(height: 12),
        _devicesCard(context, state),
        const SizedBox(height: 12),
        _detailCard(context, state, s),
      ]);
    }
    return widgets;
  }

  /// Banner offline Beranda v3.2: panel merah lembut bertepi +
  /// ikon putus + pesan ramah (dari friendlyError lewat
  /// state.statusError) + tombol "Coba Lagi" yang memicu poll
  /// status ulang. Menggantikan dump teks exception mentah.
  Widget _offlineBanner(BuildContext context, AppState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.12),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.45),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.wifi_off,
            color: AppColors.danger,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.statusError!,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: state.busy ? null : () => state.refreshStatus(),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
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

  /// Kartu saklar Data Internet v3.2 (permintaan user: tombol
  /// matikan/hidupkan data SIM kurang terlihat di versi lama).
  /// Baris kartu MENONJOL di atas Beranda: ikon data di kotak
  /// aksen + label "Data Internet" besar + keterangan keadaan +
  /// Switch besar di kanan. Wire PERSIS perintah Sambung/Putus
  /// yang terbukti sejak v1.4 (AppState.toggleConnection →
  /// CONNECT_NETWORK / DISCONNECT_NETWORK) — tidak diubah.
  /// Keadaan saklar mengikuti ppp_status dari polling; saat
  /// offline (poll terakhir gagal) atau sibuk, saklar nonaktif.
  Widget _dataSwitchCard(
    BuildContext context,
    AppState state,
    DeviceStatus s,
  ) {
    final connected = _isConnected(s);
    final offline = state.statusOffline;
    final enabled = !offline && !state.busy;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          IconBox(
            connected ? Icons.signal_cellular_alt : Icons.signal_cellular_off,
            color: connected ? _tileIcon : _inkFaint,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Data Internet',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  offline
                      ? 'Tidak terhubung ke MiFi'
                      : connected
                          ? 'Tersambung'
                          : 'Terputus',
                  style: const TextStyle(color: _inkSoft, fontSize: 13),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 1.2,
            child: Switch(
              value: connected,
              activeTrackColor: _primary,
              onChanged: enabled
                  ? (v) async {
                      final msg = await state.toggleConnection(v);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Gauge Beranda ala Ookla: busur setengah lingkaran gradasi
  /// cyan → biru → ungu.
  ///
  /// v3.1 — BULANAN ASLI: tengah gauge kini total BULAN INI dari
  /// field datar monthly_rx_bytes + monthly_tx_bytes grup status
  /// WebUI (TERBUKTI terisi di perangkat user lewat probe v3.0:
  /// ±1,07 GB + ±159 MB — menggantikan total sesi v3.0 yang
  /// datanya kecil dan data_counter yang terbukti kosong).
  /// Sub-baris: kecepatan live ↓/↑ + total sesi berjalan.
  ///
  /// Fraksi busur: bila batas data Manajemen Data aktif
  /// (dataLimitBytes terhitung mengikuti rumus WebUI), fraksi =
  /// total bulanan ÷ batas. Selain itu fraksi = total bulanan ÷
  /// referensi lunak 10 GB — murni patokan tampilan agar busur
  /// terbaca, BUKAN batas data perangkat.
  Widget _gaugeCard(BuildContext context, DeviceStatus s) {
    final totalMonthly = s.monthlyTotalBytes;
    final hasSession = s.txBytes != null || s.rxBytes != null;
    final totalSession = (s.txBytes ?? 0) + (s.rxBytes ?? 0);
    final limit = s.dataLimitBytes;
    const softScaleBytes = 10 * 1024 * 1024 * 1024; // 10 GB
    final denom = (limit != null && limit > 0) ? limit : softScaleBytes;
    final fraction = totalMonthly == null
        ? 0.0
        : (totalMonthly / denom).clamp(0.0, 1.0).toDouble();
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
                  // v3.1.1: busur nilai MENYAPU halus ke nilai
                  // baru setiap polling (TweenAnimationBuilder
                  // 650 ms) — bukan lompat kasar antar-angka.
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: fraction),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeOutCubic,
                    builder: (context, animatedFraction, _) {
                      return CustomPaint(
                        size: const Size(260, 148),
                        painter:
                            _GaugePainter(fraction: animatedFraction),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: <Widget>[
                        const Text(
                          'TOTAL BULAN INI',
                          style: TextStyle(
                            color: _inkSoft,
                            fontSize: 11,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          totalMonthly == null
                              ? '—'
                              : _fmtBytes(totalMonthly),
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
                        const SizedBox(height: 2),
                        Text(
                          hasSession
                              ? 'Sesi ini ${_fmtBytes(totalSession)}'
                              : 'Sesi ini —',
                          style: const TextStyle(
                            color: _inkFaint,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 4),
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
    // LEVEL JUJUR dari battery_pers (skala 0–3: Tinggi / Sedang /
    // Rendah / Sangat Rendah — pilihan user v3.1, tanpa klaim
    // "Penuh") — battery_pers terbukti BUKAN persen, dan fallback
    // 100% ala WebUI TIDAK ditiru. Ikon segmen mengikuti level;
    // petir tampil bila sedang mengisi.
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
            valueIcon: _batterySegments(
              s.batteryLevel,
              charging: s.batteryCharging == true,
            ),
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

  /// Ikon baterai 3 segmen untuk kartu Baterai: segmen terisi
  /// mengikuti level battery_pers (0–3), warna segmen cyan —
  /// merah lembut khusus level 0. Ikon petir kecil menempel bila
  /// perangkat sedang mengisi (battery_charging == "1").
  Widget _batterySegments(int? level, {required bool charging}) {
    final filled = (level ?? 0).clamp(0, 3);
    final segColor = level == 0
        ? AppColors.danger
        : (level == null ? AppColors.gaugeTrack : AppColors.primary);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 27,
          height: 14,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(color: _inkSoft, width: 1.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: List<Widget>.generate(3, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 1.5 : 0),
                  decoration: BoxDecoration(
                    color: i < filled ? segColor : AppColors.gaugeTrack,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              );
            }),
          ),
        ),
        Container(
          width: 2.5,
          height: 6,
          decoration: const BoxDecoration(
            color: _inkSoft,
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(2),
            ),
          ),
        ),
        if (charging) ...<Widget>[
          const SizedBox(width: 3),
          const Icon(Icons.bolt, size: 15, color: AppColors.warning),
        ],
      ],
    );
  }

  /// Satu kartu statistik: label kecil uppercase sekunder, nilai
  /// besar, sublabel redup opsional. Seluruh kartu bisa diketuk.
  Widget _statCard({
    required String label,
    required String value,
    String? sub,
    Widget? valueIcon,
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
              if (valueIcon != null) ...<Widget>[
                valueIcon,
                const SizedBox(height: 4),
              ],
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
  /// selain itu "Level 3 (Tinggi)" dari battery_pers (bukan "3%";
  /// label level jujur v3.1 — tanpa "Penuh").
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
        // v3.1: field datar monthly_*_bytes (terbukti terisi);
        // data_counter hanya fallback bila field datar kosong.
        'Pemakaian bulan ini',
        '↓ ${_fmtBytes(s.monthlyRxBytes ?? s.monthlyReceived)} • '
            '↑ ${_fmtBytes(s.monthlyTxBytes ?? s.monthlySent)}',
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

/// Indikator LIVE Beranda v3.1: titik hijau berdenyut (animasi
/// fade sederhana, berulang) + teks "LIVE" kecil — menggantikan
/// baris teks "Diperbarui otomatis…" dan tombol Segarkan.
/// Indikator keadaan polling Beranda. Online: titik hijau
/// berdenyut + "LIVE" (v3.1). v3.2: [offline] true (poll
/// terakhir gagal) → titik merah redup STATIS + "OFFLINE";
/// kembali LIVE otomatis saat poll berhasil lagi.
class _LiveIndicator extends StatefulWidget {
  const _LiveIndicator({this.offline = false});

  final bool offline;

  @override
  State<_LiveIndicator> createState() => _LiveIndicatorState();
}

class _LiveIndicatorState extends State<_LiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    if (!widget.offline) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_LiveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.offline && _ctrl.isAnimating) {
      _ctrl.stop();
    } else if (!widget.offline && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offline) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            'OFFLINE',
            style: TextStyle(
              color: AppColors.danger.withValues(alpha: 0.85),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FadeTransition(
          opacity: Tween<double>(begin: 0.25, end: 1).animate(_ctrl),
          child: Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 7),
        const Text(
          'LIVE',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ],
    );
  }
}

/// Marka Logo A RESMI v3.1 (pilihan user — varian "cincin
/// gauge", file master logo-final.png / ikon aplikasi): cincin
/// gauge ±270° gradasi cyan → biru → ungu mengelilingi glyph
/// WiFi (tiga sektor busur + titik), di atas kotak navy membulat
/// bertepi. Digambar dengan CustomPaint TANPA aset biner, karena
/// push-files menolak file biner; PNG hanya dipakai untuk ikon
/// aplikasi lewat aset base64 yang di-decode workflow.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, this.size = 148});

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
      child: CustomPaint(painter: _LogoAPainter()),
    );
  }
}

/// Painter Logo A: (1) cincin gauge — jalur (track) navy terang
/// di kanan-bawah, busur nilai gradasi sweep cyan → biru → ungu
/// membentang ±252° dari kiri-bawah lewat atas ke kanan, titik
/// ujung di kedua ujung busur gradasi; (2) glyph WiFi di tengah:
/// tiga sektor cincin konsentris menghadap ke atas + titik,
/// gradasi vertikal cyan → biru → ungu.
class _LogoAPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, size.height / 2);
    final ringRadius = w * 0.395;
    final ringRect = Rect.fromCircle(center: center, radius: ringRadius);
    final ringStroke = w * 0.030;

    // Sudut kanvas (y ke bawah): 0 = kanan, bertambah searah
    // jarum jam. Busur gradasi mulai di kiri-bawah (0.75π) dan
    // menyapu 1.40π lewat kiri → atas → kanan, berakhir ±27°.
    const startAngle = math.pi * 0.75;
    const sweepAngle = math.pi * 1.40;

    // Track cincin: sisa busur di kanan-bawah sesudah ujung
    // gradasi, menyisakan celah kecil di bawah.
    final trackPaint = Paint()
      ..color = AppColors.gaugeTrack
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      ringRect,
      startAngle + sweepAngle + 0.06,
      math.pi * 2 - sweepAngle - 0.42,
      false,
      trackPaint,
    );

    // Busur gradasi (sweep gradient mengikuti arah busur).
    final ringPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: <Color>[
          AppColors.accent,
          AppColors.gradientMid,
          AppColors.gradientEnd,
        ],
      ).createShader(ringRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringStroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(ringRect, startAngle, sweepAngle, false, ringPaint);

    // Titik ujung busur gradasi (awal cyan, akhir ungu).
    Offset ringPoint(double a) => Offset(
          center.dx + ringRadius * math.cos(a),
          center.dy + ringRadius * math.sin(a),
        );
    canvas.drawCircle(
      ringPoint(startAngle),
      ringStroke * 0.95,
      Paint()..color = AppColors.accent,
    );
    canvas.drawCircle(
      ringPoint(startAngle + sweepAngle),
      ringStroke * 0.95,
      Paint()..color = AppColors.gradientEnd,
    );

    // Glyph WiFi: sektor cincin (annular sector) + titik.
    final glyphCenter = Offset(w / 2, size.height * 0.615);
    final glyphShader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        AppColors.accent,
        AppColors.gradientMid,
        AppColors.gradientEnd,
      ],
    ).createShader(Offset.zero & size);
    final glyphPaint = Paint()..shader = glyphShader;
    const gStart = math.pi * 1.13;
    const gSweep = math.pi * 0.74;
    for (final band in <(double, double)>[
      (0.335, 0.252),
      (0.222, 0.152),
      (0.122, 0.062),
    ]) {
      final path = Path()
        ..addArc(
          Rect.fromCircle(center: glyphCenter, radius: w * band.$1),
          gStart,
          gSweep,
        )
        ..arcTo(
          Rect.fromCircle(center: glyphCenter, radius: w * band.$2),
          gStart + gSweep,
          -gSweep,
          false,
        )
        ..close();
      canvas.drawPath(path, glyphPaint);
    }
    canvas.drawCircle(glyphCenter, w * 0.047, glyphPaint);
  }

  @override
  bool shouldRepaint(_LogoAPainter oldDelegate) => false;
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
