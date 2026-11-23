import 'dart:convert';

/// Hasil parse status gabungan dari goform_get_cmd_process.
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

  int? _i(String key) {
    final s = _s(key);
    return s == null ? null : int.tryParse(s);
  }

  String? get networkProvider => _s('network_provider');

  /// Contoh dari dashboard web: "FDD_LTE".
  String? get networkType => _s('network_type');

  /// Jumlah bar sinyal 0–5 dari `signalbar`.
  int? get signalBars => _i('signalbar');

  /// Kekuatan sinyal dBm — kandidat kontrak: rssi, lalu lte_rsrp.
  String? get signalDbm => _s('rssi') ?? _s('lte_rsrp');

  /// Nama field asal nilai dBm (untuk label di UI).
  String? get signalDbmSource =>
      _s('rssi') != null ? 'rssi' : (_s('lte_rsrp') != null ? 'lte_rsrp' : null);

  /// Nilai baterai mentah dari `battery_value` (ditampilkan apa adanya).
  String? get batteryValue => _s('battery_value');

  bool? get batteryCharging {
    final s = _s('battery_charging');
    if (s == null) return null;
    return s == '1' || s.toLowerCase() == 'true';
  }

  int? get txRate => _i('realtime_tx_rate');
  int? get rxRate => _i('realtime_rx_rate');
  int? get txBytes => _i('realtime_tx_bytes');
  int? get rxBytes => _i('realtime_rx_bytes');

  /// Uptime koneksi dalam detik dari `realtime_time`.
  int? get uptimeSeconds => _i('realtime_time');

  String? get smsUnread => _s('sms_unread_num');
  String? get ssid => _s('ssid');
  String? get lanIp => _s('lan_ipaddr');
  String? get maxAccessNum => _s('max_access_num');

  /// Status koneksi mentah dari field pertama yang tersedia.
  String? get connectionStatusRaw =>
      _s('connection_status') ?? _s('ppp_status') ?? _s('modem_main_state');

  /// Label koneksi yang lebih ramah bila nilainya dikenal.
  String? get connectionLabel {
    final s = connectionStatusRaw;
    if (s == null) return null;
    switch (s) {
      case 'ppp_connected':
        return 'Terhubung';
      case 'ppp_disconnected':
        return 'Terputus';
      default:
        return s;
    }
  }

  int? _countStations(String? rawList) {
    if (rawList == null) return null;
    final t = rawList.trim();
    if (t.isEmpty) return null;
    try {
      final decoded = jsonDecode(t);
      if (decoded is List) return decoded.length;
    } catch (_) {
      // Bukan JSON — coba format daftar lain di bawah.
    }
    // Format alternatif: entri dipisah ';'.
    final parts = t.split(';').where((e) => e.trim().isNotEmpty).length;
    return parts > 0 ? parts : null;
  }

  /// Jumlah perangkat terhubung dari station_list + wifi_station_list.
  int? get stationCount {
    final a = _countStations(_s('station_list'));
    final b = _countStations(_s('wifi_station_list'));
    if (a == null && b == null) return null;
    return (a ?? 0) + (b ?? 0);
  }
}

/// Satu SMS dari cmd=sms_data_total / sms_page_data.
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
  final String tag;

  /// Tanggal mentah dari perangkat, ditampilkan apa adanya.
  final String date;
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
