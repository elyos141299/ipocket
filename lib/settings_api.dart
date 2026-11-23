import 'reqproc_client.dart';
import 'settings_models.dart';

/// Hasil POST pengaturan yang sudah dinilai: sukses bila
/// result == "success" (atau "processing" untuk SNTP).
class PostResult {
  const PostResult({required this.ok, required this.rawResult, this.message});

  final bool ok;

  /// Nilai `result` mentah dari perangkat.
  final String? rawResult;

  /// Pesan siap tampil (Bahasa Indonesia).
  final String? message;
}

/// Lapisan API Gelombang B/C/D di atas [ReqprocClient].
///
/// Semua goformId, nama field, dan enum mengikuti
/// FULL-SPEC-BCD.md PERSIS (digali dari file JS WebUI utuh).
/// Metode GET mengembalikan model ter-parse; metode POST
/// mengembalikan [PostResult]. Respons mentah selalu tercatat
/// di log Diagnostik oleh klien.
class SettingsApi {
  SettingsApi(this.client);

  final ReqprocClient client;

  // ---------- Primitif ----------

  Future<Map<String, dynamic>> getCmds(
    List<String> cmds, {
    bool multiData = true,
    String? note,
  }) {
    final params = <String, String>{'cmd': cmds.join(',')};
    if (multiData) params['multi_data'] = '1';
    return client.procGet(params, note: note);
  }

  Future<PostResult> post(
    Map<String, String> fields, {
    required String note,
    String okText = 'Pengaturan tersimpan.',
    bool processingOk = false,
  }) async {
    final res = await client.procPost(fields, note: note);
    final r = res['result']?.toString();
    if (r == 'success' || (processingOk && r == 'processing')) {
      return PostResult(ok: true, rawResult: r, message: okText);
    }
    return PostResult(
      ok: false,
      rawResult: r,
      // v3.2: pesan gagal ramah tanpa nilai result mentah.
      message: 'Perangkat menolak pengaturan ini — '
          'pengaturan mungkin tidak diterapkan. Coba lagi sebentar.',
    );
  }

  // =========================================================================
  // B1 — Wi-Fi Utama
  // =========================================================================

  static const List<String> wifiBasicCmds = <String>[
    'm_ssid_enable',
    'wifi_cur_state',
    'NoForwarding',
    'm_NoForwarding',
    'WPAPSK1_encode',
    'm_WPAPSK1_encode',
    'MAX_Station_num',
    'SSID1',
    'AuthMode',
    'HideSSID',
    'MAX_Access_num',
    'show_qrcode_flag',
    'EncrypType',
    'Key1Str1',
    'Key2Str1',
    'Key3Str1',
    'Key4Str1',
    'DefaultKeyID',
    'm_SSID',
    'm_AuthMode',
    'm_HideSSID',
    'm_MAX_Access_num',
    'm_EncrypType',
    'm_show_qrcode_flag',
    'm_DefaultKeyID',
    'm_Key1Str1',
    'm_Key2Str1',
    'm_Key3Str1',
    'm_Key4Str1',
    'rotationFlag',
    'wifi_sta_connection',
  ];

  Future<WifiBasic> getWifiBasic() async {
    final res = await getCmds(wifiBasicCmds, note: 'Wi-Fi utama (getWifiBasic)');
    return WifiBasic(res);
  }

  /// POST SET_WIFI_SSID1_SETTINGS dengan aturan kondisional B1:
  /// - WPA-keluarga → security_shared_mode=cipher + passphrase Base64
  /// - SHARED → shared_mode "WEP", security_mode "SHARED" + kunci WEP
  /// - EncrypType WEP (mode OPEN) → shared_mode "WEP" + kunci WEP
  /// - selain itu → security_shared_mode "NONE"
  Future<PostResult> setWifiBasic({
    required String ssid,
    required bool broadcast,
    required int maxAccessNum,
    required String authMode,
    required String passPhrase,
    required String noForwarding,
    required String showQrcode,
    required String encrypType,
    required String wepDefaultKey,
    required List<String> wepKeys,
  }) {
    final cipher = cipherFor(authMode);
    final fields = <String, String>{
      'goformId': 'SET_WIFI_SSID1_SETTINGS',
      'ssid': ssid,
      // Checkbox siaran tercentang → "0" (HideSSID 0 = SSID tampil).
      'broadcastSsidEnabled': broadcast ? '0' : '1',
      'MAX_Access_num': maxAccessNum.toString(),
      'security_mode': authMode,
      'cipher': cipher,
      'NoForwarding': noForwarding,
      'show_qrcode_flag': showQrcode,
    };
    var wep = false;
    if (isWpaFamily(authMode)) {
      fields['security_shared_mode'] = cipher;
      fields['passphrase'] = encodeB64(passPhrase);
    } else if (authMode == 'SHARED') {
      fields['security_shared_mode'] = 'WEP';
      fields['security_mode'] = 'SHARED';
      wep = true;
    } else if (encrypType == 'WEP') {
      fields['security_shared_mode'] = 'WEP';
      fields['security_mode'] = 'OPEN';
      wep = true;
    } else {
      fields['security_shared_mode'] = 'NONE';
    }
    if (wep) {
      fields['wep_default_key'] = wepDefaultKey;
      for (var k = 0; k < 4 && k < wepKeys.length; k++) {
        fields['wep_key_${k + 1}'] = wepKeys[k];
      }
      // Tepat satu WEPxSelect sesuai wep_default_key ("0"→1 … "3"→4).
      final sel = (int.tryParse(wepDefaultKey) ?? 0) + 1;
      fields['WEP${sel}Select'] = '1';
    }
    return post(fields, note: 'Simpan Wi-Fi utama (SET_WIFI_SSID1_SETTINGS)');
  }

