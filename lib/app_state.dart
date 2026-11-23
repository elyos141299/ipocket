import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'models.dart';
import 'zte_client.dart';

/// State aplikasi bersama (singleton sederhana, tanpa package tambahan).
///
/// Gateway dan password admin HANYA disimpan di memori selama aplikasi
/// berjalan — tidak pernah ditulis ke penyimpanan permanen.
class AppState extends ChangeNotifier {
  AppState._() {
    client = ZteClient(gateway: gateway, log: log);
  }

  static final AppState instance = AppState._();

  /// Gateway MiFi — default sesuai kontrak, bisa diganti di Pengaturan.
  String gateway = '192.168.0.1';

  /// Password admin — default "admin", hanya di memori.
  String adminPassword = 'admin';

  final DiagnosticsLog log = DiagnosticsLog();
  late ZteClient client;

  /// 'B' atau 'A' bila login berhasil; null bila belum/gagal.
  String? loginGeneration;
  bool busy = false;
  String? lastError;
  DeviceStatus? status;
  List<SmsMessage>? smsList;

  /// Hasil mentah sms_page_data bila strukturnya tidak bisa di-parse.
  String? smsRawFallback;

  void setGateway(String value) {
    final g = value.trim();
    gateway = g.isEmpty ? '192.168.0.1' : g;
    client = ZteClient(gateway: gateway, log: log);
    loginGeneration = null;
    status = null;
    notifyListeners();
  }

  void clearLog() {
    log.clear();
    notifyListeners();
  }

  /// Login (Gen B → fallback Gen A) lalu muat status.
  Future<void> connect() async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      loginGeneration = await client.login(adminPassword);
      if (loginGeneration == null) {
        lastError =
            'Login gagal pada kedua generasi (B dan A). Lihat tab Diagnostik.';
      } else {
        await refreshStatus();
      }
    } catch (e) {
      lastError = 'Tidak dapat menjangkau perangkat: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    try {
      final rawMap = await client.fetchStatus();
      status = DeviceStatus(rawMap);
    } catch (e) {
      lastError = 'Gagal memuat status: $e';
    }
    notifyListeners();
  }

  /// Muat SMS: sms_data_total dulu; bila gagal/tidak ada daftar pesan,
  /// fallback ke sms_page_data (di-parse bila bisa, mentah bila tidak).
  Future<void> loadSms() async {
    busy = true;
    notifyListeners();
    try {
      smsRawFallback = null;
      Map<String, dynamic>? primary;
      try {
        primary = await client.fetchSmsDataTotal();
      } catch (_) {
        primary = null; // Sudah tercatat di log — lanjut ke fallback.
      }
      final msgs = primary?['messages'];
      if (msgs is List) {
        smsList = msgs
            .whereType<Map<String, dynamic>>()
            .map(SmsMessage.fromJson)
            .toList();
      } else {
        final res2 = await client.fetchSmsPageData();
        final m2 = res2['messages'];
        if (m2 is List) {
          smsList = m2
              .whereType<Map<String, dynamic>>()
              .map(SmsMessage.fromJson)
              .toList();
        } else {
          smsList = null;
          smsRawFallback = const JsonEncoder.withIndent('  ').convert(res2);
        }
      }
    } catch (e) {
      lastError = 'Gagal memuat SMS: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Jalankan urutan tes lengkap dari klien, lalu segarkan status.
  Future<void> runFullTest() async {
    busy = true;
    notifyListeners();
    try {
      await client.runFullTest(adminPassword);
      await refreshStatus();
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
