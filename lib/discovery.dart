import 'package:http/http.dart' as http;

import 'zte_client.dart';

/// Mode Penemuan API (v0.2).
///
/// Latar: tes perangkat asli membuktikan firmware iPocket ini menjawab
/// HTTP 404 untuk semua path /goform/* — API aslinya bukan goform
/// klasik. Mode ini menemukan API sebenarnya dengan membaca kode WebUI
/// dari perangkat itu sendiri:
///
/// 1. Ambil `/` dan `/index.html`, ekstrak daftar file `.js` dari
///    atribut `src=`/`href=`.
/// 2. Unduh tiap file JS (maks 12) dan pindai string literal yang
///    tampak seperti path endpoint.
/// 3. Pindai juga konteks pemanggilan AJAX/fetch di sekitar penanda
///    seperti `$.ajax`, `fetch(`, `XMLHttpRequest`.
///
/// Semua READ-ONLY (hanya GET file statis) dan semua langkah tercatat
/// ke [DiagnosticsLog] yang sama dengan Tes Lengkap.
class ApiDiscovery {
  ApiDiscovery({required this.gateway, required this.log});

  /// Alamat gateway tanpa skema, mis. "192.168.0.1".
  final String gateway;
  final DiagnosticsLog log;

  final http.Client _http = http.Client();

  String get _base => 'http://$gateway';

  Map<String, String> get _headers => <String, String>{'Referer': '$_base/'};

  /// Batas potong isi per entri log — sama seperti klien ZTE (±2000).
  static String _truncate(String s, [int max = 2000]) => s.length <= max
      ? s
      : '${s.substring(0, max)}\n…(dipotong, total ${s.length} karakter)';

  /// Kata kunci penanda kandidat endpoint (sesuai spesifikasi v0.2).
  static const List<String> _endpointKeywords = <String>[
    'api',
    'goform',
    'cgi',
    'proc',
    'form',
    'cmd',
    'json',
    'data',
    'get',
    'set',
    'login',
    'sms',
    'status',
  ];

  /// Penanda pola pemanggilan HTTP di kode JS.
  static const List<String> _callMarkers = <String>[
    'url:',
    r'$.ajax',
    r'$.get',
    r'$.post',
    'fetch(',
    'XMLHttpRequest',
  ];

