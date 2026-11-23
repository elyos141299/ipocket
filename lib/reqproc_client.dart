import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'friendly_error.dart';
import 'models.dart';

/// Satu catatan ringkas untuk layar Diagnostik (v3.2, tahap
/// final): SATU baris pendek — waktu + aksi + hasil. Log TIDAK
/// lagi menyimpan URL lengkap, query string, badan respons
/// mentah, atau teks exception (dump mentah itulah keluhan user
/// dari uji v3.1.1).
class DiagEntry {
  DiagEntry({
    required this.time,
    required this.action,
    required this.result,
  });

  final DateTime time;

  /// Aksi pendek, mis. "GET status", "POST SET_WIFI_SSID1_SETTINGS",
  /// "CATATAN".
  final String action;

  /// Hasil pendek, mis. "OK", "result=success",
  /// "gagal: jaringan tidak terjangkau", "gagal: timeout".
  final String result;

  String get formatted {
    String two(int v) => v.toString().padLeft(2, '0');
    final jam = '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
    return '[$jam] $action — $result';
  }
}

/// Log diagnostik bersama — semua request klien tercatat di sini
/// sebagai ringkasan satu baris (disanitasi terpusat di [add]).
class DiagnosticsLog {
  final List<DiagEntry> entries = <DiagEntry>[];

  /// Batas panjang satu entri log (karakter) — entri wajar untuk
  /// ringkasan satu baris.
  static const int maxLineLength = 240;

  /// Sanitasi satu baris log: URL utuh dibuang (menyisakan
  /// penanda), semua whitespace dilipat jadi satu spasi, lalu
  /// dipotong ke [maxLineLength]. Jaring pengaman terakhir agar
  /// tidak ada teks mentah panjang yang lolos ke log dari
  /// pemanggil mana pun.
  static String _clean(String s) {
    var t = s.replaceAll(RegExp(r'https?://\S+'), '(alamat perangkat)');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length > maxLineLength) {
      t = '${t.substring(0, maxLineLength)}…';
    }
    return t;
  }

  void add(DiagEntry entry) {
    entries.add(DiagEntry(
      time: entry.time,
      action: _clean(entry.action),
      result: _clean(entry.result),
    ));
  }

  void addNote(String text) {
    add(DiagEntry(
      time: DateTime.now(),
      action: 'CATATAN',
      result: text,
    ));
  }

  void clear() => entries.clear();

  String get asText => entries.map((e) => e.formatted).join('\n');
}

/// Error HTTP non-200 dari perangkat.
class ReqprocHttpException implements Exception {
  ReqprocHttpException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ReqprocHttpException: HTTP $statusCode';
}

/// Hasil login reqproc, terstruktur agar UI bisa menampilkan pesan
/// Bahasa Indonesia yang tepat untuk tiap kasus.
enum LoginOutcome {
  /// result "0" atau "4" — masuk.
  ok,

  /// result "3" — sandi salah.
  wrongPassword,

  /// result "2" — sudah ada pengguna lain yang masuk.
  multipleUsers,

  /// result lain / respons tak dikenal.
  failed,
}

class LoginResult {
  const LoginResult(this.outcome, this.rawResult);

  final LoginOutcome outcome;

  /// Nilai `result` mentah dari perangkat (untuk diagnostik).
  final String? rawResult;

  bool get ok => outcome == LoginOutcome.ok;
}

/// Klien HTTP untuk API reqproc Advan iPocket MF01.
///
/// Mengikuti API-CONTRACT.md (TERKONFIRMASI dari kode WebUI perangkat):
/// - Objek berisi `cmd` → GET  /reqproc/proc_get?cmd=...&multi_data=1
/// - Objek berisi `goformId` → POST /reqproc/proc_post (form-urlencoded)
/// - Semua request membawa header `Referer: http://<gateway>/`.
/// - Sesi dijaga cookie jar sederhana dari header `set-cookie`.
/// - Login: goformId=LOGIN, password = base64(sandi) karena
///   PASSWORD_ENCODE=true di set.js perangkat.
class ReqprocClient {
  ReqprocClient({required this.gateway, required this.log});

