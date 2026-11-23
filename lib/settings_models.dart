import 'dart:convert';

/// Model data Gelombang B/C/D — hasil parse toleran dari respons
/// proc_get perangkat, mengikuti FULL-SPEC-BCD.md persis.
///
/// Semua field boleh kosong/null: firmware tidak selalu
/// mengembalikan semua cmd. UI menampilkan "—"; jangan crash.

/// Helper parse bersama untuk map mentah proc_get.
class RawMap {
  RawMap(this.raw);

  final Map<String, dynamic> raw;

  String? s(String key) {
    final v = raw[key];
    if (v == null) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  String str(String key) => s(key) ?? '';

  int? i(String key) {
    final v = raw[key];
    if (v == null) return null;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  bool flag(String key) => s(key) == '1';
}

/// Decode Base64 toleran (sandi Wi-Fi dari WPAPSK1_encode).
String decodeB64(String? v) {
  if (v == null || v.trim().isEmpty) return '';
  try {
    return utf8.decode(base64Decode(v.trim()));
  } catch (_) {
    return '';
  }
}

/// Encode teks ke Base64 (sandi Wi-Fi & login, PASSWORD_ENCODE=true).
String encodeB64(String v) => base64Encode(utf8.encode(v));

/// Pisah daftar ";" ala WebUI menjadi entri bersih (tanpa kosong).
List<String> splitSemi(String? v) {
  if (v == null) return <String>[];
  return v
      .split(';')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

// ---------------------------------------------------------------------------
// B1 — Wi-Fi Utama (getWifiBasic)
// ---------------------------------------------------------------------------

class WifiBasic extends RawMap {
  WifiBasic(super.raw);

  /// wifi_cur_state == "1".
  bool get wifiEnabled => s('wifi_cur_state') == '1';

  String get ssid => str('SSID1');
  String get authMode => str('AuthMode');

  /// HideSSID mentah: "0" = SSID tampil (siaran ON), "1" = sembunyi.
  String get hideSsid => str('HideSSID');
  bool get broadcast => hideSsid != '1';

  /// Sandi Wi-Fi hasil Base64-decode WPAPSK1_encode.
  String get passPhrase => decodeB64(s('WPAPSK1_encode'));

  /// Kapabilitas perangkat (MAX_Station_num) — BUKAN setting user.
  int get maxStation {
    final v = i('MAX_Station_num');
    return (v == null || v <= 0) ? 32 : v;
  }

  /// Batas akses yang diatur user (MAX_Access_num).
  int get maxAccess => i('MAX_Access_num') ?? 0;

  String get noForwarding => str('NoForwarding');
  String get showQrcode => str('show_qrcode_flag');
  String get encrypType => str('EncrypType');
  String get defaultKeyId => str('DefaultKeyID');
  String get key1 => str('Key1Str1');
  String get key2 => str('Key2Str1');
  String get key3 => str('Key3Str1');
  String get key4 => str('Key4Str1');

  /// Saklar multi-SSID (untuk SET_WIFI_INFO passthrough).
  String get mSsidEnable => str('m_ssid_enable');
}

/// Mode keamanan WPA-keluarga: perlu security_shared_mode=cipher
/// dan passphrase Base64 saat POST (aturan B1).
bool isWpaFamily(String authMode) {
  const modes = <String>{
    'WPAPSK',
    'WPA2PSK',
    'WPAPSKWPA2PSK',
    'WPA3Personal',
    'WPA2WPA3',
  };
  return modes.contains(authMode);
}

/// Pilihan AuthMode yang ditawarkan form Wi-Fi (nilai wire WebUI).
const List<String> kAuthModes = <String>[
  'WPA2PSK',
  'WPAPSK',
  'WPAPSKWPA2PSK',
  'WPA3Personal',
  'WPA2WPA3',
  'OPEN',
  'SHARED',
];

/// Label ramah untuk AuthMode.
String authModeLabel(String mode) {
  switch (mode) {
    case 'WPA2PSK':
      return 'WPA2-PSK';
    case 'WPAPSK':
      return 'WPA-PSK';
    case 'WPAPSKWPA2PSK':
      return 'WPA/WPA2-PSK';
    case 'WPA3Personal':
      return 'WPA3';
    case 'WPA2WPA3':
      return 'WPA2/WPA3';
    case 'OPEN':
      return 'Terbuka (tanpa sandi)';
    case 'SHARED':
      return 'WEP (Shared)';
    default:
      return mode;
  }
}

/// Aturan cipher WebUI: 1 untuk WPA2PSK & WPA3, selain itu 2.
String cipherFor(String authMode) {
  if (authMode == 'WPA2PSK' ||
      authMode == 'WPA3Personal' ||
      authMode == 'WPA2WPA3') {
    return '1';
  }
  return '2';
}

// ---------------------------------------------------------------------------
// B2 — Pengaturan Cepat (getQuickSettingInfo)
// ---------------------------------------------------------------------------

class QuickSetupInfo extends RawMap {
  QuickSetupInfo(super.raw);

  String get currentIndex => str('Current_index');
  String get index => str('index');
  String get pdpType => str('pdp_type');
  String get apnMode => str('apn_mode');
  String get profileName => str('profile_name');
  String get wanApn => str('wan_apn');
  String get pppAuthMode => str('ppp_auth_mode');
  String get pppUsername => str('ppp_username');
  String get pppPassword => str('ppp_passtmp');
  String get ipv6WanApn => str('ipv6_wan_apn');
  String get ipv6PppAuthMode => str('ipv6_ppp_auth_mode');
  String get ipv6PppUsername => str('ipv6_ppp_username');
  String get ipv6PppPassword => str('ipv6_ppp_passtmp');
  String get ssid => str('SSID1');
  String get hideSsid => str('HideSSID');
  String get authMode => str('AuthMode');
  String get encrypType => str('EncrypType');
  String get defaultKeyId => str('DefaultKeyID');
  String get key1 => str('Key1Str1');
  String get key2 => str('Key2Str1');
  String get key3 => str('Key3Str1');
  String get key4 => str('Key4Str1');
  String get passPhrase => decodeB64(s('WPAPSK1_encode'));
}

// ---------------------------------------------------------------------------
// B3 — WPS (getWpsInfo)
// ---------------------------------------------------------------------------

class WpsInfo extends RawMap {
  WpsInfo(super.raw);

  /// WscModeOption — flag WPS aktif.
  String get wpsFlag => str('WscModeOption');

  /// wps_mode terakhir: "PIN" | "PBC".
  String get wpsType => str('wps_mode');
  String get wpsSsid => str('WPS_SSID');
  bool get radioOn => s('wifi_cur_state') == '1';
  String get ssidEnable => str('m_ssid_enable');
  String get ssid => str('SSID1');
}

// ---------------------------------------------------------------------------
// B4 — Wi-Fi Lanjutan
// ---------------------------------------------------------------------------

class WifiAdvance extends RawMap {
  WifiAdvance(super.raw);

  String get mode => str('WirelessMode');
  String get countryCode => str('CountryCode');
  String get channel => str('Channel');
  String get rate => str('HT_MCS');

  /// "a" atau "b" (perangkat ini "b" = 2.4 GHz).
  String get band => s('wifi_band') == 'a' ? 'a' : 'b';
  String get bandwidth => str('wifi_11n_cap');
  int get maxAccess => i('MAX_Access_num') ?? 0;
  String get mMaxAccess => str('m_MAX_Access_num');
  int get maxStation {
    final v = i('MAX_Station_num');
    return (v == null || v <= 0) ? 32 : v;
  }
}

// ---------------------------------------------------------------------------
// B5/B6 — MAC Filter + nama host
// ---------------------------------------------------------------------------

class MacFilterInfo extends RawMap {
  MacFilterInfo(super.raw);

  /// "1" = Daftar Putih, "2" = Daftar Hitam, lain = nonaktif (SEBAGIAN).
  String get aclMode => str('ACL_mode');
  List<String> get whiteList => splitSemi(s('wifi_mac_white_list'));
  List<String> get blackList => splitSemi(s('wifi_mac_black_list'));
  List<String> get blackHosts => splitSemi(s('wifi_hostname_black_list'));
  String get userIp => str('user_ip_addr');
  String get clientMac => str('client_mac_address');
}

/// Satu entri cmd=hostNameList: {mac, hostname}.
class HostNameEntry {
  HostNameEntry({required this.mac, required this.hostname});

  final String mac;
  final String hostname;
}

/// Parse respons cmd=hostNameList secara toleran: kunci respons
/// bisa "devices", "hostNameList", atau array telanjang (_raw).
List<HostNameEntry> parseHostNameList(Map<String, dynamic> res) {
  dynamic data = res['devices'] ?? res['hostNameList'] ?? res['_raw'];
  if (data is String) {
    try {
      data = jsonDecode(data);
    } catch (_) {
      return <HostNameEntry>[];
    }
  }
  final out = <HostNameEntry>[];
  if (data is List) {
    for (final e in data) {
      if (e is Map) {
        final mac = e['mac']?.toString().trim() ?? '';
        final host = e['hostname']?.toString().trim() ?? '';
        if (mac.isNotEmpty) {
          out.add(HostNameEntry(mac: mac, hostname: host));
        }
      }
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// C9 — Mode Koneksi
// ---------------------------------------------------------------------------

class ConnectionModeInfo extends RawMap {
  ConnectionModeInfo(super.raw);

  /// "auto_dial" | "manual_dial".
  String get mode => str('ConnectionMode');
  bool get roamingAllowed => flag('autoConnectWhenRoaming');
}

// ---------------------------------------------------------------------------
// C10 — Pilih Jaringan
// ---------------------------------------------------------------------------

/// Satu entri hasil pindai m_netselect_contents:
/// "state,shortName,numeric,rat[,subact]" per entri, dipisah ";".
class NetSelectEntry {
  NetSelectEntry({
    required this.state,
    required this.shortName,
    required this.numeric,
    required this.rat,
    required this.subAct,
  });

  factory NetSelectEntry.parse(String part) {
    final cols = part.split(',');
    String col(int idx) => idx < cols.length ? cols[idx].trim() : '';
    final numericRaw = col(2).replaceAll(RegExp(r'[^0-9]'), '');
    return NetSelectEntry(
      state: int.tryParse(col(0)) ?? 0,
      shortName: col(1).replaceAll('"', ''),
      numeric: numericRaw,
      rat: int.tryParse(col(3)) ?? 0,
      // 4 kolom → subact dianggap "NON" (tidak terkirim sebagai angka).
      subAct: cols.length > 4 ? col(4) : '',
    );
  }

  final int state;
  final String shortName;
  final String numeric;
  final int rat;

  /// Kosong bila tidak ada / NaN (dikirim sebagai "" ke SET_NETWORK).
  final String subAct;

  /// Label RAT: 7=4G, 2=3G, 0=2G (peta tampilan WebUI).
  String get ratLabel {
    switch (rat) {
      case 7:
        return '4G';
      case 2:
        return '3G';
      case 0:
        return '2G';
      default:
        return 'RAT $rat';
    }
  }

  String get displayName =>
      shortName.isNotEmpty ? shortName : 'Jaringan $numeric';
}

List<NetSelectEntry> parseNetSelectContents(String? contents) {
  if (contents == null || contents.trim().isEmpty) {
    return <NetSelectEntry>[];
  }
  return contents
      .split(';')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .map(NetSelectEntry.parse)
      .where((e) => e.numeric.isNotEmpty)
      .toList();
}

// ---------------------------------------------------------------------------
// C11 — APN
// ---------------------------------------------------------------------------

/// Satu profil APN dari APN_configtmpN, dipisah pemisah "($)":
/// [0] nama, [1] wanApn, [4] authMode, [5] username, [6] password,
/// [7] pdpType, [10] dnsMode, [11] dns1, [12] dns2.
class ApnProfile {
  ApnProfile({required this.index, required this.parts});

  static ApnProfile? tryParse(int index, String? rawStr) {
    if (rawStr == null || rawStr.trim().isEmpty) return null;
    final parts = rawStr.split('(\$)');
    if (parts.isEmpty || (parts[0].trim().isEmpty && parts.length < 2)) {
      return null;
    }
    return ApnProfile(index: index, parts: parts);
  }

  final int index;
  final List<String> parts;

  String _p(int idx) => idx < parts.length ? parts[idx].trim() : '';

  String get profileName => _p(0);
  String get wanApn => _p(1);
  String get authMode => _p(4);
  String get username => _p(5);
  String get password => _p(6);
  String get pdpType => _p(7).isEmpty ? 'IP' : _p(7);
  String get dnsMode => _p(10);
  String get dns1 => _p(11);
  String get dns2 => _p(12);
}

class ApnData extends RawMap {
  ApnData(super.raw);

  String get currentIndex => str('Current_index');
  String get apnMode => str('apn_mode');

  List<ApnProfile> get profiles {
    final out = <ApnProfile>[];
    for (var idx = 0; idx < 20; idx++) {
      final p = ApnProfile.tryParse(idx, s('APN_configtmp$idx'));
      if (p != null) out.add(p);
    }
    return out;
  }

  /// Profil IPv6 pada indeks yang sama (untuk simpan IPv4v6).
  ApnProfile? ipv6Profile(int index) =>
      ApnProfile.tryParse(index, s('ipv6_APN_configtmp$index'));

  /// Indeks slot kosong pertama untuk profil baru (-1 bila penuh).
  int get firstEmptyIndex {
    for (var idx = 0; idx < 20; idx++) {
      if (ApnProfile.tryParse(idx, s('APN_configtmp$idx')) == null) return idx;
    }
    return -1;
  }
}

// ---------------------------------------------------------------------------
// C12 — Manajemen Data
// ---------------------------------------------------------------------------

class DataLimitInfo extends RawMap {
  DataLimitInfo(super.raw);

  bool get enabled => flag('data_volume_limit_switch');

  /// "data" = berbasis data; selain itu berbasis waktu (jam).
  String get unit => str('data_volume_limit_unit');
  bool get isDataUnit => unit == 'data';

  /// Ukuran mentah; untuk unit data bisa berformat "<n>_<pengali>".
  String get sizeRaw => str('data_volume_limit_size');

  /// Bagian angka dari [sizeRaw].
  String get sizeNumber {
    final r = sizeRaw;
    final idx = r.indexOf('_');
    return idx >= 0 ? r.substring(0, idx) : r;
  }

  /// Pengali dari format "<n>_<pengali>" (null bila tidak ada).
  String? get sizeMultiplier {
    final r = sizeRaw;
    final idx = r.indexOf('_');
    return idx >= 0 && idx + 1 < r.length ? r.substring(idx + 1) : null;
  }

  String get alertPercent => str('data_volume_alert_percent');
  int? get monthlyTx => i('monthly_tx_bytes');
  int? get monthlyRx => i('monthly_rx_bytes');
  int? get monthlyTime => i('monthly_time');
}

// ---------------------------------------------------------------------------
// D13 — Router / DHCP
// ---------------------------------------------------------------------------

class DhcpInfo extends RawMap {
  DhcpInfo(super.raw);

  String get lanIp => str('lan_ipaddr');
  String get lanNetmask => str('lan_netmask');
  String get macAddress => str('mac_address');
  bool get dhcpEnabled => flag('dhcpEnabled');
  String get dhcpStart => str('dhcpStart');
  String get dhcpEnd => str('dhcpEnd');
  int? get dhcpLeaseHours => i('dhcpLease_hour');
}

// ---------------------------------------------------------------------------
// D14 — Firewall
// ---------------------------------------------------------------------------

class FwSysInfo extends RawMap {
  FwSysInfo(super.raw);

  bool get remoteManagement => flag('RemoteManagement');
  bool get wanPingFilter => flag('WANPingFilter');
  bool get upnpEnabled => flag('upnpEnabled');
}

/// Rule Filter Port (IPPortFilterRules_N), string dipisah ",":
/// [0] IP sumber ("any/0" = kosong), [2..3] port sumber,
/// [4] IP tujuan, [6..7] port tujuan, [8] protocol,
/// [9] action ("1" = accept), [10] comment, [11] MAC.
class PortFilterRule {
  PortFilterRule({required this.index, required this.cols});

  static PortFilterRule? parse(int index, String? rawStr) {
    if (rawStr == null || rawStr.trim().isEmpty) return null;
    final cols = rawStr.split(',');
    if (cols.length < 5) return null;
    return PortFilterRule(index: index, cols: cols);
  }

  final int index;
  final List<String> cols;

  String _c(int idx) => idx < cols.length ? cols[idx].trim() : '';

  String get srcIp {
    final v = _c(0);
    return (v == 'any/0' || v == 'any') ? '' : v;
  }

  String get srcPortRange {
    final a = _c(2);
    final b = _c(3);
    if (a.isEmpty && b.isEmpty) return '—';
    return a == b || b.isEmpty ? a : '$a–$b';
  }

  String get dstIp => _c(4);

  String get dstPortRange {
    final a = _c(6);
    final b = _c(7);
    if (a.isEmpty && b.isEmpty) return '—';
    return a == b || b.isEmpty ? a : '$a–$b';
  }

  String get protocol => _c(8);
  bool get accept => _c(9) == '1';
  String get comment => _c(10);
  String get mac => _c(11);

  String get summary {
    final parts = <String>[
      if (srcIp.isNotEmpty) 'dari $srcIp' else 'dari semua IP',
      'port $srcPortRange → ${dstIp.isEmpty ? 'semua IP' : dstIp} '
          'port $dstPortRange',
      if (protocol.isNotEmpty) protocol,
      accept ? 'Terima' : 'Tolak',
    ];
    return parts.join(' • ');
  }
}

class PortFilterData extends RawMap {
  PortFilterData(super.raw);

  bool get enabled => flag('IPPortFilterEnable');
  String get defaultPolicy => str('DefaultFirewallPolicy');

  List<PortFilterRule> get rulesV4 {
    final out = <PortFilterRule>[];
    for (var idx = 0; idx < 10; idx++) {
      final r = PortFilterRule.parse(idx, s('IPPortFilterRules_$idx'));
      if (r != null) out.add(r);
    }
    return out;
  }

  /// Rule IPv6 ditampilkan apa adanya (hapus v6 tidak ditawarkan:
  /// format delete_id v6 tidak pasti dari spek).
  List<String> get rulesV6 {
    final out = <String>[];
    for ( var idx = 0; idx < 10; idx++) {
      final v = s('IPPortFilterRulesv6_$idx');
      if (v != null) out.add(v);
    }
    return out;
  }
}

/// Rule Port Forwarding (PortForwardRules_N):
/// [0] IP, [1..2] rentang port, [3] protocol, [4] comment.
class ForwardRule {
  ForwardRule({required this.index, required this.cols});

  static ForwardRule? parse(int index, String? rawStr) {
    if (rawStr == null || rawStr.trim().isEmpty) return null;
    final cols = rawStr.split(',');
    if (cols.length < 3) return null;
    return ForwardRule(index: index, cols: cols);
  }

  final int index;
  final List<String> cols;

  String _c(int idx) => idx < cols.length ? cols[idx].trim() : '';

  String get ip => _c(0);
  String get portStart => _c(1);
  String get portEnd => _c(2);
  String get protocol => _c(3);
  String get comment => _c(4);

  String get portRange =>
      portStart == portEnd || portEnd.isEmpty ? portStart : '$portStart–$portEnd';
}

class ForwardData extends RawMap {
  ForwardData(super.raw);

  bool get enabled => flag('PortForwardEnable');

  List<ForwardRule> get rules {
    final out = <ForwardRule>[];
    for (var idx = 0; idx < 10; idx++) {
      final r = ForwardRule.parse(idx, s('PortForwardRules_$idx'));
      if (r != null) out.add(r);
    }
    return out;
  }
}

/// Rule Port Mapping (PortMapRules_N):
/// [0] IP tujuan, [1] port sumber, [2] port tujuan, [3] protocol,
/// [4] comment.
class PortMapRule {
  PortMapRule({required this.index, required this.cols});

  static PortMapRule? parse(int index, String? rawStr) {
    if (rawStr == null || rawStr.trim().isEmpty) return null;
    final cols = rawStr.split(',');
    if (cols.length < 4) return null;
    return PortMapRule(index: index, cols: cols);
  }

  final int index;
  final List<String> cols;

  String _c(int idx) => idx < cols.length ? cols[idx].trim() : '';

  String get ip => _c(0);
  String get fromPort => _c(1);
  String get toPort => _c(2);
  String get protocol => _c(3);
  String get comment => _c(4);
}

class PortMapData extends RawMap {
  PortMapData(super.raw);

  bool get enabled => flag('PortMapEnable');

  List<PortMapRule> get rules {
    final out = <PortMapRule>[];
    for (var idx = 0; idx < 10; idx++) {
      final r = PortMapRule.parse(idx, s('PortMapRules_$idx'));
      if (r != null) out.add(r);
    }
    return out;
  }
}

class DmzInfo extends RawMap {
  DmzInfo(super.raw);

  bool get enabled => flag('DMZEnable');
  String get ipAddress => str('DMZIPAddress');
}

// ---------------------------------------------------------------------------
// D15 — SNTP / Waktu
// ---------------------------------------------------------------------------

class SntpInfo extends RawMap {
  SntpInfo(super.raw);

  String _t(String key) => str(key);

  /// Waktu perangkat tersusun dari field sntp_year..sntp_second.
  String get deviceTime {
    final y = _t('sntp_year');
    if (y.isEmpty) return '—';
    String two(String v) => v.padLeft(2, '0');
    return '$y-${two(_t('sntp_month'))}-${two(_t('sntp_day'))} '
        '${two(_t('sntp_hour'))}:${two(_t('sntp_minute'))}:'
        '${two(_t('sntp_second'))}';
  }

  /// "auto" (SNTP) | "manual".
  String get mode => str('sntp_time_set_mode');

  String get server0 => str('sntp_server0');
  String get server1 => str('sntp_server1');
  String get server2 => str('sntp_server2');
  String get other0 => str('sntp_other_server0');
  String get other1 => str('sntp_other_server1');
  String get other2 => str('sntp_other_server2');
  String get timezone => str('sntp_timezone');
  String get timezoneIndex => str('sntp_timezone_index');
  bool get dstEnabled => flag('sntp_dst_enable');
  String get processResult => str('sntp_process_result');

  String get year => str('sntp_year');
  String get month => str('sntp_month');
  String get day => str('sntp_day');
  String get hour => str('sntp_hour');
  String get minute => str('sntp_minute');
}

// ---------------------------------------------------------------------------
// D16 — FOTA
// ---------------------------------------------------------------------------

class FotaInfo extends RawMap {
  FotaInfo(super.raw);

  /// "has_critical" | "has_optional" | "already_has_pkg" | lain.
  String get newVersionState => str('fota_new_version_state');
  String get upgradeState => str('fota_current_upgrade_state');
  String get packageDownloaded => str('fota_package_already_download');

  String get newVersionLabel {
    switch (newVersionState) {
      case 'has_critical':
        return 'Ada pembaruan penting';
      case 'has_optional':
        return 'Ada pembaruan opsional';
      case 'already_has_pkg':
        return 'Paket pembaruan sudah terunduh';
      default:
        return 'Tidak ada pembaruan baru';
    }
  }
}

class FotaAutoInfo extends RawMap {
  FotaAutoInfo(super.raw);

  String get updateMode => str('fota_updateMode');
  String get intervalDay => str('fota_updateIntervalDay');
  String get allowRoaming => str('fota_allowRoamingUpdate');
}

// ---------------------------------------------------------------------------
// D17 — PIN SIM (baca-saja)
// ---------------------------------------------------------------------------

class PinInfo extends RawMap {
  PinInfo(super.raw);

  /// Status PIN mentah dari perangkat (pin_status).
  String get pinStatus => str('pin_status');

  /// Sisa upaya PIN (pinnumber).
  String get pinRemain => str('pinnumber');

  /// Sisa upaya PUK (puknumber).
  String get pukRemain => str('puknumber');
}