  /// Saklar Wi-Fi on/off: SET_WIFI_INFO passthrough. Saat mematikan
  /// ("0") WebUI hanya mengirim {goformId, wifiEnabled:"0"}.
  Future<PostResult> setWifiEnabled({
    required bool enabled,
    required String mSsidEnable,
  }) {
    final fields = <String, String>{
      'goformId': 'SET_WIFI_INFO',
      'wifiEnabled': enabled ? '1' : '0',
    };
    if (enabled) fields['m_ssid_enable'] = mSsidEnable;
    return post(
      fields,
      note: 'Saklar Wi-Fi (SET_WIFI_INFO)',
      okText: enabled ? 'Wi-Fi dinyalakan.' : 'Wi-Fi dimatikan.',
    );
  }

  // =========================================================================
  // B2 — Pengaturan Cepat
  // =========================================================================

  static List<String> quickSetupCmds() {
    final cmds = <String>[
      'pdp_type',
      'ipv6_pdp_type',
      'wifi_cur_state',
      'SSID1',
      'HideSSID',
      'AuthMode',
      'WscModeOption',
      'ppp_status',
      'apn_index',
      'ipv6_apn_index',
      'ipv6_APN_index',
      'm_profile_name',
      'apn_mode',
      'EncrypType',
      'DefaultKeyID',
      'Key1Str1',
      'Key2Str1',
      'Key3Str1',
      'Key4Str1',
      'WPAPSK1_encode',
      'profile_name',
      'wan_dial',
      'pdp_select',
      'index',
      'Current_index',
      'apn_auto_config',
      'ipv6_apn_auto_config',
      'wan_apn',
      'ppp_auth_mode',
      'ppp_username',
      'ppp_passtmp',
      'ipv6_wan_apn',
      'ipv6_ppp_auth_mode',
      'ipv6_ppp_username',
      'ipv6_ppp_passtmp',
      'apn_num_preset',
    ];
    for (var k = 0; k < 20; k++) {
      cmds.add('APN_configtmp$k');
      cmds.add('ipv6_APN_configtmp$k');
    }
    return cmds;
  }

  Future<QuickSetupInfo> getQuickSetup() async {
    final res = await getCmds(quickSetupCmds(), note: 'Pengaturan Cepat (prefill)');
    return QuickSetupInfo(res);
  }

  /// POST QUICK_SETUP_EX — objek utuh sesuai spek B2.
  Future<PostResult> setQuickSetup({
    required QuickSetupInfo base,
    required String profileName,
    required String wanApn,
    required String pppAuthMode,
    required String pppUsername,
    required String pppPassword,
    required String ssidName,
    required bool ssidBroadcast,
    required String authMode,
    required String passPhrase,
  }) {
    final cipher = cipherFor(authMode);
    final String sharedMode;
    if (isWpaFamily(authMode)) {
      sharedMode = cipher;
    } else if (authMode == 'SHARED' || base.encrypType == 'WEP') {
      sharedMode = 'WEP';
    } else {
      sharedMode = 'NONE';
    }
    final fields = <String, String>{
      'goformId': 'QUICK_SETUP_EX',
      'index': base.currentIndex.isNotEmpty ? base.currentIndex : base.index,
      'pdp_type': base.pdpType,
      'apn_mode': base.apnMode,
      'profile_name': profileName,
      'wan_apn': wanApn,
      'ppp_auth_mode': pppAuthMode,
      'ppp_username': pppUsername,
      'ppp_passtmp': pppPassword,
      'ipv6_wan_apn': base.ipv6WanApn,
      'ipv6_ppp_auth_mode': base.ipv6PppAuthMode,
      'ipv6_ppp_username': base.ipv6PppUsername,
      'ipv6_ppp_passtmp': base.ipv6PppPassword,
      'SSID_name': ssidName,
      'SSID_Broadcast': ssidBroadcast ? '0' : '1',
      'Encryption_Mode_hid': authMode,
      'security_shared_mode': sharedMode,
      'WPA_PreShared_Key': isWpaFamily(authMode) ? encodeB64(passPhrase) : '',
      'wep_default_key': base.defaultKeyId,
      'WPA_ENCRYPTION_hid': base.encrypType,
      'wep_key_1': base.key1,
      'wep_key_2': base.key2,
      'wep_key_3': base.key3,
      'wep_key_4': base.key4,
    };
    if (sharedMode == 'WEP') {
      final sel = (int.tryParse(base.defaultKeyId) ?? 0) + 1;
      fields['WEP${sel}Select'] = '1';
    }
    return post(fields, note: 'Pengaturan Cepat (QUICK_SETUP_EX)');
  }

  // =========================================================================
  // B3 — WPS
  // =========================================================================

