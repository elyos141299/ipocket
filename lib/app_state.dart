import 'package:flutter/foundation.dart';

import 'discovery.dart';
import 'models.dart';
import 'reqproc_client.dart';

/// State aplikasi bersama (singleton sederhana, tanpa package tambahan).
///
/// Gateway dan password admin HANYA disimpan di memori selama aplikasi
/// berjalan — tidak pernah ditulis ke penyimpanan permanen.
class AppState extends ChangeNotifier {
  AppState._() {
    client = ReqprocClient(gateway: gateway, log: log);
  }

  static final AppState instance = AppState._();

  /// Gateway MiFi — default sesuai kontrak, bisa diganti di Pengaturan.
  String gateway = '192.168.0.1';

  /// Password admin — default "admin", hanya di memori.
  String adminPassword = 'admin';

  final DiagnosticsLog log = DiagnosticsLog();
  late ReqprocClient client;

  /// True setelah login reqproc berhasil (result "0"/"4").
  bool loggedIn = false;

  /// Pesan khusus hasil login terakhir (Bahasa Indonesia) untuk
  /// ditampilkan di kartu sambutan; null bila tidak ada.
  String? loginMessage;

  bool busy = false;
  String? lastError;
  DeviceStatus? status;
  List<SmsMessage>? smsList;
  SmsCapacity? smsCapacity;

  void setGateway(String value) {
    final g = value.trim();
    gateway = g.isEmpty ? '192.168.0.1' : g;
    client = ReqprocClient(gateway: gateway, log: log);
    loggedIn = false;
    loginMessage = null;
    status = null;
    smsList = null;
    smsCapacity = null;
    notifyListeners();
  }

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  /// Login reqproc dengan sandi saat ini. Bila berhasil, langsung
  /// muat status + SMS. Pesan kegagalan disiapkan per kasus agar
  /// pengguna tahu persis masalahnya.
  Future<void> login() async {
    busy = true;
    loginMessage = null;
    lastError = null;
    notifyListeners();
    try {
      final result = await client.login(adminPassword);
      switch (result.outcome) {
        case LoginOutcome.ok:
          loggedIn = true;
          loginMessage = null;
          break;
        case LoginOutcome.wrongPassword:
          loggedIn = false;
          loginMessage = 'Kata sandi salah. Periksa lagi kata sandi '
              'admin MiFi-mu, lalu coba lagi.';
          break;
        case LoginOutcome.multipleUsers:
          loggedIn = false;
          loginMessage = 'Sudah ada pengguna lain yang sedang masuk '
              '(misalnya halaman web MiFi masih terbuka). Tutup sesi '
              'lain itu dulu, lalu coba lagi.';
          break;
        case LoginOutcome.failed:
          loggedIn = false;
          loginMessage = 'Login ditolak perangkat '
              '(result=${result.rawResult ?? 'tidak dikenal'}). '
              'Coba lagi sebentar lagi.';
          break;
      }
      if (loggedIn) {
        await refreshStatus();
        await refreshSms();
      }
    } catch (e) {
      loggedIn = false;
      loginMessage = 'Tidak dapat menjangkau MiFi di $gateway. '
          'Pastikan HP terhubung ke WiFi iPocket, lalu coba lagi.';
      lastError = 'Login error: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Muat ulang status gabungan (dipakai dashboard + auto-refresh).
  Future<void> refreshStatus() async {
    try {
      final rawMap = await client.getStatus();
      status = DeviceStatus(rawMap);
    } catch (e) {
      lastError = 'Gagal memuat status: $e';
    }
    notifyListeners();
  }

  /// Muat ulang daftar SMS + kapasitasnya.
  Future<void> refreshSms() async {
    final wasBusy = busy;
    if (!wasBusy) {
      busy = true;
      notifyListeners();
    }
    try {
      smsList = await client.getSmsList();
    } catch (e) {
      lastError = 'Gagal memuat SMS: $e';
    }
    try {
      smsCapacity = await client.getSmsCapacity();
    } catch (_) {
      // Kapasitas hanya pelengkap — kegagalannya sudah tercatat di log
      // dan tidak boleh menggagalkan daftar SMS.
    }
    if (!wasBusy) busy = false;
    notifyListeners();
  }

  /// Jalankan urutan tes reqproc dari klien (login → status → SMS →
  /// kapasitas), lalu segarkan data aplikasi bila login berhasil.
  Future<void> runFullTest() async {
    busy = true;
    notifyListeners();
    try {
      final ok = await client.runFullTest(adminPassword);
      if (ok) {
        loggedIn = true;
        loginMessage = null;
        await refreshStatus();
        await refreshSms();
      }
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Jalankan mode penemuan API: baca kode WebUI dari perangkat dan
  /// cari endpoint aslinya (pengganti goform yang terbukti 404).
  /// Semua hasil tercatat di log diagnostik yang sama.
  Future<void> runDiscovery() async {
    busy = true;
    notifyListeners();
    try {
      await ApiDiscovery(gateway: gateway, log: log).run();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Jalankan penemuan API lanjutan (v0.3): petakan tag <script>
  /// RequireJS di index.html, coba kamus path modul yang umum, lalu
  /// crawl nama modul dari require/define + paths: require.config
  /// untuk menemukan file JS aplikasi WebUI yang dimuat dinamis.
  /// Semua hasil tercatat di log diagnostik yang sama.
  Future<void> runDiscoveryAdvanced() async {
    busy = true;
    notifyListeners();
    try {
      await ApiDiscoveryAdvanced(gateway: gateway, log: log).runAdvanced();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Jalankan penemuan API final (v0.4): ambil enam file layanan
  /// WebUI yang terpetakan dari require.config di js/main.js
  /// (js/com.js, js/set.js, js/lib.js, js/sim_device.js, js/net.js,
  /// js/wifi.js), pindai kandidat endpoint + konteks kata kunci
  /// pemanggilan API-nya; isi set.js dicatat utuh bila kecil.
  /// Semua hasil tercatat di log diagnostik yang sama.
  Future<void> runDiscoveryFinal() async {
    busy = true;
    notifyListeners();
    try {
      await ApiDiscoveryFinal(gateway: gateway, log: log).runFinal();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