  /// Alamat gateway tanpa skema, mis. "192.168.0.1".
  final String gateway;
  final DiagnosticsLog log;

  final http.Client _http = http.Client();
  final Map<String, String> _cookies = <String, String>{};

  /// Daftar cmd status persis yang dipakai WebUI (com.js), kontrak
  /// bagian "Baca status".
  static const List<String> statusCmds = <String>[
    'modem_main_state',
    'pin_status',
    'puknumber',
    'pinnumber',
    'blc_wan_mode',
    'network_type',
    'sub_network_type',
    'network_provider',
    'signalbar',
    'wan_csq',
    'rssi',
    'rscp',
    'lte_rsrp',
    'lte_rsrq',
    'lte_snr',
    'ppp_status',
    'connection_status',
    'connect_network',
    'battery_vol_percent',
    'battery_pers',
    'battery_charging',
    'battery_vol',
    'realtime_tx_bytes',
    'realtime_rx_bytes',
    'realtime_tx_rate',
    'realtime_rx_rate',
    'realtime_time',
    'data_counter',
    // v3.1: field bulanan & batas data grup status WebUI —
    // TERBUKTI terisi lewat Probe Persen Baterai v3.0
    // (monthly_rx_bytes 1.067.155.788, monthly_tx_bytes
    // 158.831.344 di perangkat user) untuk gauge bulanan asli.
    'monthly_rx_bytes',
    'monthly_tx_bytes',
    'data_volume_limit_switch',
    'data_volume_limit_size',
    'data_volume_limit_unit',
    'station_list',
    'lan_station_list',
    'sms_unread_num',
    'sms_received_flag',
    'lan_ipaddr',
    'ssid',
    'wifi_coverage',
    'max_access_num',
    'loginfo',
  ];

  String get _base => 'http://$gateway';