  Future<WpsInfo> getWps() async {
    final res = await getCmds(
      const <String>[
        'wifi_wps_index',
        'WscModeOption',
        'AuthMode',
        'wifi_cur_state',
        'EncrypType',
        'wps_mode',
        'WPS_SSID',
        'm_ssid_enable',
        'SSID1',
        'm_SSID',
        'm_EncrypType',
        'm_AuthMode',
        'wifi_sta_connection',
      ],
      note: 'WPS (getWpsInfo)',
    );
    return WpsInfo(res);
  }

  /// POST WIFI_WPS_SET (SSID1); wps_pin HANYA bila mode PIN.
  /// PIN: pemisah di posisi 4 dibuang sebelum dikirim (spek B3).
  Future<PostResult> startWps({
    required String ssid,
    required String mode,
    required String pin,
    bool secondSsid = false,
    String mSsid = '',
  }) {
    final cleanPin = pin.replaceAll(RegExp(r'[\s-]'), '');
    if (!secondSsid) {
      final fields = <String, String>{
        'goformId': 'WIFI_WPS_SET',
        'WPS_SSID': ssid,
        'wps_mode': mode,
        'wifi_wps_index': '1',
      };
      if (mode == 'PIN') fields['wps_pin'] = cleanPin;
      return post(fields, note: 'WPS SSID1 (WIFI_WPS_SET)', okText: 'WPS dimulai.');
    }
    final fields = <String, String>{
      'goformId': 'WIFI_M_WPS_SET',
      'm_WPS_SSID': mSsid,
      'm_wps_mode': mode,
      'm_wifi_wps_index': '2',
    };
    if (mode == 'PIN') fields['m_wps_pin'] = cleanPin;
    return post(fields, note: 'WPS SSID2 (WIFI_M_WPS_SET)', okText: 'WPS dimulai.');
  }

  // =========================================================================
  // B4 — Wi-Fi Lanjutan
  // =========================================================================

  Future<WifiAdvance> getWifiAdvance() async {
    final res = await getCmds(
      const <String>[
        'WirelessMode',
        'CountryCode',
        'Channel',
        'HT_MCS',
        'wifi_band',
        'wifi_11n_cap',
        'MAX_Access_num',
        'm_MAX_Access_num',
        'MAX_Station_num',
        'wifi_sta_connection',
      ],
      note: 'Wi-Fi Lanjutan (prefill)',
    );
    return WifiAdvance(res);
  }

  /// POST SET_WIFI_INFO (advance). wifi_band & wifi_11n_cap TIDAK
  /// dikirim: flag support keduanya mati di build unit ini
  /// (spek B4) sehingga WebUI pun tidak mengirimnya.
  Future<PostResult> setWifiAdvance({
    required WifiAdvance base,
    required String countryCode,
    required String channel,
    required int maxAccessNum,
  }) {
    final fields = <String, String>{
      'goformId': 'SET_WIFI_INFO',
      'wifiMode': base.mode,
      'countryCode': countryCode,
      'MAX_Access_num': maxAccessNum.toString(),
      'm_MAX_Access_num': base.mMaxAccess,
      // Band perangkat ini "b" (2.4 GHz): kirim kanal + rate.
      'selectedChannel': channel,
      'abg_rate': base.rate,
    };
    return post(fields, note: 'Wi-Fi Lanjutan (SET_WIFI_INFO)');
  }

  // =========================================================================
  // B5/B6 — MAC Filter, blokir, nama host
  // =========================================================================

  Future<MacFilterInfo> getMacFilter() async {
    final res = await getCmds(
      const <String>[
        'ACL_mode',
        'wifi_mac_black_list',
        'wifi_hostname_black_list',
        'wifi_cur_state',
        'user_ip_addr',
        'client_mac_address',
        'wifi_mac_white_list',
      ],
      note: 'Filter MAC (getMacFilterInfo)',
    );
    return MacFilterInfo(res);
  }

  /// POST WIFI_MAC_FILTER — pola pemanggil halaman MAC filter:
  /// hanya daftar sesuai mode terpilih yang dikirim.
  Future<PostResult> setMacFilterPage({
    required String aclMode,
    required List<String> whiteList,
    required List<String> blackList,
  }) {
    final fields = <String, String>{
      'goformId': 'WIFI_MAC_FILTER',
      'ACL_mode': aclMode,
    };
    if (aclMode == '1') {
      fields['wifi_mac_white_list'] = whiteList.join(';');
    } else if (aclMode == '2') {
      fields['wifi_mac_black_list'] = blackList.join(';');
    }
    return post(fields, note: 'Filter MAC (WIFI_MAC_FILTER)');
  }

  /// Blokir / lepas blokir — pola persis wifi_station_info (B6):
  /// {ACL_mode:"2", macFilteringMode:"2", kedua daftar hitam}.
  Future<PostResult> setBlacklist({
    required List<String> macs,
    required List<String> hosts,
  }) {
    return post(
      <String, String>{
        'goformId': 'WIFI_MAC_FILTER',
        'ACL_mode': '2',
        'macFilteringMode': '2',
        'wifi_hostname_black_list': hosts.join(';'),
        'wifi_mac_black_list': macs.join(';'),
      },
      note: 'Blokir perangkat (setMacFilter daftar hitam)',
      okText: 'Daftar blokir diperbarui.',
    );
  }

