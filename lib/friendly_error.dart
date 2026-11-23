import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Pemetaan error mentah → pesan ramah (v3.2, tahap final).
///
/// ATURAN FINAL: teks exception mentah TIDAK BOLEH mencapai UI
/// atau log Diagnostik — tidak ada nama kelas exception, errno,
/// alamat, URL, atau query string. Semua permukaan error
/// (Beranda, banner login, snackbar pengaturan, operasi SMS,
/// Sambung/Putus, log) wajib lewat dua fungsi di sini:
///
/// - [friendlyError]: kalimat lengkap Bahasa Indonesia untuk UI.
/// - [shortErrorReason]: frasa pendek untuk ringkasan log
///   (mis. "jaringan tidak terjangkau", "timeout", "HTTP 500").

bool _isTimeout(Object e) {
  if (e is TimeoutException) return true;
  return e.toString().contains('TimeoutException');
}

bool _isNetwork(Object e) {
  if (e is SocketException) return true;
  // package:http membungkus kegagalan socket sebagai
  // ClientException ("ClientException with SocketException:
  // Connection failed (OS Error: Network is unreachable, ...)").
  if (e is http.ClientException) return true;
  final t = e.toString();
  return t.contains('SocketException') ||
      t.contains('Network is unreachable') ||
      t.contains('Connection failed') ||
      t.contains('Connection refused') ||
      t.contains('Connection closed') ||
      t.contains('Connection reset') ||
      t.contains('Failed host lookup');
}

/// Kode HTTP dari ReqprocHttpException (toString-nya berbentuk
/// "ReqprocHttpException: HTTP 500") — diekstrak tanpa mengimpor
/// kelasnya agar tidak ada impor melingkar.
int? _httpCode(Object e) {
  final m = RegExp(r'HTTP (\d{3})').firstMatch(e.toString());
  return m == null ? null : int.tryParse(m.group(1)!);
}

/// Pesan error lengkap untuk UI — pendek, Bahasa Indonesia,
/// tanpa satu pun detail teknis mentah.
String friendlyError(Object e) {
  if (_isTimeout(e)) {
    return 'MiFi tidak merespons — coba lagi sebentar.';
  }
  if (_isNetwork(e)) {
    return 'Tidak terhubung ke MiFi — pastikan HP tersambung '
        'ke WiFi iPocket.';
  }
  return 'Terjadi gangguan — coba lagi.';
}

/// Alasan pendek satu frasa untuk entri log Diagnostik.
String shortErrorReason(Object e) {
  if (_isTimeout(e)) return 'timeout';
  if (_isNetwork(e)) return 'jaringan tidak terjangkau';
  final code = _httpCode(e);
  if (code != null) return 'HTTP $code';
  return 'gangguan';
}
