import 'dart:convert';

/// Hasil parse status gabungan dari GET /reqproc/proc_get.
///
/// Semua field boleh kosong — firmware tidak selalu mengembalikan semua
/// cmd. UI menampilkan "—" untuk field yang null; jangan pernah crash.
class DeviceStatus {
  DeviceStatus(this.raw);

  /// Respons mentah apa adanya (untuk keperluan diagnostik).
  final Map<String, dynamic> raw;

  String? _s(String key) {
    final v = raw[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _dynInt(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  int? _i(String key) => _dynInt(raw[key]);

  String? get networkProvider => _s('network_provider');

  /// Contoh dari dashboard web: "FDD_LTE".
  String? get networkType => _s('network_type');

  /// Jumlah bar sinyal 0–5 dari `signalbar`.
  int? get signalBar => _i('signalbar');

  /// Pilih field dBm mengikuti jenis jaringan (pola convertSignal
  /// WebUI): LTE → lte_rsrp, 3G/WCDMA → rscp, lainnya → rssi.
  /// Bila field utama kosong, coba field dBm lain apa pun yang ada.
  ({String? value, String? source}) _signalPick() {
    final t = (networkType ?? '').toUpperCase();
    String? primary;
    if (t.contains('LTE')) {
      primary = 'lte_rsrp';
    } else if (t.contains('WCDMA') ||
        t.contains('UMTS') ||
        t.contains('HSPA') ||
        t.contains('CDMA') ||
        t.contains('3G')) {
      primary = 'rscp';
    } else {
      primary = 'rssi';
    }
    final pv = _s(primary);
    if (pv != null) return (value: pv, source: primary);
    for (final k in <String>['lte_rsrp', 'rscp', 'rssi', 'wan_csq']) {
      final v = _s(k);
      if (v != null) return (value: v, source: k);
    }
    return (value: null, source: null);
  }

  /// Kekuatan sinyal dBm (string mentah, mis. "-85").
  String? get signalDbm => _signalPick().value;

  /// Nama field asal nilai dBm (untuk label di UI).
  String? get signalDbmSource => _signalPick().source;

  /// Persen baterai asli — HANYA dari battery_vol_percent, dan
  /// hanya bila field itu terisi. battery_pers BUKAN persen
  /// (lihat [batteryLevel]).
  int? get batteryPercent => _i('battery_vol_percent');

  /// Level baterai dari battery_pers — skala 0–3, BUKAN persen.
  /// Bukti uji perangkat asli v1.0 (23 Nov 2026): baterai fisik
  /// PENUH terbaca "3" → 3 = penuh. battery_vol_percent kosong
  /// di perangkat ini, jadi level inilah angka baterai yang ada.
  int? get batteryLevel => _i('battery_pers');

  /// Label teks [batteryLevel]: 3 "Penuh", 2 "Tinggi", 1 "Rendah",
  /// 0 "Habis"; nilai di luar skala 0–3 ditampilkan apa adanya
  /// sebagai "Level N".
  String? get batteryLevelLabel {
    final l = batteryLevel;
    if (l == null) return null;
    switch (l) {
      case 3:
        return 'Penuh';
      case 2:
        return 'Tinggi';
      case 1:
        return 'Rendah';
      case 0:
        return 'Habis';
      default:
        return 'Level $l';
    }
  }

  bool? get batteryCharging {
    final s = _s('battery_charging');
    if (s == null) return null;
    final low = s.toLowerCase();
    if (low == '1' || low == 'true') return true;
    if (low == '0' || low == 'false') return false;
    return null;
  }

  int? get realtimeTxRate => _i('realtime_tx_rate');
  int? get realtimeRxRate => _i('realtime_rx_rate');
  int? get realtimeTxBytes => _i('realtime_tx_bytes');
  int? get realtimeRxBytes => _i('realtime_rx_bytes');

  /// Kecepatan unggah hasil hitung aplikasi (byte/detik) — diisi
  /// AppState dari selisih realtime_tx_bytes antar dua sampel
  /// status, karena realtime_tx_rate kosong di perangkat ini.
  /// Null = belum bisa dihitung (sampel pertama, atau counter
  /// turun karena perangkat reboot).
  int? computedTxRateBps;

  /// Pasangan [computedTxRateBps] untuk arah unduh.
  int? computedRxRateBps;

  // Alias pendek untuk UI: utamakan angka dari perangkat
  // (realtime_*_rate); bila kosong, pakai hasil hitung aplikasi.
  int? get txRate => realtimeTxRate ?? computedTxRateBps;
  int? get rxRate => realtimeRxRate ?? computedRxRateBps;
  int? get txBytes => realtimeTxBytes;
  int? get rxBytes => realtimeRxBytes;

  /// Lama koneksi berjalan dalam detik dari `realtime_time`.
  int? get uptimeSeconds => _i('realtime_time');
  int? get uptime => uptimeSeconds;

  String? get pppStatus => _s('ppp_status');
  String? get connectionStatus => _s('connection_status');

  /// Label koneksi yang ramah bila nilainya dikenal.
  String? get connectionLabel {
    final v = (connectionStatus ?? pppStatus ?? '').toLowerCase();
    if (v.isEmpty) return null;
    if (v.contains('disconnect')) return 'Terputus';
    if (v.contains('connect')) return 'Terhubung';
    if (v.contains('idle')) return 'Terputus';
    return connectionStatus ?? pppStatus;
  }

  /// Peta data_counter yang ditoleransi: perangkat bisa mengirimnya
  /// sebagai Map JSON, atau sebagai string pasangan "kunci:nilai"
  /// dipisah ";" (format serial keluarga firmware ini). Keduanya
  /// dinormalisasi ke Map di sini.
  Map<String, dynamic> get _counter {
    final dc = raw['data_counter'];
    if (dc is Map) {
      return dc.map((k, v) => MapEntry(k.toString(), v));
    }
    if (dc is String) {
      final out = <String, dynamic>{};
      for (final part in dc.split(';')) {
        final p = part.trim();
        if (p.isEmpty) continue;
        var idx = p.indexOf(':');
        if (idx < 0) idx = p.indexOf('=');
        if (idx <= 0) continue;
        out[p.substring(0, idx).trim()] = p.substring(idx + 1).trim();
      }
      return out;
    }
    return const <String, dynamic>{};
  }

  int? _counterInt(String camel, String snake) {
    final c = _counter;
    return _dynInt(c[camel]) ??
        _dynInt(c[snake]) ??
        _dynInt(raw[camel]) ??
        _dynInt(raw[snake]);
  }

  /// Total data terkirim bulan ini (byte) dari data_counter.
  int? get monthlySent => _counterInt('monthlySent', 'monthly_sent');

  /// Total data diterima bulan ini (byte) dari data_counter.
  int? get monthlyReceived =>
      _counterInt('monthlyReceived', 'monthly_received');

  /// Total durasi tersambung bulan ini (detik) dari data_counter.
  int? get monthlyConnectedTime =>
      _counterInt('monthlyConnectedTime', 'monthly_connected_time');

  int? _countStations(dynamic v) {
    if (v == null) return null;
    if (v is List) return v.length;
    if (v is Map) return v.length;
    final t = v.toString().trim();
    if (t.isEmpty) return null;
    try {
      final decoded = jsonDecode(t);
      if (decoded is List) return decoded.length;
      if (decoded is Map) return decoded.length;
    } catch (_) {
      // Bukan JSON — coba format daftar lain di bawah.
    }
    // Format alternatif: entri dipisah ';'.
    final parts = t.split(';').where((e) => e.trim().isNotEmpty).length;
    return parts > 0 ? parts : null;
  }

  /// Jumlah perangkat nirkabel terhubung (station_list).
  int? get stationCount => _countStations(raw['station_list']);

  /// Jumlah perangkat kabel terhubung (lan_station_list).
  int? get lanStationCount => _countStations(raw['lan_station_list']);

  /// SMS belum dibaca dari sms_unread_num.
  int? get smsUnread => _i('sms_unread_num');

  String? get ssid => _s('ssid');
  String? get lanIp => _s('lan_ipaddr');
  String? get maxAccessNum => _s('max_access_num');
}

/// Kapasitas SMS dari cmd=sms_capacity_info.
///
/// TERKONFIRMASI dari uji perangkat asli v1.0: perangkat mengirim
/// sms_nv_total (=20), sms_nv_rev_total, sms_nv_send_total, dan
/// sms_nv_draftbox_total (plus padanan sms_sim_*). Terpakai persis
/// = rev + send + draftbox (penyimpanan perangkat/nv). Bila ketiga
/// field *_total itu absen, jatuh ke heuristik lama: sms_nv_used
/// bila ada; bila tidak, jumlahkan nilai numerik sms_nv_rev* +
/// sms_nv_send* + sms_nv_draft*.
class SmsCapacity {
  SmsCapacity({this.total, this.used, required this.raw});

  factory SmsCapacity.fromJson(Map<String, dynamic> raw) {
    int? dyn(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString().trim());
    }

    final total = dyn(raw['sms_nv_total']);
    // Jalur persis (terkonfirmasi perangkat asli): jumlahkan tiga
    // field *_total kotak pesan perangkat.
    final revTotal = dyn(raw['sms_nv_rev_total']);
    final sendTotal = dyn(raw['sms_nv_send_total']);
    final draftTotal = dyn(raw['sms_nv_draftbox_total']);
    int? used;
    if (revTotal != null || sendTotal != null || draftTotal != null) {
      used = (revTotal ?? 0) + (sendTotal ?? 0) + (draftTotal ?? 0);
    }
    used ??= dyn(raw['sms_nv_used']);
    if (used == null) {
      var sum = 0;
      var found = false;
      for (final e in raw.entries) {
        final k = e.key.toLowerCase();
        if (k.startsWith('sms_nv_rev') ||
            k.startsWith('sms_nv_send') ||
            k.startsWith('sms_nv_draft')) {
          final v = dyn(e.value);
          if (v != null) {
            sum += v;
            found = true;
          }
        }
      }
      if (found) used = sum;
    }
    return SmsCapacity(total: total, used: used, raw: raw);
  }

  /// Total slot SMS di perangkat (sms_nv_total).
  final int? total;

  /// Jumlah SMS tersimpan di perangkat (lihat catatan parse di
  /// atas — persis bila field *_total tersedia).
  final int? used;

  final Map<String, dynamic> raw;
}

/// Satu SMS dari cmd=sms_data_total.
class SmsMessage {
  SmsMessage({
    required this.id,
    required this.number,
    required this.content,
    required this.tag,
    required this.date,
  });

  factory SmsMessage.fromJson(Map<String, dynamic> json) {
    return SmsMessage(
      id: json['id']?.toString() ?? '',
      number: json['number']?.toString() ?? '',
      content: decodeSmsContent(json['content']?.toString() ?? ''),
      tag: json['tag']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }

  final String id;
  final String number;

  /// Isi pesan — sudah di-decode dari hex UTF-16BE bila formatnya hex.
  final String content;

  /// Tag perangkat: "1" = diterima belum dibaca, "0" = diterima sudah
  /// dibaca (konvensi keluarga firmware ini).
  final String tag;

  /// Tanggal mentah dari perangkat, ditampilkan apa adanya.
  final String date;

  bool get isUnread => tag == '1';
}

/// Satu perangkat terhubung dari `station_list` (nirkabel) atau
/// `lan_station_list` (kabel). Bentuk respons TERBUKTI dari probe
/// v1.1 (panggilan terpisah TANPA multi_data): array objek
/// {connect_time, dev_type, mac_addr, hostname, ip_addr, ip_type}.
/// Parser tetap toleran terhadap bentuk lain (string JSON, Map).
class ConnectedDevice {
  ConnectedDevice({
    required this.hostname,
    required this.ipAddr,
    required this.macAddr,
    required this.devType,
    this.connectTime,
    this.ipType,
  });

  factory ConnectedDevice.fromJson(Map<String, dynamic> json) {
    String s(String k) => json[k]?.toString().trim() ?? '';
    return ConnectedDevice(
      hostname: s('hostname'),
      ipAddr: s('ip_addr'),
      macAddr: s('mac_addr'),
      devType: s('dev_type'),
      connectTime: s('connect_time').isEmpty ? null : s('connect_time'),
      ipType: s('ip_type').isEmpty ? null : s('ip_type'),
    );
  }

  final String hostname;
  final String ipAddr;
  final String macAddr;

  /// "wifi" untuk station_list; nilai perangkat untuk kabel.
  final String devType;
  final String? connectTime;
  final String? ipType;

  String get displayName => hostname.isNotEmpty ? hostname : '—';
}

/// Parse toleran daftar stasiun: menerima List of Map, string JSON
/// array, Map (diambil values-nya), atau string kosong → kosong.
List<ConnectedDevice> parseStationList(dynamic v) {
  dynamic data = v;
  if (data is String) {
    final t = data.trim();
    if (t.isEmpty) return <ConnectedDevice>[];
    try {
      data = jsonDecode(t);
    } catch (_) {
      return <ConnectedDevice>[];
    }
  }
  final out = <ConnectedDevice>[];
  if (data is List) {
    for (final e in data) {
      if (e is Map) {
        out.add(ConnectedDevice.fromJson(
          e.map((k, val) => MapEntry(k.toString(), val)),
        ));
      }
    }
  } else if (data is Map) {
    for (final e in data.values) {
      if (e is Map) {
        out.add(ConnectedDevice.fromJson(
          e.map((k, val) => MapEntry(k.toString(), val)),
        ));
      }
    }
  }
  return out;
}

/// Info SSID dari grup WiFi datar (multi_data=1):
/// cmd=SSID1,HideSSID,AuthMode,MAX_Station_num — TERBUKTI probe
/// v1.1: SSID1="iPocket", HideSSID="0", AuthMode="WPA2PSK",
/// MAX_Station_num="32". Field `ssid` huruf kecil di status
/// gabungan selalu kosong, jadi grup inilah sumber SSID asli.
class WifiSsidInfo {
  WifiSsidInfo(this.raw);

  final Map<String, dynamic> raw;

  String? _s(String key) {
    final v = raw[key];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String? get ssid => _s('SSID1');
  String? get authMode => _s('AuthMode');
  String? get maxStationNum => _s('MAX_Station_num');

  bool? get ssidHidden {
    final s = _s('HideSSID');
    if (s == null) return null;
    if (s == '1' || s.toLowerCase() == 'true') return true;
    if (s == '0' || s.toLowerCase() == 'false') return false;
    return null;
  }
}

/// Decode `content` SMS: hex UTF-16BE → teks.
/// Bila isinya bukan hex murni, kembalikan apa adanya (kemungkinan teks
/// polos dari firmware).
String decodeSmsContent(String content) {
  final t = content.trim();
  if (t.isEmpty) return '';
  final isHex = RegExp(r'^[0-9a-fA-F]+$').hasMatch(t) && t.length % 2 == 0;
  if (!isHex) return content;
  try {
    final bytes = <int>[];
    for (var i = 0; i < t.length; i += 2) {
      bytes.add(int.parse(t.substring(i, i + 2), radix: 16));
    }
    final units = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      units.add((bytes[i] << 8) | bytes[i + 1]);
    }
    return String.fromCharCodes(units).replaceAll('\u0000', '');
  } catch (_) {
    return content;
  }
}

/// Encode teks SMS → hex UTF-16BE (kebalikan [decodeSmsContent]).
/// Inilah `encodeMessage` WebUI; hasilnya hanya berisi karakter
/// hex [0-9a-f], sehingga `escapeMessage` (JS escape) WebUI tidak
/// mengubahnya — string hex ini langsung menjadi MessageBody
/// SEND_SMS / SMSMessage SAVE_SMS.
String encodeSmsContent(String text) {
  final sb = StringBuffer();
  for (final unit in text.codeUnits) {
    sb.write(unit.toRadixString(16).padLeft(4, '0'));
  }
  return sb.toString();
}
