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

  /// Persen baterai: battery_vol_percent, fallback battery_pers.
  int? get batteryPercent =>
      _i('battery_vol_percent') ?? _i('battery_pers');

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

  // Alias pendek untuk UI.
  int? get txRate => realtimeTxRate;
  int? get rxRate => realtimeRxRate;
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
/// Kontrak hanya memastikan `sms_nv_total` dan keluarga `sms_nv_rev*`;
/// pemetaan "terpakai" WebUI (nvUsed) tidak menyebut nama field persis,
/// jadi parse-nya toleran: pakai sms_nv_used bila ada; bila tidak,
/// jumlahkan nilai numerik sms_nv_rev* + sms_nv_send* + sms_nv_draft*.
class SmsCapacity {
  SmsCapacity({this.total, this.used, required this.raw});

  factory SmsCapacity.fromJson(Map<String, dynamic> raw) {
    int? dyn(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString().trim());
    }

    final total = dyn(raw['sms_nv_total']);
    var used = dyn(raw['sms_nv_used']);
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

  /// Perkiraan jumlah SMS tersimpan (lihat catatan parse di atas).
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
