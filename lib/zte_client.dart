import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

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

/// Log diagnostik bersama — semua request klien ZTE tercatat di sini.
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
class ZteHttpException implements Exception {
  ZteHttpException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'ZteHttpException: HTTP $statusCode';
}

/// SHA-256 hex dengan huruf besar — format yang dipakai login Gen B ZTE.
String sha256HexUpper(String input) =>
    sha256.convert(utf8.encode(input)).toString().toUpperCase();

/// Klien HTTP untuk API goform ZTE (Advan iPocket MF01).
///
/// Mengikuti API-CONTRACT.md:
/// - Semua request membawa header `Referer: http://<gateway>/`.
/// - Sesi dijaga cookie jar sederhana dari header `set-cookie`.
/// - Login dua generasi: Gen B (LD/RD + SHA-256) dulu, fallback Gen A
///   (password base64).
class ZteClient {
  ZteClient({required this.gateway, required this.log});

  /// Alamat gateway tanpa skema, mis. "192.168.0.1".
  final String gateway;
  final DiagnosticsLog log;

  final http.Client _http = http.Client();
  final Map<String, String> _cookies = <String, String>{};

  /// Daftar cmd status gabungan persis kontrak (multi_data=1).
  static const List<String> statusCmds = <String>[
    'signalbar',
    'wan_csq',
    'rssi',
    'lte_rsrp',
    'lte_rsrq',
    'lte_snr',
    'network_type',
    'network_provider',
    'ppp_status',
    'modem_main_state',
    'connection_status',
    'connect_network',
    'battery_value',
    'battery_charging',
    'battery_vol',
    'realtime_tx_bytes',
    'realtime_rx_bytes',
    'realtime_tx_rate',
    'realtime_rx_rate',
    'realtime_time',
    'data_counter',
    'station_list',
    'wifi_station_list',
    'sms_unread_num',
    'sms_received_flag',
    'lan_ipaddr',
    'ssid',
    'wifi_coverage',
    'max_access_num',
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
      throw ZteHttpException(res.statusCode, res.body);
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

  /// GET /goform/goform_get_cmd_process dengan parameter bebas.
  Future<Map<String, dynamic>> getCmdProcess(
    Map<String, String> params, {
    String? note,
  }) {
    final uri = Uri.parse('$_base/goform/goform_get_cmd_process')
        .replace(queryParameters: params);
    return _send('GET', uri, note: note);
  }

  /// POST /goform/goform_set_cmd_process (form-urlencoded).
  Future<Map<String, dynamic>> postForm(
    Map<String, String> fields, {
    String? note,
  }) {
    final uri = Uri.parse('$_base/goform/goform_set_cmd_process');
    return _send('POST', uri, formBody: fields, note: note);
  }

  /// Ambil LD dan RD untuk login Gen B.
  Future<Map<String, dynamic>> fetchLdRd() {
    return getCmdProcess(
      <String, String>{
        'isTest': 'false',
        'cmd': 'wa_inner_version,cr_version,LD,RD',
        'multi_data': '1',
      },
      note: 'Ambil LD/RD',
    );
  }

  bool _loginOk(Map<String, dynamic> res) {
    final r = res['result']?.toString();
    return r == '0' || hasSession;
  }

  /// Login Gen B: password = SHA256hexUpper(SHA256hexUpper(pw) + LD).
  Future<bool> loginGenB(String password) async {
    final ldRd = await fetchLdRd();
    final ld = ldRd['LD']?.toString() ?? '';
    if (ld.isEmpty) return false;
    final hashed = sha256HexUpper(sha256HexUpper(password) + ld);
    final res = await postForm(
      <String, String>{
        'goformId': 'LOGIN',
        'user': 'admin',
        'password': hashed,
      },
      note: 'Login Gen B',
    );
    return _loginOk(res);
  }

  /// Login Gen A: password = base64(password).
  Future<bool> loginGenA(String password) async {
    final res = await postForm(
      <String, String>{
        'goformId': 'LOGIN',
        'password': base64Encode(utf8.encode(password)),
      },
      note: 'Login Gen A',
    );
    return _loginOk(res);
  }

  /// Coba Gen B, fallback Gen A. Mengembalikan 'B', 'A', atau null.
  Future<String?> login(String password) async {
    try {
      if (await loginGenB(password)) return 'B';
    } catch (_) {
      // Tercatat di log diagnostik — lanjut ke Gen A.
    }
    try {
      if (await loginGenA(password)) return 'A';
    } catch (_) {
      // Tercatat di log diagnostik.
    }
    return null;
  }

  /// Status gabungan persis daftar kontrak.
  Future<Map<String, dynamic>> fetchStatus() {
    return getCmdProcess(
      <String, String>{
        'isTest': 'false',
        'cmd': statusCmds.join(','),
        'multi_data': '1',
      },
      note: 'Status gabungan',
    );
  }

  /// SMS utama persis parameter kontrak.
  Future<Map<String, dynamic>> fetchSmsDataTotal() {
    return getCmdProcess(
      <String, String>{
        'isTest': 'false',
        'cmd': 'sms_data_total',
        'page': '0',
        'data_per_page': '5000',
        'mem_store': '1',
        'tags': '10',
        'order_by': 'order by id desc',
      },
      note: 'SMS sms_data_total',
    );
  }

  /// SMS alternatif UI baru.
  Future<Map<String, dynamic>> fetchSmsPageData() {
    return getCmdProcess(
      <String, String>{'isTest': 'false', 'cmd': 'sms_page_data'},
      note: 'SMS sms_page_data',
    );
  }

  /// Urutan tes lengkap untuk layar Diagnostik:
  /// LD/RD → login Gen B → (gagal) login Gen A → status → SMS.
  /// Semua langkah tercatat di log diagnostik.
  Future<void> runFullTest(String password) async {
    log.addNote('=== TES LENGKAP DIMULAI ===');
    try {
      await fetchLdRd();
    } catch (e) {
      log.addNote('Ambil LD/RD gagal: $e');
    }
    var genB = false;
    try {
      genB = await loginGenB(password);
      log.addNote('Login Gen B: ${genB ? 'BERHASIL' : 'gagal'}');
    } catch (e) {
      log.addNote('Login Gen B error: $e');
    }
    if (!genB) {
      try {
        final a = await loginGenA(password);
        log.addNote('Login Gen A: ${a ? 'BERHASIL' : 'gagal'}');
      } catch (e) {
        log.addNote('Login Gen A error: $e');
      }
    }
    try {
      await fetchStatus();
    } catch (e) {
      log.addNote('Status gabungan gagal: $e');
    }
    try {
      await fetchSmsDataTotal();
    } catch (e) {
      log.addNote('SMS sms_data_total gagal: $e');
    }
    log.addNote('=== TES LENGKAP SELESAI ===');
  }
}
