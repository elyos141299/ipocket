import 'package:flutter/foundation.dart';

import 'friendly_error.dart';
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

  /// Gateway MiFi — v4.0: tetap default kontrak 192.168.0.1
  /// (halaman ganti gateway dihapus bersama tab Tools).
  String gateway = '192.168.0.1';

  /// Password admin — default "admin", hanya di memori.
  String adminPassword = 'admin';

  final DiagnosticsLog log = DiagnosticsLog();
  late ReqprocClient client;

  /// Lapisan API pengaturan Gelombang B/C/D di atas klien aktif
  /// (dibuat segar tiap akses agar selalu mengikuti [client]
  /// terbaru).
  SettingsApi get api => SettingsApi(client);

  /// True setelah login reqproc berhasil (result "0"/"4").
  bool loggedIn = false;

  /// Pesan khusus hasil login terakhir (Bahasa Indonesia) untuk
  /// ditampilkan di kartu sambutan; null bila tidak ada.
  String? loginMessage;

  bool busy = false;
  String? lastError;

  /// v3.2: keadaan poll status terakhir untuk Beranda — true
  /// bila poll terakhir GAGAL (indikator jadi OFFLINE + banner
  /// ringkas tampil; data terakhir tetap ditampilkan).
  bool statusOffline = false;

  /// Pesan ramah kegagalan status terakhir (dari friendlyError)
  /// untuk banner Beranda; null bila poll terakhir berhasil.
  String? statusError;

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
          loginMessage = 'Login ditolak perangkat. '
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
      lastError = friendlyError(e);
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
      statusOffline = false;
      statusError = null;
    } catch (e) {
      // v3.2: pesan ramah saja (tanpa dump exception) + tandai
      // offline; [status] terakhir SENGAJA dipertahankan agar
      // Beranda tetap menampilkan data terakhir yang diketahui.
      statusOffline = true;
      statusError = friendlyError(e);
      lastError = statusError;
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
      lastError = friendlyError(e);
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
      return 'Perangkat menolak permintaan ini — coba lagi sebentar.';
    } catch (e) {
      return friendlyError(e);
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

  /// Hapus SEMUA SMS yang tampil (v3.1): kumpulkan semua id dari
  /// daftar saat ini lalu kirim SATU DELETE_SMS massal —
  /// ALL_DELETE_SMS lama terbukti tidak menghapus apa pun.
  /// Daftar kosong → tidak ada panggilan ke perangkat.
  Future<String> deleteAllSms() {
    final ids = <String>[
      for (final m in smsList ?? const <SmsMessage>[])
        if (m.id.isNotEmpty) m.id,
    ];
    if (ids.isEmpty) {
      return Future<String>.value('Tidak ada SMS untuk dihapus.');
    }
    return _smsWrite(
      () => client.deleteAllSms(ids),
      'Semua SMS terhapus.',
    );
  }

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
      return 'Perangkat menolak permintaan ini — coba lagi sebentar.';
    } catch (e) {
      return friendlyError(e);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

}
