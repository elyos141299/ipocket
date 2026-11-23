import 'package:flutter/foundation.dart';

import 'discovery.dart';
import 'models.dart';
import 'reqproc_client.dart';
import 'settings_api.dart';

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

  /// Lapisan API pengaturan Gelombang B/C/D di atas klien aktif
  /// (dibuat segar tiap akses agar selalu mengikuti [client]
  /// terbaru setelah ganti gateway).
  SettingsApi get api => SettingsApi(client);

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

  /// Perangkat terhubung dari panggilan TERPISAH tanpa multi_data
  /// (probe v1.1: array rusak di panggilan gabungan). Diisi
  /// refreshStatus; kosong = belum terbaca / tidak ada klien.
  List<ConnectedDevice> wifiStations = <ConnectedDevice>[];
  List<ConnectedDevice> lanStations = <ConnectedDevice>[];

  /// Info SSID asli dari grup SSID1 (field `ssid` gabungan mati).
  WifiSsidInfo? wifiInfo;

  /// Sampel counter sesi sebelumnya — dasar hitung kecepatan ↑/↓
  /// (realtime_tx_rate/realtime_rx_rate kosong di perangkat ini,
  /// jadi kecepatan dihitung dari selisih byte antar-sampel).
  int? _prevTxBytes;
  int? _prevRxBytes;
  DateTime? _prevSampleAt;

  void setGateway(String value) {
    final g = value.trim();
    gateway = g.isEmpty ? '192.168.0.1' : g;
    client = ReqprocClient(gateway: gateway, log: log);
    loggedIn = false;
    loginMessage = null;
    status = null;
    smsList = null;
    smsCapacity = null;
    wifiStations = <ConnectedDevice>[];
    lanStations = <ConnectedDevice>[];
    wifiInfo = null;
    _prevTxBytes = null;
    _prevRxBytes = null;
    _prevSampleAt = null;
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
  /// Sekalian mengambil daftar perangkat terhubung (2 GET terpisah
  /// tanpa multi_data — aturan emas probe v1.1) dan grup SSID1;
  /// kegagalan dua panggilan ekstra itu tidak menggagalkan status
  /// utama (sudah tercatat di log diagnostik).
  Future<void> refreshStatus() async {
    try {
      final rawMap = await client.getStatus();
      final parsed = DeviceStatus(rawMap);
      _hitungKecepatan(parsed);
      status = parsed;
    } catch (e) {
      lastError = 'Gagal memuat status: $e';
    }
    try {
      final st = await client.getStations();
      wifiStations = st.wifi;
      lanStations = st.lan;
    } catch (_) {
      // Daftar perangkat hanya pelengkap dashboard.
    }
    try {
      wifiInfo = await client.getWifiSsidInfo();
    } catch (_) {
      // Info SSID hanya pelengkap dashboard.
    }
    notifyListeners();
  }

  /// Hitung kecepatan ↑/↓ dari selisih counter byte sesi antar
  /// sampel: rate = (byte sekarang − byte sebelumnya) / selisih
  /// detik, disimpan ke field computed* milik [DeviceStatus].
  /// Sampel pertama, atau counter yang turun (perangkat reboot /
  /// sesi mulai ulang), membiarkan rate null → UI menampilkan "—".
  void _hitungKecepatan(DeviceStatus s) {
    final tx = s.realtimeTxBytes;
    final rx = s.realtimeRxBytes;
    final prevTx = _prevTxBytes;
    final prevRx = _prevRxBytes;
    final prevAt = _prevSampleAt;
    final now = DateTime.now();
    if (tx != null &&
        rx != null &&
        prevTx != null &&
        prevRx != null &&
        prevAt != null) {
      final dt = now.difference(prevAt).inMilliseconds / 1000.0;
      if (dt > 0) {
        final dTx = tx - prevTx;
        final dRx = rx - prevRx;
        if (dTx >= 0) s.computedTxRateBps = (dTx / dt).round();
        if (dRx >= 0) s.computedRxRateBps = (dRx / dt).round();
      }
    }
    if (tx != null && rx != null) {
      _prevTxBytes = tx;
      _prevRxBytes = rx;
      _prevSampleAt = now;
    }
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

  /// Pola bersama aksi tulis SMS: jalankan POST, anggap berhasil
  /// bila result == "success", lalu segarkan daftar SMS. Pesan
  /// hasil (Bahasa Indonesia) dikembalikan untuk snackbar UI;
  /// respons mentah selalu tercatat di log diagnostik oleh klien.
  Future<String> _smsWrite(
    Future<Map<String, dynamic>> Function() action,
    String okText,
  ) async {
    busy = true;
    notifyListeners();
    try {
      final res = await action();
      final ok = res['result']?.toString() == 'success';
      if (ok) {
        await refreshSms();
        return okText;
      }
      return 'Perangkat menjawab result=${res['result'] ?? 'tidak dikenal'} '
          '— periksa log Diagnostik.';
    } catch (e) {
      return 'Gagal menghubungi MiFi: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Kirim SMS (SEND_SMS).
  Future<String> sendSms(String number, String message) => _smsWrite(
        () => client.sendSms(number, message),
        'SMS terkirim ke $number.',
      );

  /// Simpan draf SMS (SAVE_SMS).
  Future<String> saveSmsDraft(String number, String message) => _smsWrite(
        () => client.saveSmsDraft(number, message),
        'Draf SMS tersimpan.',
      );

  /// Hapus satu SMS (DELETE_SMS).
  Future<String> deleteSms(SmsMessage m) => _smsWrite(
        () => client.deleteSms(<String>[m.id]),
        'SMS terhapus.',
      );

  /// Tandai SMS sudah dibaca (SET_MSG_READ) — tanpa snackbar;
  /// daftar disegarkan agar titik "belum dibaca" hilang.
  Future<void> markSmsRead(SmsMessage m) async {
    try {
      await client.setSmsRead(<String>[m.id]);
      await refreshSms();
    } catch (_) {
      // Gagal menandai tidak kritis; sudah tercatat di log.
    }
  }

  /// Hapus SEMUA SMS perangkat (ALL_DELETE_SMS).
  Future<String> deleteAllSms() => _smsWrite(
        () => client.deleteAllSms(),
        'Semua SMS terhapus.',
      );

  /// Simpan pengaturan SMS (SET_MESSAGE_CENTER).
  Future<String> saveSmsSettings({
    required String saveTime,
    required String messageCenter,
    required String statusSave,
  }) =>
      _smsWrite(
        () => client.setMessageCenter(
          saveTime: saveTime,
          messageCenter: messageCenter,
          statusSave: statusSave,
        ),
        'Pengaturan SMS tersimpan.',
      );

  /// Sambung/putus data (CONNECT_NETWORK / DISCONNECT_NETWORK).
  /// Berhasil bila result == "success"; status disegarkan sesudahnya.
  Future<String> toggleConnection(bool connect) async {
    busy = true;
    notifyListeners();
    try {
      final res = connect
          ? await client.connectNetwork()
          : await client.disconnectNetwork();
      final ok = res['result']?.toString() == 'success';
      await refreshStatus();
      if (ok) {
        return connect
            ? 'Perintah sambung terkirim.'
            : 'Perintah putus terkirim.';
      }
      return 'Perangkat menjawab result=${res['result'] ?? 'tidak dikenal'} '
          '— periksa log Diagnostik.';
    } catch (e) {
      return 'Gagal menghubungi MiFi: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Mulai ulang perangkat (REBOOT_DEVICE). Mengembalikan pesan
  /// hasil; sesi kemungkinan putus sesudahnya (perangkat boot
  /// ulang) — pengguna masuk lagi setelah perangkat siap.
  Future<String> rebootDevice() async {
    busy = true;
    notifyListeners();
    try {
      final res = await client.rebootDevice();
      final r = res['result']?.toString();
      log.addNote('REBOOT_DEVICE result mentah: ${r ?? '(kosong)'}');
      return 'Perintah mulai ulang terkirim (result=${r ?? 'kosong'}). '
          'MiFi akan boot ulang — tunggu ±1 menit lalu masuk lagi '
          'bila sesi terputus.';
    } catch (e) {
      return 'Tidak ada respons utuh dari MiFi ($e) — wajar bila '
          'perangkat langsung mulai ulang. Tunggu ±1 menit lalu '
          'masuk lagi.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Matikan perangkat (TURN_OFF_DEVICE {} — FULL-SPEC D18).
  /// Setelah perintah ini perangkat MATI total: aplikasi pasti
  /// kehilangan koneksi sampai user menyalakan MiFi manual.
  Future<String> turnOffDevice() async {
    busy = true;
    notifyListeners();
    try {
      final res = await api.turnOffDevice();
      final r = res['result']?.toString();
      loggedIn = false;
      return 'Perintah matikan terkirim (result=${r ?? 'kosong'}). '
          'MiFi akan mati — nyalakan lagi manual dengan tombol '
          'power bila ingin memakainya.';
    } catch (e) {
      loggedIn = false;
      return 'Tidak ada respons utuh dari MiFi ($e) — wajar bila '
          'perangkat langsung mati. Periksa lampu MiFi-mu.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Setel ulang pabrik (RESTORE_FACTORY_SETTINGS {} — FULL-SPEC
  /// D18). SEMUA pengaturan perangkat kembali ke awal pabrik
  /// (SSID, sandi WiFi, sandi admin) dan perangkat mulai ulang.
  Future<String> restoreFactory() async {
    busy = true;
    notifyListeners();
    try {
      final res = await api.restoreFactory();
      final r = res['result']?.toString();
      loggedIn = false;
      client.clearSession();
      return 'Perintah setel ulang pabrik terkirim '
          '(result=${r ?? 'kosong'}). MiFi kembali ke pengaturan '
          'awal dan mulai ulang — sambungkan ulang ke WiFi '
          'bawaan perangkat, lalu masuk dengan sandi awal.';
    } catch (e) {
      return 'Tidak ada respons utuh dari MiFi ($e) — wajar bila '
          'perangkat langsung mulai ulang untuk reset. Tunggu '
          '±1 menit lalu sambungkan ulang ke WiFi bawaan.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Ganti kata sandi login (CHANGE_PASSWORD). Bila sukses: sesi
  /// ditutup dan pengguna diarahkan ke layar login dengan sandi
  /// baru (sandi baru disimpan di memori sebagai sandi aktif).
  Future<String> changePassword(String oldPw, String newPw) async {
    busy = true;
    notifyListeners();
    try {
      final ok = await client.changePassword(oldPw, newPw);
      if (ok) {
        adminPassword = newPw;
        loggedIn = false;
        client.clearSession();
        loginMessage = 'Kata sandi berhasil diganti. Masuk lagi '
            'dengan kata sandi barumu.';
        return 'Kata sandi diganti. Silakan masuk lagi.';
      }
      return 'Perangkat menolak ganti sandi — periksa kata sandi '
          'lamamu, lalu coba lagi.';
    } catch (e) {
      return 'Gagal menghubungi MiFi: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Jalankan Probe Baterai & Bulanan (v1.2 "Probe Data
  /// Bulanan", diperluas v1.3): baterai (battery_vol_percent,
  /// battery_vol, grup baterai — semua tanpa multi_data) +
  /// data_counter tanpa multi_data + traffic_alert_info,
  /// tercatat mentah di log.
  Future<void> runMonthlyProbe() async {
    busy = true;
    notifyListeners();
    try {
      await client.runMonthlyProbe();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Jalankan Probe Persen Baterai (v3.0): satu panggilan grup
  /// status WebUI utuh (multi_data=1) untuk membuktikan apakah
  /// firmware mengisi battery_vol_percent bila diminta dalam
  /// grup persis WebUI; hasilnya tercatat di log diagnostik.
  Future<void> runBatteryPercentProbe() async {
    busy = true;
    notifyListeners();
    try {
      await client.runBatteryPercentProbe();
    } finally {
      busy = false;
      notifyListeners();
    }
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

  /// Jalankan Probe Field Kosong (v1.1): minta field yang kembali
  /// kosong dari panggilan status gabungan (data_counter,
  /// station_list, lan_station_list, ssid) satu per satu / dalam
  /// grup kecil ala WebUI, dan catat setiap respons mentahnya ke
  /// log diagnostik — untuk menentukan bentuk panggilan yang benar.
  Future<void> runFieldProbe() async {
    busy = true;
    notifyListeners();
    try {
      await client.runFieldProbe();
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

  /// Jalankan penemuan terarah JS (v1.3): unduh PENUH
  /// js/wifi.js, js/net.js, js/sim_device.js dari perangkat dan
  /// catat konteks ±1200 karakter di sekitar SETIAP kemunculan
  /// kata kunci spesifik per file (goformId/setWifiBasic/
  /// MacFilter di wifi.js, DHCP_SETTING/DMZ/REBOOT/SNTP di
  /// net.js, save_time/MessageCenter/status_save di
  /// sim_device.js, dll) — bahan memastikan nama field wire
  /// gelombang pengaturan berikutnya. Semua hasil tercatat di
  /// log diagnostik yang sama.
  Future<void> runTargetedDiscovery() async {
    busy = true;
    notifyListeners();
    try {
      await ApiDiscoveryTargeted(gateway: gateway, log: log).runTargeted();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