  Future<List<HostNameEntry>> getHostNames() async {
    final res = await client.procGet(
      <String, String>{'cmd': 'hostNameList'},
      note: 'Nama perangkat (hostNameList)',
    );
    return parseHostNameList(res);
  }

  /// POST EDIT_HOSTNAME {mac, hostname}.
  Future<PostResult> editHostName(String mac, String hostname) {
    return post(
      <String, String>{
        'goformId': 'EDIT_HOSTNAME',
        'mac': mac,
        'hostname': hostname,
      },
      note: 'Ganti nama perangkat (EDIT_HOSTNAME)',
      okText: 'Nama perangkat diganti.',
    );
  }

  // =========================================================================
  // B7 — Hemat daya
  // =========================================================================

  Future<String?> getWifiCoverage() async {
    final res = await getCmds(
      const <String>['wifi_coverage'],
      multiData: false,
      note: 'Cakupan Wi-Fi (getWifiRange)',
    );
    final v = res['wifi_coverage']?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// POST SET_WIFI_COVERAGE {wifi_coverage}.
  Future<PostResult> setWifiCoverage(String mode) {
    return post(
      <String, String>{
        'goformId': 'SET_WIFI_COVERAGE',
        'wifi_coverage': mode,
      },
      note: 'Cakupan Wi-Fi (SET_WIFI_COVERAGE)',
      okText: 'Cakupan Wi-Fi diubah.',
    );
  }

  /// GET cmd=Sleep_interval (baca-saja — enum nilai kirim GELAP).
  Future<String?> getSleepInterval() async {
    final res = await getCmds(
      const <String>['Sleep_interval'],
      multiData: false,
      note: 'Waktu tidur Wi-Fi (getSleepMode)',
    );
    final v = res['Sleep_interval']?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  // =========================================================================
  // C9 — Mode Koneksi
  // =========================================================================

  Future<ConnectionModeInfo> getConnectionMode() async {
    final res = await getCmds(
      const <String>['ConnectionMode', 'autoConnectWhenRoaming'],
      note: 'Mode koneksi (prefill)',
    );
    return ConnectionModeInfo(res);
  }

  /// POST SET_CONNECTION_MODE {ConnectionMode, roam_setting_option}.
  /// Nilai roam "1"/"0" dari checkbox (enum SEBAGIAN di spek).
  Future<PostResult> setConnectionMode({
    required String mode,
    required bool roaming,
  }) {
    return post(
      <String, String>{
        'goformId': 'SET_CONNECTION_MODE',
        'ConnectionMode': mode,
        'roam_setting_option': roaming ? '1' : '0',
      },
      note: 'Mode koneksi (SET_CONNECTION_MODE)',
    );
  }

  // =========================================================================
  // C10 — Pilih Jaringan
  // =========================================================================

  Future<RawMap> getNetSelectPrefill() async {
    final res = await getCmds(
      const <String>[
        'current_network_mode',
        'm_netselect_save',
        'net_select_mode',
        'm_netselect_contents',
        'net_select',
        'ppp_status',
        'modem_main_state',
      ],
      note: 'Pilih jaringan (prefill)',
    );
    return RawMap(res);
  }

  /// POST SCAN_NETWORK {} lalu polling dilakukan pemanggil.
  Future<Map<String, dynamic>> scanNetwork() {
    return client.procPost(
      <String, String>{'goformId': 'SCAN_NETWORK'},
      note: 'Pindai jaringan (SCAN_NETWORK)',
    );
  }

  Future<String?> netSelectStatus() async {
    final res = await getCmds(
      const <String>['m_netselect_status'],
      multiData: false,
      note: 'Status pindai (m_netselect_status)',
    );
    return res['m_netselect_status']?.toString().trim();
  }

  Future<List<NetSelectEntry>> netSelectContents() async {
    final res = await getCmds(
      const <String>['m_netselect_contents'],
      multiData: false,
      note: 'Hasil pindai (m_netselect_contents)',
    );
    return parseNetSelectContents(res['m_netselect_contents']?.toString());
  }

  /// POST SET_NETWORK {NetworkNumber, Rat, nSubrat} — Rat hanya
  /// 0/2/7 yang diterima perangkat (validasi spek C10).
  Future<Map<String, dynamic>> setNetwork(NetSelectEntry entry) {
    return client.procPost(
      <String, String>{
        'goformId': 'SET_NETWORK',
        'NetworkNumber': entry.numeric,
        'Rat': entry.rat.toString(),
        'nSubrat': entry.subAct,
      },
      note: 'Pilih jaringan (SET_NETWORK)',
    );
  }

  Future<String?> netSelectResult() async {
    final res = await getCmds(
      const <String>['m_netselect_result'],
      multiData: false,
      note: 'Hasil pilih jaringan (m_netselect_result)',
    );
    return res['m_netselect_result']?.toString().trim();
  }

  // =========================================================================
  // C11 — APN
  // =========================================================================

  Future<ApnData> getApn() async {
    final res = await getCmds(quickSetupCmds(), note: 'APN (getApnSettings)');
    return ApnData(res);
  }

  /// POST APN_PROC_EX aksi "save" — set field mengikuti pdp_type:
  /// IP → set v4; IPv6 → set v6; IPv4v6 → keduanya + DNS manual.
  Future<PostResult> saveApn({
    required int index,
    required String profileName,
    required String wanApn,
    required String pdpType,
    required String authMode,
    required String username,
    required String password,
    required String ipv6WanApn,
    required String ipv6AuthMode,
    required String ipv6Username,
    required String ipv6Password,
    required String dnsMode,
    required String dns1,
    required String dns2,
  }) {
    final fields = <String, String>{
      'goformId': 'APN_PROC_EX',
      'apn_action': 'save',
      'apn_mode': 'manual',
      'profile_name': profileName,
      'wan_dial': '*99#',
      'pdp_type': pdpType,
      'pdp_select': 'auto',
      'index': index.toString(),
    };
    void addV4() {
      fields['wan_apn'] = wanApn;
      fields['ppp_auth_mode'] = authMode;
      fields['ppp_username'] = username;
      fields['ppp_passtmp'] = password;
    }

    void addV6() {
      fields['ipv6_wan_apn'] = ipv6WanApn;
      fields['ipv6_ppp_auth_mode'] = ipv6AuthMode;
      fields['ipv6_ppp_username'] = ipv6Username;
      fields['ipv6_ppp_passtmp'] = ipv6Password;
    }

    if (pdpType == 'IP') {
      addV4();
    } else if (pdpType == 'IPv6') {
      addV6();
    } else {
      addV4();
      addV6();
      fields['dns_mode'] = dnsMode;
      fields['prefer_dns_manual'] = dns1;
      fields['standby_dns_manual'] = dns2;
    }
    return post(fields, note: 'Simpan APN (APN_PROC_EX save)');
  }

  /// POST APN_PROC_EX aksi "set_default".
  Future<PostResult> setDefaultApn({
    required String apnMode,
    required String pdpType,
    required int index,
  }) {
    return post(
      <String, String>{
        'goformId': 'APN_PROC_EX',
        'apn_mode': apnMode,
        'apn_action': 'set_default',
        'set_default_flag': '1',
        'pdp_type': pdpType,
        'index': index.toString(),
      },
      note: 'APN default (APN_PROC_EX set_default)',
      okText: 'Profil APN dijadikan default.',
    );
  }

  /// POST APN_PROC_EX aksi "delete".
  Future<PostResult> deleteApn(int index) {
    return post(
      <String, String>{
        'goformId': 'APN_PROC_EX',
        'apn_action': 'delete',
        'apn_mode': 'manual',
        'index': index.toString(),
      },
      note: 'Hapus APN (APN_PROC_EX delete)',
      okText: 'Profil APN terhapus.',
    );
  }

  // =========================================================================
  // C12 — Manajemen Data
  // =========================================================================

  Future<DataLimitInfo> getDataLimit() async {
    final res = await getCmds(
      const <String>[
        'data_volume_limit_switch',
        'data_volume_limit_unit',
        'data_volume_limit_size',
        'data_volume_alert_percent',
        'monthly_tx_bytes',
        'monthly_rx_bytes',
        'monthly_time',
        'traffic_alined_delta',
      ],
      note: 'Manajemen data (prefill)',
    );
    return DataLimitInfo(res);
  }

  /// POST DATA_LIMIT_SETTING — field tambahan hanya bila aktif.
  /// Tanggal reset memang TIDAK ada di wire (spek C12).
  Future<PostResult> setDataLimit({
    required bool enabled,
    required String unit,
    required String size,
    required String alertPercent,
  }) {
    final fields = <String, String>{
      'goformId': 'DATA_LIMIT_SETTING',
      'data_volume_limit_switch': enabled ? '1' : '0',
    };
    if (enabled) {
      fields['data_volume_limit_unit'] = unit;
      fields['data_volume_limit_size'] = size;
      fields['data_volume_alert_percent'] = alertPercent;
    }
    return post(fields, note: 'Manajemen data (DATA_LIMIT_SETTING)');
  }

  // =========================================================================
  // D13 — Router / DHCP
  // =========================================================================

  Future<DhcpInfo> getDhcp() async {
    final res = await getCmds(
      const <String>[
        'lan_ipaddr',
        'lan_netmask',
        'mac_address',
        'dhcpEnabled',
        'dhcpStart',
        'dhcpEnd',
        'dhcpLease_hour',
      ],
      note: 'Router & DHCP (prefill)',
    );
    return DhcpInfo(res);
  }

  /// POST DHCP_SETTING utuh + dhcp_reboot_flag:1 (perangkat reboot).
  Future<PostResult> setDhcp({
    required String lanIp,
    required String lanNetmask,
    required bool serverEnabled,
    required String dhcpStart,
    required String dhcpEnd,
    required String dhcpLease,
  }) {
    final fields = <String, String>{
      'goformId': 'DHCP_SETTING',
      'lanIp': lanIp,
      'lanNetmask': lanNetmask,
      'lanDhcpType': serverEnabled ? 'SERVER' : 'DISABLE',
    };
    if (serverEnabled) {
      fields['dhcpStart'] = dhcpStart;
      fields['dhcpEnd'] = dhcpEnd;
      fields['dhcpLease'] = dhcpLease;
    }
    fields['dhcp_reboot_flag'] = '1';
    return post(fields, note: 'Router & DHCP (DHCP_SETTING)');
  }

  // =========================================================================
  // D14 — Firewall
  // =========================================================================

  Future<FwSysInfo> getFwSys() async {
    final res = await getCmds(
      const <String>['RemoteManagement', 'WANPingFilter'],
      note: 'Firewall dasar (FW_SYS prefill)',
    );
    return FwSysInfo(res);
  }

  /// POST FW_SYS {remoteManagementEnabled, pingFrmWANFilterEnabled}.
  Future<PostResult> setFwSys({
    required bool remoteManagement,
    required bool wanPingFilter,
  }) {
    return post(
      <String, String>{
        'goformId': 'FW_SYS',
        'remoteManagementEnabled': remoteManagement ? '1' : '0',
        'pingFrmWANFilterEnabled': wanPingFilter ? '1' : '0',
      },
      note: 'Firewall dasar (FW_SYS)',
    );
  }

  Future<PortFilterData> getPortFilter() async {
    final cmds = <String>['IPPortFilterEnable', 'DefaultFirewallPolicy'];
    for (var k = 0; k < 10; k++) {
      cmds.add('IPPortFilterRules_$k');
      cmds.add('IPPortFilterRulesv6_$k');
    }
    final res = await getCmds(cmds, note: 'Filter port (prefill)');
    return PortFilterData(res);
  }

  /// Saklar + kebijakan default: BASIC_SETTING. Nilai kebijakan
  /// diteruskan apa adanya dari perangkat (enum tidak terbaca).
  Future<PostResult> setPortFilterBasic({
    required bool enabled,
    required String defaultPolicy,
  }) {
    return post(
      <String, String>{
        'goformId': 'BASIC_SETTING',
        'portFilterEnabled': enabled ? '1' : '0',
        'defaultFirewallPolicy': defaultPolicy,
      },
      note: 'Filter port dasar (BASIC_SETTING)',
    );
  }

  /// Tambah rule: ADD_IP_PORT_FILETER_V4V6 (ejaan persis spek).
  Future<PostResult> addPortFilterRule({
    required String ipVersion,
    required String macAddress,
    required String dipAddress,
    required String sipAddress,
    required String dFromPort,
    required String dToPort,
    required String sFromPort,
    required String sToPort,
    required String action,
    required String protocol,
    required String comment,
  }) {
    return post(
      <String, String>{
        'goformId': 'ADD_IP_PORT_FILETER_V4V6',
        'ip_version': ipVersion,
        'mac_address': macAddress,
        'dip_address': dipAddress,
        'sip_address': sipAddress,
        'dFromPort': dFromPort,
        'dToPort': dToPort,
        'sFromPort': sFromPort,
        'sToPort': sToPort,
        'action': action,
        'protocol': protocol,
        'comment': comment,
      },
      note: 'Tambah rule filter port (ADD_IP_PORT_FILETER_V4V6)',
      okText: 'Rule filter port ditambahkan.',
    );
  }

  /// Hapus rule v4: DEL_IP_PORT_FILETER_V4V6 — delete_id = indeks
  /// 1 karakter digabung ";" + ";" penutup.
  Future<PostResult> deletePortFilterRulesV4(List<int> indices) {
    return post(
      <String, String>{
        'goformId': 'DEL_IP_PORT_FILETER_V4V6',
        'delete_id': indices.isEmpty ? '' : '${indices.join(';')};',
        'delete_id_v6': '',
      },
      note: 'Hapus rule filter port (DEL_IP_PORT_FILETER_V4V6)',
      okText: 'Rule filter port terhapus.',
    );
  }

  Future<ForwardData> getForward() async {
    final cmds = <String>['PortForwardEnable'];
    for (var k = 0; k < 10; k++) {
      cmds.add('PortForwardRules_$k');
    }
    final res = await getCmds(cmds, note: 'Port forwarding (prefill)');
    return ForwardData(res);
  }

  /// Saklar port forwarding: VIRTUAL_SERVER {PortForwardEnable}.
  Future<PostResult> setForwardEnabled(bool enabled) {
    return post(
      <String, String>{
        'goformId': 'VIRTUAL_SERVER',
        'PortForwardEnable': enabled ? '1' : '0',
      },
      note: 'Saklar port forwarding (VIRTUAL_SERVER)',
    );
  }

  /// Tambah rule: FW_FORWARD_ADD.
  Future<PostResult> addForwardRule({
    required String ipAddress,
    required String portStart,
    required String portEnd,
    required String protocol,
    required String comment,
  }) {
    return post(
      <String, String>{
        'goformId': 'FW_FORWARD_ADD',
        'ipAddress': ipAddress,
        'portStart': portStart,
        'portEnd': portEnd,
        'protocol': protocol,
        'comment': comment,
      },
      note: 'Tambah port forwarding (FW_FORWARD_ADD)',
      okText: 'Rule port forwarding ditambahkan.',
    );
  }

  /// Hapus rule: FW_FORWARD_DEL {delete_id: "i;i;"}.
  Future<PostResult> deleteForwardRules(List<int> indices) {
    return post(
      <String, String>{
        'goformId': 'FW_FORWARD_DEL',
        'delete_id': '${indices.join(';')};',
      },
      note: 'Hapus port forwarding (FW_FORWARD_DEL)',
      okText: 'Rule port forwarding terhapus.',
    );
  }

  Future<PortMapData> getPortMap() async {
    final cmds = <String>['PortMapEnable'];
    for (var k = 0; k < 10; k++) {
      cmds.add('PortMapRules_$k');
    }
    final res = await getCmds(cmds, note: 'Port mapping (prefill)');
    return PortMapData(res);
  }

  /// Saklar saja: ADD_PORT_MAP {portMapEnabled}.
  Future<PostResult> setPortMapEnabled(bool enabled) {
    return post(
      <String, String>{
        'goformId': 'ADD_PORT_MAP',
        'portMapEnabled': enabled ? '1' : '0',
      },
      note: 'Saklar port mapping (ADD_PORT_MAP)',
    );
  }

  /// Tambah rule: ADD_PORT_MAP + field rule.
  Future<PostResult> addPortMapRule({
    required String fromPort,
    required String ipAddress,
    required String toPort,
    required String protocol,
    required String comment,
  }) {
    return post(
      <String, String>{
        'goformId': 'ADD_PORT_MAP',
        'portMapEnabled': '1',
        'fromPort': fromPort,
        'ip_address': ipAddress,
        'toPort': toPort,
        'protocol': protocol,
        'comment': comment,
      },
      note: 'Tambah port mapping (ADD_PORT_MAP)',
      okText: 'Rule port mapping ditambahkan.',
    );
  }

  /// Hapus rule: DEL_PORT_MAP {delete_id: "i;i;"}.
  Future<PostResult> deletePortMapRules(List<int> indices) {
    return post(
      <String, String>{
        'goformId': 'DEL_PORT_MAP',
        'delete_id': '${indices.join(';')};',
      },
      note: 'Hapus port mapping (DEL_PORT_MAP)',
      okText: 'Rule port mapping terhapus.',
    );
  }

  Future<DmzInfo> getDmz() async {
    final res = await getCmds(
      const <String>['DMZEnable', 'DMZIPAddress'],
      note: 'DMZ (prefill)',
    );
    return DmzInfo(res);
  }

  /// POST DMZ_SETTING — DMZIPAddress hanya bila aktif.
  Future<PostResult> setDmz({required bool enabled, required String ip}) {
    final fields = <String, String>{
      'goformId': 'DMZ_SETTING',
      'DMZEnabled': enabled ? '1' : '0',
    };
    if (enabled) fields['DMZIPAddress'] = ip;
    return post(fields, note: 'DMZ (DMZ_SETTING)');
  }

  /// GET cmd=websURLFilters → satu string URL digabung ";".
  Future<List<String>> getUrlFilters() async {
    final res = await client.procGet(
      <String, String>{'cmd': 'websURLFilters'},
      note: 'Filter URL (websURLFilters)',
    );
    return splitSemi(res['websURLFilters']?.toString());
  }

  /// Tambah URL: URL_FILTER_ADD {addURLFilter}.
  Future<PostResult> addUrlFilter(String url) {
    return post(
      <String, String>{
        'goformId': 'URL_FILTER_ADD',
        'addURLFilter': url,
      },
      note: 'Tambah filter URL (URL_FILTER_ADD)',
      okText: 'URL ditambahkan ke filter.',
    );
  }

  /// Hapus URL: URL_FILTER_DELETE {url_filter_delete_id: "i;i;"}.
  Future<PostResult> deleteUrlFilters(List<int> indices) {
    return post(
      <String, String>{
        'goformId': 'URL_FILTER_DELETE',
        'url_filter_delete_id': '${indices.join(';')};',
      },
      note: 'Hapus filter URL (URL_FILTER_DELETE)',
      okText: 'URL terhapus dari filter.',
    );
  }

  Future<bool> getUpnp() async {
    final res = await getCmds(
      const <String>['upnpEnabled'],
      note: 'UPnP (prefill)',
    );
    return FwSysInfo(res).upnpEnabled;
  }

  /// POST UPNP_SETTING {upnp_setting_option}.
  Future<PostResult> setUpnp(bool enabled) {
    return post(
      <String, String>{
        'goformId': 'UPNP_SETTING',
        'upnp_setting_option': enabled ? '1' : '0',
      },
      note: 'UPnP (UPNP_SETTING)',
    );
  }

  // =========================================================================
  // D15 — SNTP / Waktu
  // =========================================================================

  static List<String> sntpCmds() {
    final cmds = <String>[
      'sntp_year',
      'sntp_month',
      'sntp_day',
      'sntp_hour',
      'sntp_minute',
      'sntp_second',
      'sntp_time_set_mode',
      'sntp_static_server0',
      'sntp_static_server1',
      'sntp_static_server2',
    ];
    for (var k = 0; k < 10; k++) {
      cmds.add('sntp_server$k');
    }
    cmds.addAll(const <String>[
      'sntp_other_server0',
      'sntp_other_server1',
      'sntp_other_server2',
      'sntp_timezone',
      'sntp_timezone_index',
      'sntp_dst_enable',
      'ppp_status',
      'sntp_process_result',
      'rj45_state',
    ]);
    return cmds;
  }

  Future<SntpInfo> getSntp() async {
    final res = await getCmds(sntpCmds(), note: 'SNTP (getSntpParams)');
    return SntpInfo(res);
  }

  /// Segarkan waktu perangkat: SNTP_Getdatastatic {} — dipanggil
  /// WebUI saat halaman dibuka & setelah simpan manual.
  Future<void> sntpRefreshTime() async {
    try {
      await client.procPost(
        <String, String>{'goformId': 'SNTP_Getdatastatic'},
        note: 'SNTP segarkan waktu (SNTP_Getdatastatic)',
      );
    } catch (_) {
      // Penyegaran waktu bersifat pelengkap; abaikan kegagalannya.
    }
  }

  /// POST SNTP — objek persis spek D15: timezone dibelah pada "_"
  /// (bagian sebelum "_" → timezone, sesudahnya → index), TANPA
  /// field detik.
  Future<PostResult> setSntp({
    required String mode,
    required List<String> servers,
    required List<String> otherServers,
    required String timezoneCombined,
    required bool dstEnabled,
    required String year,
    required String month,
    required String day,
    required String hour,
    required String minute,
  }) {
    final cut = timezoneCombined.indexOf('_');
    final tz = cut >= 0 ? timezoneCombined.substring(0, cut) : timezoneCombined;
    final tzIndex = cut >= 0 ? timezoneCombined.substring(cut + 1) : '';
    String at(List<String> l, int idx) => idx < l.length ? l[idx] : '';
    return post(
      <String, String>{
        'goformId': 'SNTP',
        'manualsettime': mode,
        'sntp_server1_ip': at(servers, 0),
        'sntp_server2_ip': at(servers, 1),
        'sntp_server3_ip': at(servers, 2),
        'sntp_other_server0': at(otherServers, 0),
        'sntp_other_server1': at(otherServers, 1),
        'sntp_other_server2': at(otherServers, 2),
        'timezone': tz,
        'sntp_timezone_index': tzIndex,
        'DaylightEnabled': dstEnabled ? '1' : '0',
        'time_year': year,
        'time_month': month,
        'time_day': day,
        'time_hour': hour,
        'time_minute': minute,
      },
      note: 'SNTP (SNTP)',
      okText: 'Pengaturan waktu tersimpan.',
      processingOk: true,
    );
  }

  // =========================================================================
  // D16 — FOTA
  // =========================================================================

  Future<FotaInfo> getFotaStatus() async {
    final res = await getCmds(
      const <String>[
        'fota_new_version_state',
        'fota_current_upgrade_state',
        'fota_package_already_download',
      ],
      note: 'FOTA status',
    );
    return FotaInfo(res);
  }

  Future<FotaAutoInfo> getFotaAuto() async {
    final res = await getCmds(
      const <String>[
        'fota_updateMode',
        'fota_updateIntervalDay',
        'fota_allowRoamingUpdate',
      ],
      note: 'FOTA pengaturan otomatis',
    );
    return FotaAutoInfo(res);
  }

  /// Periksa pembaruan: IF_UPGRADE {select_op:"check",
  /// ota_manual_check_roam_state:1}.
  Future<Map<String, dynamic>> fotaCheck() {
    return client.procPost(
      <String, String>{
        'goformId': 'IF_UPGRADE',
        'select_op': 'check',
        'ota_manual_check_roam_state': '1',
      },
      note: 'FOTA periksa (IF_UPGRADE check)',
    );
  }

  /// POST SetUpgAutoSetting {UpgMode, UpgIntervalDay, UpgRoamPermission}.
  Future<PostResult> setFotaAuto({
    required String mode,
    required String intervalDay,
    required String roamPermission,
  }) {
    return post(
      <String, String>{
        'goformId': 'SetUpgAutoSetting',
        'UpgMode': mode,
        'UpgIntervalDay': intervalDay,
        'UpgRoamPermission': roamPermission,
      },
      note: 'FOTA otomatis (SetUpgAutoSetting)',
    );
  }

  // =========================================================================
  // D17 — PIN SIM (baca-saja)
  // =========================================================================

  Future<PinInfo> getPin() async {
    final res = await getCmds(
      const <String>['pinnumber', 'pin_status', 'puknumber'],
      note: 'PIN SIM (status)',
    );
    return PinInfo(res);
  }

  // =========================================================================
  // D18 — Perangkat (daya)
  // =========================================================================

  /// POST TURN_OFF_DEVICE {} — tanpa field (spek D18, PASTI).
  Future<Map<String, dynamic>> turnOffDevice() {
    return client.procPost(
      <String, String>{'goformId': 'TURN_OFF_DEVICE'},
      note: 'Matikan perangkat (TURN_OFF_DEVICE)',
    );
  }

  /// POST RESTORE_FACTORY_SETTINGS {} — tanpa field (spek D18).
  Future<Map<String, dynamic>> restoreFactory() {
    return client.procPost(
      <String, String>{'goformId': 'RESTORE_FACTORY_SETTINGS'},
      note: 'Setel ulang pabrik (RESTORE_FACTORY_SETTINGS)',
    );
  }

  /// Info perangkat tambahan: versi SW/HW dicoba dari cmd umum
  /// keluarga firmware ini; yang kosong ditampilkan "—".
  Future<RawMap> getDeviceInfoExtra() async {
    final res = await getCmds(
      const <String>[
        'sw_version',
        'software_version',
        'firmware_version',
        'hw_version',
        'hardware_version',
        'device_model',
        'model',
        'mac_address',
        'lan_ipaddr',
        'lan_netmask',
      ],
      note: 'Info perangkat (versi)',
    );
    return RawMap(res);
  }
}