  static final RegExp _attrRe = RegExp(
    r'''(?:src|href)\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  static final RegExp _literalRe = RegExp(
    r'"([^"\r\n]{1,400})"' + r"|'([^'\r\n]{1,400})'",
  );

  /// GET mentah: tidak melempar pada status non-200; selalu tercatat
  /// ke log (status + ukuran di catatan, isi dipotong ±2000 karakter).
  /// Mengembalikan null hanya bila request gagal total (jaringan).
  Future<http.Response?> _getRaw(
    Uri uri, {
    required Duration timeout,
    required String note,
  }) async {
    try {
      final res = await _http.get(uri, headers: _headers).timeout(timeout);
      log.add(DiagEntry(
        time: DateTime.now(),
        method: 'GET',
        url: uri.toString(),
        statusCode: res.statusCode,
        body: _truncate(res.body),
        note: '$note — ${res.bodyBytes.length} byte',
      ));
      return res;
    } catch (e) {
      log.add(DiagEntry(
        time: DateTime.now(),
        method: 'GET',
        url: uri.toString(),
        statusCode: null,
        body: 'ERROR: $e',
        note: note,
      ));
      return null;
    }
  }

  /// Catat teks panjang ke log dalam potongan ±1900 karakter per entri,
  /// diusahakan putus di batas baris. Entri pertama dan seterusnya
  /// memakai [title] yang sama (lanjutan diberi penanda "bagian N").
  void _logChunks(String title, String text) {
    const limit = 1900;
    if (text.length <= limit) {
      log.addNote('$title\n$text');
      return;
    }
    var part = 1;
    var rest = text;
    while (rest.isNotEmpty) {
      var chunk = rest;
      var advance = rest.length;
      if (rest.length > limit) {
        var cut = rest.lastIndexOf('\n', limit);
        if (cut <= 0) cut = limit;
        chunk = rest.substring(0, cut);
        advance = cut + (rest[cut] == '\n' ? 1 : 0);
      }
      log.addNote('$title (bagian $part)\n$chunk');
      part++;
      rest = rest.substring(advance);
    }
  }

  /// Ekstrak URL file `.js` dari atribut src=/href= sebuah HTML,
  /// di-resolve terhadap URL halamannya. Hasil unik, urutan temuan.
  List<String> _extractJsUrls(Uri pageUri, String html) {
    final out = <String>[];
    for (final m in _attrRe.allMatches(html)) {
      final ref = m.group(1)?.trim() ?? '';
      if (ref.isEmpty) continue;
      final clean = ref.split('?').first.split('#').first;
      if (!clean.toLowerCase().endsWith('.js')) continue;
      final resolved = pageUri.resolve(ref);
      if (resolved.scheme != 'http' && resolved.scheme != 'https') continue;
      final url = resolved.toString();
      if (!out.contains(url)) out.add(url);
    }
    return out;
  }

  /// Kumpulkan string literal unik yang tampak seperti path endpoint:
  /// mengandung "/" dan salah satu kata kunci. Urut abjad, maks 300.
  List<String> _scanEndpoints(String js) {
    final found = <String>{};
    for (final m in _literalRe.allMatches(js)) {
      final s = m.group(1) ?? m.group(2) ?? '';
      if (!s.contains('/')) continue;
      final low = s.toLowerCase();
      if (_endpointKeywords.any(low.contains)) {
        found.add(s);
        if (found.length >= 300) break;
      }
    }
    return found.toList()..sort();
  }

  /// Ambil potongan teks ±80 karakter di sekitar kemunculan penanda
  /// pemanggilan (url:, $.ajax, fetch(, …), urut posisi di file.
  /// Paling banyak [budget] potongan.
  List<String> _scanContexts(String js, int budget) {
    final snippets = <String>[];
    var from = 0;
    while (snippets.length < budget) {
      var bestIdx = -1;
      var bestMarker = '';
      for (final marker in _callMarkers) {
        final i = js.indexOf(marker, from);
        if (i >= 0 && (bestIdx < 0 || i < bestIdx)) {
          bestIdx = i;
          bestMarker = marker;
        }
      }
      if (bestIdx < 0) break;
      final start = bestIdx - 80 < 0 ? 0 : bestIdx - 80;
      final endRaw = bestIdx + bestMarker.length + 80;
      final end = endRaw > js.length ? js.length : endRaw;
      snippets.add(
        js.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim(),
      );
      from = bestIdx + bestMarker.length;
    }
    return snippets;
  }

  static String _fileName(String url) {
    final segments = Uri.parse(url).pathSegments;
    return segments.isEmpty ? url : segments.last;
  }

  /// Jalankan seluruh urutan penemuan. Semua hasil ke log diagnostik.
  Future<void> run() async {
    log.addNote('=== PENEMUAN API DIMULAI ===');

    // Langkah 1: ambil halaman utama, kumpulkan daftar file JS.
    final jsUrls = <String>[];
    String? firstHtml;
    for (final path in <String>['/', '/index.html']) {
      final uri = Uri.parse('$_base$path');
      final res = await _getRaw(
        uri,
        timeout: const Duration(seconds: 10),
        note: 'Penemuan API: halaman $path',
      );
      if (res == null) continue;
      firstHtml ??= res.body;
      if (res.statusCode == 200) {
        for (final url in _extractJsUrls(uri, res.body)) {
          if (!jsUrls.contains(url)) jsUrls.add(url);
        }
      }
    }

    if (jsUrls.isEmpty) {
      log.addNote(
        'Tidak ada file JS ditemukan dari HTML — tidak ada atribut '
        'src=/href= berakhiran .js pada halaman yang berhasil diambil.',
      );
      if (firstHtml != null && firstHtml.isNotEmpty) {
        final head = firstHtml.length <= 500
            ? firstHtml
            : firstHtml.substring(0, 500);
        log.addNote('500 karakter pertama HTML:\n$head');
      }
    } else {
      _logChunks(
        'File JS ditemukan (${jsUrls.length}):',
        jsUrls.join('\n'),
      );
    }

    // Langkah 2 & 3: unduh dan pindai tiap file JS (maks 12).
    final targets = jsUrls.take(12).toList();
    if (jsUrls.length > targets.length) {
      log.addNote(
        'Hanya ${targets.length} file pertama yang dibaca '
        '(total ditemukan ${jsUrls.length}).',
      );
    }
    var filesRead = 0;
    var totalBytes = 0;
    final globalCandidates = <String>{};
    var contextsLeft = 40;
    final contextSnippets = <String>[];

    for (final url in targets) {
      final name = _fileName(url);
      final res = await _getRaw(
        Uri.parse(url),
        timeout: const Duration(seconds: 15),
        note: 'Penemuan API: file JS $name',
      );
      if (res == null) continue;
      filesRead++;
      totalBytes += res.bodyBytes.length;
      if (res.statusCode != 200) {
        log.addNote('File $name: status HTTP ${res.statusCode}, dilewati.');
        continue;
      }
      final js = res.body;

      final candidates = _scanEndpoints(js);
      globalCandidates.addAll(candidates);
      if (candidates.isEmpty) {
        log.addNote('Endpoint kandidat dari $name: (tidak ada)');
      } else {
        _logChunks(
          'Endpoint kandidat dari $name (${candidates.length}):',
          candidates.join('\n'),
        );
      }

      if (contextsLeft > 0) {
        final snippets = _scanContexts(js, contextsLeft);
        contextsLeft -= snippets.length;
        contextSnippets.addAll(snippets.map((s) => '[$name] $s'));
      }
    }

    if (contextSnippets.isEmpty) {
      log.addNote(
        'Konteks panggilan: (tidak ditemukan penanda url:/ajax/fetch '
        'di file yang terbaca)',
      );
    } else {
      _logChunks(
        'Konteks panggilan (${contextSnippets.length}):',
        contextSnippets.join('\n---\n'),
      );
    }

    // Langkah 5: ringkasan.
    log.addNote(
      '=== PENEMUAN API SELESAI ===\n'
      'Ringkasan: $filesRead file JS terbaca, total $totalBytes byte, '
      '${globalCandidates.length} endpoint kandidat unik.',
    );
  }
}
