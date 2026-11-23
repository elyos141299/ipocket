import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Satu catatan request/respons untuk layar Diagnostik.
class DiagEntry {
  DiagEntry({
    required this.time,
    required this.method,
    required this.url,
    required this.statusCode,
    required this.body,
    this.note,
  });

  final DateTime time;
  final String method;
  final String url;
  final int? statusCode;
  final String body;
  final String? note;

  String get formatted {
    String two(int v) => v.toString().padLeft(2, '0');
    final jam = '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
    final status = statusCode == null ? '(tanpa respons)' : 'HTTP $statusCode';
    final catatan = note == null ? '' : '\nCatatan: $note';
    return '[$jam] $method $url\nStatus: $status$catatan\nIsi:\n$body';
  }
}

/// Log diagnostik bersama — semua request klien tercatat di sini.
class DiagnosticsLog {
  final List<DiagEntry> entries = <DiagEntry>[];

  void add(DiagEntry entry) => entries.add(entry);

  void addNote(String text) {
    entries.add(DiagEntry(
      time: DateTime.now(),
      method: 'CATATAN',
      url: '-',
      statusCode: null,
      body: text,
    ));
  }

  void clear() => entries.clear();

  String get asText => entries.map((e) => e.formatted).join('\n\n');
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

  static String _truncate(String s, [int max = 2000]) => s.length <= max
      ? s
      : '${s.substring(0, max)}\n…(dipotong, total ${s.length} karakter)';

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
        method: method,
        url: uri.toString(),
        statusCode: null,
        body: 'ERROR: $e',
        note: note,
      ));
      rethrow;
    }
    _storeCookies(res);
    log.add(DiagEntry(
      time: DateTime.now(),
      method: method,
      url: uri.toString(),
      statusCode: res.statusCode,
      body: _truncate(res.body),
      note: note,
    ));
    if (res.statusCode != 200) {
      throw ReqprocHttpException(res.statusCode, res.body);
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return <String, dynamic>{'_raw': decoded};
    } on FormatException {
      // Respons bukan JSON — kembalikan apa adanya untuk diagnostik.
      return <String, dynamic>{'_raw_text': res.body};
    }
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
        log.addNote('Probe $step gagal: $e');
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
      log.addNote('Login reqproc error: $e');
    }
    try {
      await getStatus();
    } catch (e) {
      log.addNote('Status reqproc gagal: $e');
    }
    try {
      final list = await getSmsList();
      log.addNote('SMS terbaca: ${list.length} pesan.');
    } catch (e) {
      log.addNote('SMS sms_data_total gagal: $e');
    }
    try {
      final cap = await getSmsCapacity();
      log.addNote(
        'Kapasitas SMS: terpakai ${cap.used ?? '—'} dari '
        '${cap.total ?? '—'}.',
      );
    } catch (e) {
      log.addNote('SMS sms_capacity_info gagal: $e');
    }
    log.addNote('=== TES LENGKAP (REQPROC) SELESAI ===');
    return loginOk;
  }
}