  Map<String, String> get _headers {
    final h = <String, String>{'Referer': '$_base/'};
    if (_cookies.isNotEmpty) {
      h['Cookie'] =
          _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    return h;
  }

  bool get hasSession => _cookies.isNotEmpty;

  void clearSession() => _cookies.clear();

  /// Label aksi pendek untuk log ringkas v3.2: POST memakai
  /// goformId ("POST SET_WIFI_SSID1_SETTINGS"); GET memakai cmd
  /// pertama ("GET station_list"), dan panggilan banyak field
  /// sekaligus diringkas jadi "GET status".
  static String _actionLabel(
    String method,
    Uri uri,
    Map<String, String>? formBody,
  ) {
    if (method == 'POST') {
      final id = formBody?['goformId'];
      return id == null ? 'POST reqproc' : 'POST $id';
    }
    final cmd = uri.queryParameters['cmd'] ?? '';
    if (cmd.isEmpty) return 'GET data';
    final parts = cmd.split(',');
    if (parts.length > 5) return 'GET status';
    return 'GET ${parts.first}';
  }

  /// Simpan cookie dari header `set-cookie` (bisa gabungan beberapa cookie).
  void _storeCookies(http.Response res) {
    final raw = res.headers['set-cookie'];
    if (raw == null || raw.isEmpty) return;
    // Pisahkan antar-cookie: koma yang diikuti "nama=" dianggap awal cookie
    // baru (koma di dalam tanggal "Expires=Wed, 21 Oct …" tidak punya "=").
    final parts = raw.split(RegExp(r',\s*(?=[^;,=]+?=)'));
    for (final part in parts) {
      final first = part.split(';').first.trim();
      final eq = first.indexOf('=');
      if (eq > 0) {
        _cookies[first.substring(0, eq).trim()] =
            first.substring(eq + 1).trim();
      }
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    Uri uri, {
    Map<String, String>? formBody,
    String? note,
  }) async {
    // v3.2: log hanya mencatat ringkasan satu baris (aksi +
    // hasil pendek) — URL lengkap, query string, badan respons
    // mentah, dan teks exception TIDAK lagi masuk log.
    final action = _actionLabel(method, uri, formBody);
    http.Response res;
    try {
      if (method == 'GET') {
        res = await _http
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 10));
      } else {
        res = await _http
            .post(uri, headers: _headers, body: formBody)
            .timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      log.add(DiagEntry(
        time: DateTime.now(),
        action: action,
        result: 'gagal: ${shortErrorReason(e)}',
      ));
      rethrow;
    }
    _storeCookies(res);
    if (res.statusCode != 200) {
      log.add(DiagEntry(
        time: DateTime.now(),
        action: action,
        result: 'gagal: HTTP ${res.statusCode}',
      ));
      throw ReqprocHttpException(res.statusCode, res.body);
    }
    Map<String, dynamic> decodedMap;
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        decodedMap = decoded;
      } else {
        decodedMap = <String, dynamic>{'_raw': decoded};
      }
    } on FormatException {
      // Respons bukan JSON — kembalikan apa adanya untuk pemanggil.
      decodedMap = <String, dynamic>{'_raw_text': res.body};
    }
    final r = decodedMap['result'];
    log.add(DiagEntry(
      time: DateTime.now(),
      action: action,
      result: r == null ? 'OK' : 'result=$r',
    ));
    return decodedMap;
  }

  /// GET /reqproc/proc_get dengan parameter bebas (objek berisi cmd).
  Future<Map<String, dynamic>> procGet(
    Map<String, String> params, {
    String? note,
  }) {
    final uri =
        Uri.parse('$_base/reqproc/proc_get').replace(queryParameters: params);
    return _send('GET', uri, note: note);
  }

  /// POST /reqproc/proc_post (objek berisi goformId, form-urlencoded).
  Future<Map<String, dynamic>> procPost(
    Map<String, String> fields, {
    String? note,
  }) {
    final uri = Uri.parse('$_base/reqproc/proc_post');
    return _send('POST', uri, formBody: fields, note: note);
  }

  /// Login: POST LOGIN dengan sandi Base64 (PASSWORD_ENCODE=true).
  /// result "0"/"4" sukses, "3" sandi salah, "2" pengguna ganda,
  /// "1"/lainnya gagal.
  Future<LoginResult> login(String password) async {
    final res = await procPost(
      <String, String>{
        'goformId': 'LOGIN',
        'password': base64Encode(utf8.encode(password)),
      },
      note: 'Login reqproc',
    );
    final r = res['result']?.toString();
    switch (r) {
      case '0':
      case '4':
        return LoginResult(LoginOutcome.ok, r);
      case '3':
        return LoginResult(LoginOutcome.wrongPassword, r);
      case '2':
        return LoginResult(LoginOutcome.multipleUsers, r);
      default:
        return LoginResult(LoginOutcome.failed, r);
    }
  }

  /// Keluar dari sesi perangkat.
  Future<void> logout() async {
    await procPost(
      <String, String>{'goformId': 'LOGOUT'},
      note: 'Logout reqproc',
    );
  }

  /// Status gabungan persis daftar kontrak (multi_data=1).
  /// Mengembalikan Map mentah; parsing ada di [DeviceStatus].
  Future<Map<String, dynamic>> getStatus() {
    return procGet(
      <String, String>{
        'cmd': statusCmds.join(','),
        'multi_data': '1',
      },
      note: 'Status reqproc',
    );
  }

  /// Daftar SMS dari sms_data_total; content di-decode di model.
  Future<List<SmsMessage>> getSmsList() async {
    final res = await procGet(
      <String, String>{
        'cmd': 'sms_data_total',
        'page': '0',
        'data_per_page': '500',
        'mem_store': '1',
        'tags': '10',
        'order_by': 'order by id desc',
      },
      note: 'SMS sms_data_total (reqproc)',
    );
    final msgs = res['messages'];
    if (msgs is List) {
      return msgs
          .whereType<Map<String, dynamic>>()
          .map(SmsMessage.fromJson)
          .toList();
    }
    return <SmsMessage>[];
  }

  /// Kapasitas SMS dari sms_capacity_info.
  Future<SmsCapacity> getSmsCapacity() async {
    final res = await procGet(
      <String, String>{'cmd': 'sms_capacity_info'},
      note: 'SMS sms_capacity_info (reqproc)',
    );
    return SmsCapacity.fromJson(res);
  }

  /// Daftar perangkat terhubung — ATURAN EMAS probe v1.1: field
  /// array RUSAK di panggilan multi_data gabungan, jadi
  /// station_list & lan_station_list diminta TERPISAH dan TANPA
  /// multi_data. Respons bisa berbentuk {"station_list":[...]}
  /// atau array JSON telanjang (dibungkus _send sebagai _raw).
  Future<({List<ConnectedDevice> wifi, List<ConnectedDevice> lan})>
      getStations() async {
    List<ConnectedDevice> pick(Map<String, dynamic> res, String key) {
      if (res.containsKey(key)) return parseStationList(res[key]);
      final rawArr = res['_raw'];
      if (rawArr is List) return parseStationList(rawArr);
      return <ConnectedDevice>[];
    }

    final wifiRes = await procGet(
      <String, String>{'cmd': 'station_list'},
      note: 'station_list terpisah (tanpa multi_data)',
    );
    final lanRes = await procGet(
      <String, String>{'cmd': 'lan_station_list'},
      note: 'lan_station_list terpisah (tanpa multi_data)',
    );
    return (
      wifi: pick(wifiRes, 'station_list'),
      lan: pick(lanRes, 'lan_station_list'),
    );
  }

  /// Grup SSID datar ala WebUI (multi_data OK untuk field datar):
  /// SSID1, HideSSID, AuthMode, MAX_Station_num.
  Future<WifiSsidInfo> getWifiSsidInfo() async {
    final res = await procGet(
      <String, String>{
        'cmd': 'SSID1,HideSSID,AuthMode,MAX_Station_num',
        'multi_data': '1',
      },
      note: 'Grup SSID1 (multi_data)',
    );
    return WifiSsidInfo(res);
  }

  /// Format sms_time SEND_SMS — meniru getCurrentTimeString()
  /// WebUI dari lib.js PERSIS (definisi ketemu lewat Penemuan
  /// Terarah v1.4; lihat addendum API-CONTRACT 23 Nov ±15:00):
  /// "yy;MM;dd;hh;mm;ss;" + zona waktu sebagai bilangan polos
  /// TANPA zero-pad. Di JS, zona = 0 - getTimezoneOffset()/60
  /// dengan tanda "+" bila offset JS < 0 (lokal di depan UTC).
  /// timeZoneOffset Dart adalah kebalikannya (WIB = +420
  /// menit), jadi jam = menit/60: WIB menghasilkan "+7" —
  /// BUKAN "+07"; nol di depan itulah yang membuat SEND_SMS
  /// menjawab result "failure" (tes v1.3/v1.4). Zona bersisa
  /// menit mengikuti JS: hasil bagi desimal tanpa padding
  /// (mis. "+5.5").
  static String smsTimeString(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    final yy = two(t.year % 100);
    final hours = t.timeZoneOffset.inMinutes / 60;
    final String tz;
    if (hours == hours.truncateToDouble()) {
      final h = hours.toInt();
      tz = h >= 0 ? '+$h' : '$h';
    } else {
      tz = hours >= 0 ? '+$hours' : '$hours';
    }
    return '$yy;${two(t.month)};${two(t.day)};${two(t.hour)};'
        '${two(t.minute)};${two(t.second)};$tz';
  }

  /// Kirim SMS: POST SEND_SMS {notCallback, Number, sms_time,
  /// MessageBody: escapeMessage(encodeMessage(pesan))} — pola
  /// persis kode asli hasil Penemuan Terarah (v1.4 menambahkan
  /// notCallback:"true" persis bentuk wire WebUI);
  /// encodeMessage = hex UTF-16BE (lihat
  /// [encodeSmsContent]) dan escape() JS tidak mengubah hex.
  /// Mengembalikan Map respons mentah (result "success" = terkirim).
  Future<Map<String, dynamic>> sendSms(String number, String message) {
    log.addNote(
      'SEND_SMS: format sms_time mengikuti lib.js WebUI '
      '(zona polos tanpa zero-pad, WIB "+7").',
    );
    return procPost(
      <String, String>{
        'goformId': 'SEND_SMS',
        'notCallback': 'true',
        'Number': number,
        'sms_time': smsTimeString(DateTime.now()),
        'MessageBody': encodeSmsContent(message),
      },
      note: 'Kirim SMS (SEND_SMS)',
    );
  }

  /// Simpan draf SMS: POST SAVE_SMS {notCallback, SMSMessage:
  /// hex UTF-16BE, SMSNumber: "nomor;", Index} — pola kode asli
  /// hasil Penemuan Terarah (v1.4 menambahkan notCallback:"true"
  /// persis bentuk wire WebUI); numbers digabung ";" + trailing
  /// ";". Index kosong untuk draf baru.
  Future<Map<String, dynamic>> saveSmsDraft(String number, String message) {
    return procPost(
      <String, String>{
        'goformId': 'SAVE_SMS',
        'notCallback': 'true',
        'SMSMessage': encodeSmsContent(message),
        'SMSNumber': '$number;',
        'Index': '',
      },
      note: 'Simpan draf SMS (SAVE_SMS)',
    );
  }

  /// Hapus SMS: POST DELETE_SMS {notCallback, msg_id:
  /// "id;id;"} — pola kode asli hasil Penemuan Terarah (v1.4
  /// menambahkan notCallback:"true"); ids digabung ";" plus
  /// ";" penutup.
  Future<Map<String, dynamic>> deleteSms(List<String> ids) {
    return procPost(
      <String, String>{
        'goformId': 'DELETE_SMS',
        'notCallback': 'true',
        'msg_id': '${ids.join(';')};',
      },
      note: 'Hapus SMS (DELETE_SMS)',
    );
  }

  /// Tandai SMS sudah dibaca: POST SET_MSG_READ {notCallback,
  /// msg_id, tag: 0} — pola kode asli hasil Penemuan Terarah
  /// (v1.4 menambahkan notCallback:"true" persis wire WebUI).
  Future<Map<String, dynamic>> setSmsRead(List<String> ids) {
    return procPost(
      <String, String>{
        'goformId': 'SET_MSG_READ',
        'notCallback': 'true',
        'msg_id': '${ids.join(';')};',
        'tag': '0',
      },
      note: 'Tandai SMS dibaca (SET_MSG_READ)',
    );
  }

  /// Hapus SEMUA SMS yang tampil: SATU POST DELETE_SMS massal
  /// berisi semua id — format persis com.js (msg_id =
  /// ids.join(";") + ";"), sama seperti [deleteSms] tetapi untuk
  /// seluruh daftar.
  ///
  /// v3.1 MENGGANTIKAN ALL_DELETE_SMS: goform itu terbukti TIDAK
  /// menghapus apa pun di perangkat user (menjawab result
  /// "success" tetapi pesan tetap utuh — uji lapangan v3.0),
  /// sedangkan DELETE_SMS per pesan terbukti bekerja. Pemakaian
  /// ALL_DELETE_SMS dihapus total.
  Future<Map<String, dynamic>> deleteAllSms(List<String> ids) {
    return procPost(
      <String, String>{
        'goformId': 'DELETE_SMS',
        'notCallback': 'true',
        'msg_id': '${ids.join(';')};',
      },
      note: 'Hapus semua SMS (DELETE_SMS massal, ${ids.length} id)',
    );
  }

  /// Pengaturan SMS: POST SET_MESSAGE_CENTER {save_time,
  /// MessageCenter, status_save} — pola com.js (save_time =
  /// validitas, status_save = laporan pengiriman "1"/"0").
  Future<Map<String, dynamic>> setMessageCenter({
    required String saveTime,
    required String messageCenter,
    required String statusSave,
  }) {
    return procPost(
      <String, String>{
        'goformId': 'SET_MESSAGE_CENTER',
        'save_time': saveTime,
        'MessageCenter': messageCenter,
        'status_save': statusSave,
      },
      note: 'Pengaturan SMS (SET_MESSAGE_CENTER)',
    );
  }

  /// Sambungkan data: POST CONNECT_NETWORK (result "success").
  Future<Map<String, dynamic>> connectNetwork() {
    return procPost(
      <String, String>{'goformId': 'CONNECT_NETWORK'},
      note: 'Sambungkan (CONNECT_NETWORK)',
    );
  }

  /// Putuskan data: POST DISCONNECT_NETWORK (result "success").
  Future<Map<String, dynamic>> disconnectNetwork() {
    return procPost(
      <String, String>{'goformId': 'DISCONNECT_NETWORK'},
      note: 'Putuskan (DISCONNECT_NETWORK)',
    );
  }

  /// Mulai ulang perangkat: POST REBOOT_DEVICE {} — PASTI sejak
  /// FULL-SPEC-BCD.md (D18, dari file JS WebUI utuh): fungsi aj
  /// di com.js, tanpa field tambahan.
  Future<Map<String, dynamic>> rebootDevice() {
    return procPost(
      <String, String>{'goformId': 'REBOOT_DEVICE'},
      note: 'Mulai ulang perangkat (REBOOT_DEVICE)',
    );
  }

  /// Ganti kata sandi login: POST CHANGE_PASSWORD {newPassword,
  /// oldPassword} — keduanya Base64 (PASSWORD_ENCODE=true),
  /// pola com.js terkonfirmasi. True bila result == "success".
  Future<bool> changePassword(String oldPassword, String newPassword) async {
    final res = await procPost(
      <String, String>{
        'goformId': 'CHANGE_PASSWORD',
        'newPassword': base64Encode(utf8.encode(newPassword)),
        'oldPassword': base64Encode(utf8.encode(oldPassword)),
      },
      note: 'Ganti kata sandi login (CHANGE_PASSWORD)',
    );
    return res['result']?.toString() == 'success';
  }

  /// Probe Baterai & Bulanan (v1.2 "Probe Data Bulanan",
  /// diperluas & diganti nama di v1.3).
  ///
  /// Bagian baterai (BARU v1.3): WebUI menampilkan baterai
  /// sebagai PERSEN (73% saat inspeksi live 23 Nov 2026),
  /// sedangkan dari panggilan gabungan battery_vol_percent
  /// selalu "" dan battery_pers hanya level 0–3. Mengikuti
  /// aturan emas probe v1.1 (field bisa rusak di panggilan
  /// multi_data gabungan), tiga bentuk TANPA multi_data dicoba:
  /// battery_vol_percent sendiri, battery_vol sendiri, dan
  /// grup baterai kecil. Target: persen baterai asli.
  ///
  /// Bagian bulanan (dari v1.2, DIPERTAHANKAN): data_counter
  /// tanpa multi_data + cmd traffic_alert_info (modul
  /// status_traffic_alert WebUI). Hasil perangkat asli
  /// (addendum 14:20) membuktikan keduanya "" karena rencana
  /// Manajemen Data nonaktif — dipertahankan sebagai pembukti
  /// ulang bila user mengaktifkan rencana data.
  /// Semua respons mentah tercatat lewat [procGet].
  Future<void> runMonthlyProbe() async {
    log.addNote('=== PROBE BATERAI & BULANAN DIMULAI ===');
    final batteryProbes = <({String label, Map<String, String> params})>[
      (
        label: 'battery_vol_percent sendiri (tanpa multi_data)',
        params: <String, String>{'cmd': 'battery_vol_percent'},
      ),
      (
        label: 'battery_vol sendiri (tanpa multi_data)',
        params: <String, String>{'cmd': 'battery_vol'},
      ),
      (
        label: 'grup baterai battery_pers,battery_vol_percent,'
            'battery_charging,battery_vol (tanpa multi_data)',
        params: <String, String>{
          'cmd': 'battery_pers,battery_vol_percent,battery_charging,'
              'battery_vol',
        },
      ),
    ];
    var step = 0;
    for (final p in batteryProbes) {
      step++;
      log.addNote('Probe baterai $step/${batteryProbes.length}: ${p.label}');
      try {
        await procGet(p.params, note: 'Probe baterai: ${p.label}');
      } catch (e) {
        log.addNote('Probe baterai $step gagal: ${shortErrorReason(e)}');
      }
    }
    try {
      await procGet(
        <String, String>{'cmd': 'data_counter'},
        note: 'Probe bulanan: data_counter TANPA multi_data',
      );
    } catch (e) {
      log.addNote('Probe data_counter (tanpa multi_data) gagal: ${shortErrorReason(e)}');
    }
    try {
      await procGet(
        <String, String>{'cmd': 'traffic_alert_info'},
        note: 'Probe bulanan: traffic_alert_info',
      );
    } catch (e) {
      log.addNote('Probe traffic_alert_info gagal: ${shortErrorReason(e)}');
    }
    log.addNote('=== PROBE BATERAI & BULANAN SELESAI ===');
  }

  /// Probe Persen Baterai (BARU v3.0): satu GET proc_get dengan
  /// cmd = SELURUH daftar field grup status WebUI PERSIS seperti
  /// yang dikirim WebUI (js/com.js utuh: array dasar `cQ` 12 field
  /// digabung array `aw` 40 field, lalu — karena HAS_SMS aktif —
  /// ditambah 3 field SMS; WebUI menggabungkannya menjadi satu
  /// cmd.join(",") dalam SATU panggilan multi_data=1).
  ///
  /// Latar: WebUI menampilkan persen dari battery_vol_percent
  /// dalam grup ini (dan jatuh ke 100 bila kosong — fallback itu
  /// TIDAK ditiru aplikasi). Di semua tes perangkat, panggilan
  /// getStatus aplikasi selalu menerima battery_vol_percent ""
  /// — dugaan: firmware hanya mengisi field itu bila diminta
  /// dalam grup persis WebUI. Probe ini membuktikannya: respons
  /// mentah tercatat lewat [procGet], dan nilai battery_vol_percent
  /// & battery_pers diekstrak eksplisit ke log sesudahnya.
  /// getStatus utama TIDAK diubah.
  Future<void> runBatteryPercentProbe() async {
    log.addNote('=== PROBE PERSEN BATERAI DIMULAI ===');
    const cmd = 'modem_main_state,pin_status,blc_wan_mode,'
        'blc_wan_auto_mode,loginfo,fota_new_version_state,'
        'fota_current_upgrade_state,fota_upgrade_selector,'
        'network_provider,is_mandatory,sta_count,m_sta_count,'
        'signalbar,network_type,sub_network_type,ppp_status,'
        'rj45_state,EX_SSID1,sta_ip_status,EX_wifi_profile,'
        'm_ssid_enable,wifi_cur_state,SSID1,simcard_roam,'
        'lan_ipaddr,battery_charging,battery_vol_percent,'
        'battery_pers,spn_name_data,spn_b1_flag,spn_b2_flag,'
        'realtime_tx_bytes,realtime_rx_bytes,realtime_time,'
        'realtime_tx_thrpt,realtime_rx_thrpt,monthly_rx_bytes,'
        'monthly_tx_bytes,traffic_alined_delta,monthly_time,'
        'date_month,data_volume_limit_switch,'
        'data_volume_limit_size,data_volume_alert_percent,'
        'data_volume_limit_unit,roam_setting_option,'
        'upg_roam_switch,fota_package_already_download,ssid,'
        'dial_mode,ethwan_mode,default_wan_name,'
        'sms_received_flag,sts_received_flag,sms_unread_num';
    try {
      final res = await procGet(
        <String, String>{'cmd': cmd, 'multi_data': '1'},
        note: 'Probe persen baterai: grup status WebUI utuh '
            '(multi_data=1)',
      );
      final volPercent = res['battery_vol_percent'];
      final pers = res['battery_pers'];
      log.addNote(
        'HASIL PROBE PERSEN BATERAI: '
        'battery_vol_percent=${volPercent == null ? '(tidak ada di respons)' : '"$volPercent"'}; '
        'battery_pers=${pers == null ? '(tidak ada di respons)' : '"$pers"'}',
      );
    } catch (e) {
      log.addNote('Probe persen baterai gagal: ${shortErrorReason(e)}');
    }
    log.addNote('=== PROBE PERSEN BATERAI SELESAI ===');
  }

  /// Probe Field Kosong (v1.1): dari uji perangkat asli v1.0,
  /// beberapa field kembali "" dari panggilan status gabungan
  /// (data_counter, station_list, lan_station_list, ssid,
  /// realtime_tx_rate/rx_rate). Probe ini meminta field-field itu
  /// satu per satu / dalam grup kecil ala WebUI untuk melihat
  /// bentuk respons aslinya. Semua respons mentah tercatat di log
  /// diagnostik lewat [procGet] (dipotong ±2000 karakter per entri),
  /// dibungkus penanda DIMULAI/SELESAI. Kegagalan satu langkah tidak
  /// menghentikan langkah berikutnya.
  Future<void> runFieldProbe() async {
    log.addNote('=== PROBE FIELD KOSONG DIMULAI ===');
    final probes = <({String label, Map<String, String> params})>[
      (
        label: 'data_counter sendiri (multi_data=1)',
        params: <String, String>{'cmd': 'data_counter', 'multi_data': '1'},
      ),
      (
        label: 'station_list sendiri (tanpa multi_data)',
        params: <String, String>{'cmd': 'station_list'},
      ),
      (
        label: 'lan_station_list sendiri (tanpa multi_data)',
        params: <String, String>{'cmd': 'lan_station_list'},
      ),
      (
        label: 'station_list + lan_station_list (multi_data=1)',
        params: <String, String>{
          'cmd': 'station_list,lan_station_list',
          'multi_data': '1',
        },
      ),
      (
        label: 'ssid sendiri (tanpa multi_data)',
        params: <String, String>{'cmd': 'ssid'},
      ),
      (
        label: 'grup WiFi SSID1,HideSSID,AuthMode,MAX_Station_num '
            '(multi_data=1)',
        params: <String, String>{
          'cmd': 'SSID1,HideSSID,AuthMode,MAX_Station_num',
          'multi_data': '1',
        },
      ),
      (
        label: 'data_counter + counter sesi (multi_data=1)',
        params: <String, String>{
          'cmd': 'data_counter,realtime_tx_bytes,realtime_rx_bytes,'
              'realtime_time',
          'multi_data': '1',
        },
      ),
    ];
    var step = 0;
    for (final p in probes) {
      step++;
      log.addNote('Probe $step/${probes.length}: ${p.label}');
      try {
        await procGet(p.params, note: 'Probe field kosong: ${p.label}');
      } catch (e) {
        log.addNote('Probe $step gagal: ${shortErrorReason(e)}');
      }
    }
    log.addNote('=== PROBE FIELD KOSONG SELESAI ===');
  }

  /// Urutan tes untuk layar Diagnostik versi reqproc:
  /// login → status → daftar SMS → kapasitas SMS.
  /// Mengembalikan true bila login berhasil. Semua langkah tercatat
  /// di log diagnostik.
  Future<bool> runFullTest(String password) async {
    log.addNote('=== TES LENGKAP (REQPROC) DIMULAI ===');
    var loginOk = false;
    try {
      final r = await login(password);
      loginOk = r.ok;
      log.addNote(
        'Login reqproc: ${r.ok ? 'BERHASIL' : 'gagal'} '
        '(result=${r.rawResult}, outcome=${r.outcome.name})',
      );
    } catch (e) {
      log.addNote('Login reqproc gagal: ${shortErrorReason(e)}');
    }
    try {
      await getStatus();
    } catch (e) {
      log.addNote('Status reqproc gagal: ${shortErrorReason(e)}');
    }
    try {
      final list = await getSmsList();
      log.addNote('SMS terbaca: ${list.length} pesan.');
    } catch (e) {
      log.addNote('SMS sms_data_total gagal: ${shortErrorReason(e)}');
    }
    try {
      final cap = await getSmsCapacity();
      log.addNote(
        'Kapasitas SMS: terpakai ${cap.used ?? '—'} dari '
        '${cap.total ?? '—'}.',
      );
    } catch (e) {
      log.addNote('SMS sms_capacity_info gagal: ${shortErrorReason(e)}');
    }
    log.addNote('=== TES LENGKAP (REQPROC) SELESAI ===');
    return loginOk;
  }
}
