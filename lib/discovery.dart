import 'package:http/http.dart' as http;

import 'reqproc_client.dart';

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

/// Penemuan API Lanjutan (v0.3).
///
/// Hasil v0.2 di perangkat asli: index.html terbaca (WebUI RequireJS +
/// Knockout), tapi satu-satunya file JS yang tertangkap dari atribut
/// src=/href= adalah library generik (require-jquery.js) — modul
/// aplikasi dimuat DINAMIS oleh RequireJS sehingga belum terjangkau.
/// Mode lanjutan ini memburunya lewat tiga jalur:
///
/// 1. Petakan semua tag `<script ...>` di /index.html secara verbatim
///    (src, data-main, dll) + 1500 karakter terakhir HTML.
/// 2. Coba "kamus modul": path JS yang umum dipakai WebUI sekelas ini;
///    status HTTP tiap path tercatat (404 pun informasi layout).
/// 3. Crawl tingkat dua: ekstrak nama modul dari require([...]) /
///    define([...]) dan nilai `paths:` dari require.config pada JS
///    yang berhasil dibaca, susun URL kandidat, unduh & pindai lagi.
///
/// Setiap file yang terbaca dipindai dengan regex endpoint yang sama
/// seperti v0.2, DITAMBAH pindaian kata kunci khusus (goform,
/// cmd_process, .cgi, proc_get, proc_post) dengan konteks ±100
/// karakter. Semua READ-ONLY, tercatat ke DiagnosticsLog yang sama.
class ApiDiscoveryAdvanced extends ApiDiscovery {
  ApiDiscoveryAdvanced({required super.gateway, required super.log});

  /// Path modul yang umum pada WebUI RequireJS — dicoba satu per satu.
  static const List<String> _moduleDictionary = <String>[
    'js/main.js',
    'js/config.js',
    'js/service.js',
    'js/api.js',
    'js/app.js',
    'js/index.js',
    'js/lib/service.js',
    'js/modules/service.js',
    'js/config/config.js',
  ];

  /// Kata kunci khusus: jejak API perangkat (sisa goform maupun pola
  /// CGI/proc lain) yang dicari verbatim di kode JS.
  static const List<String> _specialKeywords = <String>[
    'goform',
    'cmd_process',
    '.cgi',
    'proc_get',
    'proc_post',
  ];

  static final RegExp _scriptTagRe = RegExp(
    r'<script[^>]*>',
    caseSensitive: false,
  );

  static final List<RegExp> _requireArrayRes = <RegExp>[
    RegExp(r'(?:require|define)\s*\(\s*\[([^\]]*)\]'),
    RegExp(r'''define\s*\(\s*["'][^"']*["']\s*,\s*\[([^\]]*)\]'''),
  ];

  static final RegExp _pathsBlockRe = RegExp(r'paths\s*:\s*\{([^}]*)\}');

  static final RegExp _pathPairRe = RegExp(
    r'''["']([^"']+)["']\s*:\s*["']([^"']+)["']''',
  );

  /// Nama modul/path yang aman disusun jadi URL (huruf, angka, dan
  /// pemisah path saja — membuang string aneh dari array dependensi).
  static final RegExp _safeRefRe = RegExp(r'^[A-Za-z0-9_\-./]+$');

  /// Pindai satu file JS untuk penemuan lanjutan: kandidat endpoint
  /// (regex yang sama dengan v0.2) + hitungan & konteks kata kunci
  /// khusus. Kandidat digabung ke [globalCandidates]. Mengembalikan
  /// jumlah kemunculan "goform" (case-insensitive) di file ini.
  int _scanJsAdvanced(
    String name,
    String js,
    Set<String> globalCandidates,
  ) {
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

    var goformHits = 0;
    final counts = <String, int>{};
    final snippets = <String>[];
    for (final kw in _specialKeywords) {
      final re = RegExp(RegExp.escape(kw), caseSensitive: false);
      final matches = re.allMatches(js).toList();
      counts[kw] = matches.length;
      if (kw == 'goform') goformHits = matches.length;
      for (final m in matches) {
        if (snippets.length >= 40) break;
        final start = m.start - 100 < 0 ? 0 : m.start - 100;
        final end = m.end + 100 > js.length ? js.length : m.end + 100;
        snippets.add(
          '[$kw] ${js.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim()}',
        );
      }
    }
    log.addNote(
      'Kata kunci khusus di $name — '
      '${_specialKeywords.map((k) => '$k: ${counts[k]}').join(', ')}',
    );
    if (snippets.isNotEmpty) {
      _logChunks(
        'Konteks kata kunci khusus dari $name (${snippets.length}):',
        snippets.join('\n---\n'),
      );
    }
    return goformHits;
  }

  /// Terkesan file lokal? Bukan URL absolut dan bukan library pihak
  /// ketiga (folder "3rd" — sudah terbukti generik di v0.2).
  static bool _looksLocal(String ref) {
    final low = ref.toLowerCase();
    return !low.startsWith('http://') &&
        !low.startsWith('https://') &&
        !low.startsWith('//') &&
        !low.contains('3rd');
  }

  /// Susun URL kandidat dari NAMA modul require/define:
  /// `<base>/js/<nama>.js` (kecuali nama sudah berawalan js/).
  String _moduleUrl(String name) {
    var n = name;
    if (n.startsWith('./')) n = n.substring(2);
    if (n.startsWith('/')) n = n.substring(1);
    final withExt = n.endsWith('.js') ? n : '$n.js';
    return withExt.startsWith('js/') ? '$_base/$withExt' : '$_base/js/$withExt';
  }

  /// Susun URL kandidat dari NILAI paths: require.config:
  /// `<base>/<path>.js` (path dianggap relatif ke root WebUI).
  String _pathUrl(String path) {
    var p = path;
    if (p.startsWith('./')) p = p.substring(2);
    if (p.startsWith('/')) p = p.substring(1);
    return p.endsWith('.js') ? '$_base/$p' : '$_base/$p.js';
  }

  /// Jalankan seluruh urutan penemuan lanjutan ke log diagnostik.
  Future<void> runAdvanced() async {
    log.addNote('=== PENEMUAN API LANJUTAN DIMULAI ===');

    final tried = <String, int?>{}; // URL → status HTTP (null = gagal)
    final globalCandidates = <String>{};
    var goformCount = 0;
    final jsBodies = <String>[]; // isi JS status 200, bahan crawl

    Future<http.Response?> fetch(
      String url,
      String note, {
      Duration timeout = const Duration(seconds: 10),
    }) async {
      final res = await _getRaw(Uri.parse(url), timeout: timeout, note: note);
      tried[url] = res?.statusCode;
      return res;
    }

    // Langkah 1: /index.html — tag <script> verbatim + ekor HTML.
    final indexUrl = '$_base/index.html';
    final indexRes = await fetch(
      indexUrl,
      'Penemuan lanjutan: halaman /index.html',
    );
    if (indexRes != null && indexRes.statusCode == 200) {
      final html = indexRes.body;
      goformCount +=
          RegExp('goform', caseSensitive: false).allMatches(html).length;
      final tags =
          _scriptTagRe.allMatches(html).map((m) => m.group(0)!).toList();
      if (tags.isEmpty) {
        log.addNote('Tag <script> di /index.html: (tidak ditemukan)');
      } else {
        _logChunks(
          'Tag <script> di /index.html (${tags.length}):',
          tags.join('\n'),
        );
      }
      if (html.isNotEmpty) {
        final tail =
            html.length <= 1500 ? html : html.substring(html.length - 1500);
        log.addNote('1500 karakter terakhir /index.html:\n$tail');
      }
    } else {
      log.addNote(
        'Penemuan lanjutan: /index.html tidak terbaca '
        '(status ${indexRes?.statusCode}) — lanjut ke kamus modul.',
      );
    }

    // Langkah 2: kamus modul — status tiap path tercatat apa adanya.
    for (final path in _moduleDictionary) {
      final url = '$_base/$path';
      final res = await fetch(url, 'Penemuan lanjutan: kamus modul $path');
      if (res != null && res.statusCode == 200) {
        jsBodies.add(res.body);
        goformCount += _scanJsAdvanced(
          ApiDiscovery._fileName(url),
          res.body,
          globalCandidates,
        );
      }
    }

    // Langkah 3: crawl tingkat dua dari JS yang berhasil dibaca.
    final moduleNames = <String>{};
    final pathValues = <String>{};
    for (final body in jsBodies) {
      for (final re in _requireArrayRes) {
        for (final m in re.allMatches(body)) {
          final inner = m.group(1) ?? '';
          for (final lm in ApiDiscovery._literalRe.allMatches(inner)) {
            final s = (lm.group(1) ?? lm.group(2) ?? '').trim();
            if (s.isNotEmpty) moduleNames.add(s);
          }
        }
      }
      for (final m in _pathsBlockRe.allMatches(body)) {
        final inner = m.group(1) ?? '';
        for (final pm in _pathPairRe.allMatches(inner)) {
          final v = (pm.group(2) ?? '').trim();
          if (v.isNotEmpty) pathValues.add(v);
        }
      }
    }
    if (moduleNames.isEmpty) {
      log.addNote('Nama modul dari require/define: (tidak ditemukan)');
    } else {
      _logChunks(
        'Nama modul dari require/define (${moduleNames.length}):',
        (moduleNames.toList()..sort()).join('\n'),
      );
    }
    if (pathValues.isEmpty) {
      log.addNote('Nilai paths: dari require.config: (tidak ditemukan)');
    } else {
      _logChunks(
        'Nilai paths: dari require.config (${pathValues.length}):',
        (pathValues.toList()..sort()).join('\n'),
      );
    }

    final crawlUrls = <String>[];
    void addCrawl(String url) {
      if (!crawlUrls.contains(url) && !tried.containsKey(url)) {
        crawlUrls.add(url);
      }
    }

    for (final raw in moduleNames) {
      // Sintaks plugin RequireJS ("text!tpl/x") → ambil file aslinya.
      final name = (raw.contains('!') ? raw.split('!').last : raw).trim();
      if (name.isEmpty || !_looksLocal(name) || !_safeRefRe.hasMatch(name)) {
        continue;
      }
      addCrawl(_moduleUrl(name));
    }
    for (final raw in pathValues) {
      final path = raw.trim();
      if (path.isEmpty || !_looksLocal(path) || !_safeRefRe.hasMatch(path)) {
        continue;
      }
      addCrawl(_pathUrl(path));
    }

    final extra = crawlUrls.take(12).toList();
    if (crawlUrls.length > extra.length) {
      log.addNote(
        'Hanya ${extra.length} URL crawl pertama yang dibaca '
        '(total kandidat ${crawlUrls.length}).',
      );
    }
    for (final url in extra) {
      final res = await fetch(
        url,
        'Penemuan lanjutan: crawl modul',
        timeout: const Duration(seconds: 15),
      );
      if (res != null && res.statusCode == 200) {
        goformCount += _scanJsAdvanced(
          ApiDiscovery._fileName(url),
          res.body,
          globalCandidates,
        );
      }
    }

    // Langkah 4: ringkasan akhir.
    _logChunks(
      'Semua URL yang dicoba (${tried.length}):',
      tried.entries
          .map((e) => '${e.key} → ${e.value ?? 'gagal jaringan'}')
          .join('\n'),
    );
    log.addNote(
      '=== PENEMUAN API LANJUTAN SELESAI ===\n'
      'Ringkasan: ${tried.length} URL dicoba, '
      '${globalCandidates.length} endpoint kandidat unik, '
      '$goformCount kemunculan "goform" di semua file yang terbaca.',
    );
  }
}

/// Penemuan API Final (v0.4).
///
/// js/main.js yang terbaca di v0.3 membocorkan peta modul RequireJS
/// WebUI ini: modul "service" dipetakan ke file `com`, fitur SIM/SMS
/// ke `sim_device`, jaringan ke `net`, WiFi ke `wifi` — dan main.js
/// sendiri memuat `DEVICE + "/set"` serta `"set service lib"`. Jadi
/// file layanan sebenarnya hampir pasti enam file ini:
///
///   js/com.js, js/set.js, js/lib.js, js/sim_device.js, js/net.js,
///   js/wifi.js
///
/// Tahap final mengambil persis keenamnya. File yang terbaca dipindai
/// kandidat endpoint-nya (regex yang sama), DITAMBAH pindaian konteks
/// kata kunci pemanggilan API (ajax, cgi, api, goform, cmd, method,
/// action, url) ±120 karakter — di sinilah URL API asli harusnya
/// muncul verbatim. Khusus js/set.js (file konstanta; isinya
/// menentukan awalan path API): bila kecil (< 12000 byte), isinya
/// dicatat UTUH ke log. Semua READ-ONLY.
class ApiDiscoveryFinal extends ApiDiscoveryAdvanced {
  ApiDiscoveryFinal({required super.gateway, required super.log});

  /// Enam file layanan hasil petunjuk require.config di js/main.js.
  static const List<String> _targetFiles = <String>[
    'js/com.js',
    'js/set.js',
    'js/lib.js',
    'js/sim_device.js',
    'js/net.js',
    'js/wifi.js',
  ];

  /// Kata kunci pemanggilan API: konteks di sekitar kemunculannya
  /// memperlihatkan URL/metode yang benar-benar dipakai WebUI.
  static const List<String> _contextKeywords = <String>[
    'ajax',
    'cgi',
    'api',
    'goform',
    'cmd',
    'method',
    'action',
    'url',
  ];

  /// Pindai konteks kata kunci di satu file: satu catatan hitungan
  /// untuk semua kata, lalu potongan ±120 karakter per kata yang
  /// ditemukan (maks [budgetPerWord] kemunculan per kata).
  void _scanKeywordContexts(
    String name,
    String js, {
    required int budgetPerWord,
  }) {
    final counts = <String, int>{};
    final perWord = <String, List<String>>{};
    for (final kw in _contextKeywords) {
      final re = RegExp(RegExp.escape(kw), caseSensitive: false);
      final matches = re.allMatches(js).toList();
      counts[kw] = matches.length;
      if (matches.isEmpty) continue;
      final snippets = <String>[];
      for (final m in matches) {
        if (snippets.length >= budgetPerWord) break;
        final start = m.start - 120 < 0 ? 0 : m.start - 120;
        final end = m.end + 120 > js.length ? js.length : m.end + 120;
        snippets.add(
          js.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim(),
        );
      }
      perWord[kw] = snippets;
    }
    log.addNote(
      'Kata kunci konteks di $name — '
      '${_contextKeywords.map((k) => '$k: ${counts[k]}').join(', ')}',
    );
    perWord.forEach((kw, snippets) {
      _logChunks(
        'Konteks "$kw" di $name (${snippets.length}):',
        snippets.join('\n---\n'),
      );
    });
  }

  /// Jalankan penemuan final: ambil enam file layanan, pindai.
  Future<void> runFinal() async {
    log.addNote('=== PENEMUAN API FINAL DIMULAI ===');

    final statuses = <String, int?>{}; // path → status (null = gagal)
    final globalCandidates = <String>{};

    for (final path in _targetFiles) {
      final url = '$_base/$path';
      final name = ApiDiscovery._fileName(url);
      final res = await _getRaw(
        Uri.parse(url),
        timeout: const Duration(seconds: 15),
        note: 'Penemuan final: file $path',
      );
      statuses[path] = res?.statusCode;
      if (res == null) continue;
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

      // com.js & lib.js = lapisan layanan inti: anggaran konteks
      // per kata lebih besar (40) dibanding file fitur (25).
      final budget = (name == 'com.js' || name == 'lib.js') ? 40 : 25;
      _scanKeywordContexts(name, js, budgetPerWord: budget);

      // set.js = konstanta awalan path API — catat utuh bila kecil.
      if (path == 'js/set.js' && res.bodyBytes.length < 12000) {
        _logChunks(
          'Isi lengkap set.js (${res.bodyBytes.length} byte):',
          js,
        );
      }
    }

    log.addNote(
      '=== PENEMUAN API FINAL SELESAI ===\n'
      'Ringkasan: '
      '${_targetFiles.map((p) => '$p → ${statuses[p] ?? 'gagal jaringan'}').join(', ')}; '
      '${globalCandidates.length} endpoint kandidat unik dari tahap ini.',
    );
  }
}

/// Penemuan Terarah JS (v1.3; diperluas v1.4).
///
/// Penemuan Final (v0.4) hanya mencatat SAMPEL tiap file JS:
/// konteks kata kunci umum ±120 karakter dan isi terpotong
/// ±2000 karakter per entri — terlalu dangkal untuk memastikan
/// nama field wire gelombang pengaturan berikutnya (simpan WiFi,
/// filter MAC, DHCP, DMZ, reboot, SNTP, pengaturan SMS, dll).
///
/// Mode terarah ini mengunduh PENUH empat file —
/// js/wifi.js, js/net.js, js/sim_device.js, js/lib.js — dan
/// untuk daftar kata kunci SPESIFIK per file mencatat konteks
/// ±1200 karakter di sekitar SETIAP kemunculan ke log, dipecah
/// entri ≤3500 karakter TANPA membuang isi konteks (jendela
/// yang tumpang tindih digabung, jadi tidak ada teks dobel
/// maupun terpotong). Tiap entri berpenanda file + kata kunci
/// + nomor segmen/potongan. Pencarian case-insensitive; ejaan
/// kata kunci yang hanya beda huruf besar/kecil (DMZ/dmz,
/// SNTP/sntp, traffic/Traffic) dicari sekali. File yang gagal
/// diunduh atau 404 dicatat apa adanya. Semua READ-ONLY.
///
/// v1.4 menambahkan js/lib.js dengan konteks LEBIH LEBAR
/// (±2000 karakter): buruan terakhir definisi
/// getCurrentTimeString/encodeMessage/escapeMessage — tiga
/// fungsi pembentuk wire SEND_SMS WebUI yang TIDAK ada di
/// wifi/net/sim_device.js (hanya call-site) dan menjadi
/// tersangka utama kegagalan kirim SMS di perangkat asli
/// (addendum API-CONTRACT 14:37).
class ApiDiscoveryTargeted extends ApiDiscovery {
  ApiDiscoveryTargeted({required super.gateway, required super.log});

  /// File target → kata kunci yang diburu di dalamnya.
  static const Map<String, List<String>> _targets =
      <String, List<String>>{
    'js/wifi.js': <String>[
      'goformId',
      'setWifiBasic',
      'getWifiBasic',
      'MAX_Access',
      'mac',
      'MacFilter',
      'block',
      'SET_WIFI',
      'channel',
      'Country',
    ],
    'js/net.js': <String>[
      'DHCP_SETTING',
      'lanDhcp',
      'FILTER',
      'DMZ',
      'dmz',
      'REBOOT',
      'restart',
      'TURN_OFF',
      'FOTA',
      'SNTP',
      'sntp',
      'traffic',
      'Traffic',
    ],
    'js/sim_device.js': <String>[
      'sms',
      'SmsSetting',
      'save_time',
      'MessageCenter',
      'status_save',
    ],
    // v1.4: buruan definisi fungsi pembentuk wire SMS.
    'js/lib.js': <String>[
      'getCurrentTimeString',
      'encodeMessage',
      'escapeMessage',
    ],
  };

  /// Setengah lebar jendela konteks di sekitar kemunculan.
  static const int _contextRadius = 1200;

  /// Radius khusus js/lib.js (v1.4): definisi fungsi yang
  /// diburu panjang, jadi jendela konteksnya ±2000 karakter.
  static const int _contextRadiusWide = 2000;

  /// Batas ukuran satu entri log untuk mode ini.
  static const int _entryLimit = 3500;

  /// Catat [text] ke log dalam potongan ≤[_entryLimit] karakter,
  /// diusahakan putus di batas baris, dengan penanda "potongan N"
  /// pada [title]. Isi TIDAK pernah dibuang — hanya dipecah
  /// antar-entri (berbeda dari _truncate klien yang memotong).
  void _logTargeted(String title, String text) {
    if (text.length <= _entryLimit) {
      log.addNote('$title\n$text');
      return;
    }
    var part = 1;
    var rest = text;
    while (rest.isNotEmpty) {
      var chunk = rest;
      var advance = rest.length;
      if (rest.length > _entryLimit) {
        var cut = rest.lastIndexOf('\n', _entryLimit);
        if (cut <= 0) cut = _entryLimit;
        chunk = rest.substring(0, cut);
        advance = cut + (rest[cut] == '\n' ? 1 : 0);
      }
      log.addNote('$title (potongan $part)\n$chunk');
      part++;
      rest = rest.substring(advance);
    }
  }

  /// Cari semua kemunculan [keyword] (case-insensitive) di [js],
  /// gabung jendela konteks ±[radius] yang tumpang tindih
  /// menjadi segmen, lalu catat tiap segmen ke log dengan
  /// penanda file + kata kunci + nomor segmen.
  void _scanTargeted(
    String file,
    String keyword,
    String js, {
    int radius = _contextRadius,
  }) {
    final re = RegExp(RegExp.escape(keyword), caseSensitive: false);
    final matches = re.allMatches(js).toList();
    if (matches.isEmpty) {
      log.addNote('[$file] kata kunci "$keyword": 0 kemunculan.');
      return;
    }
    // Jendela konteks tiap kemunculan: [awal, akhir, jumlah
    // kemunculan di dalam segmen]. Digabung bila tumpang tindih.
    final windows = <List<int>>[];
    for (final m in matches) {
      final start = m.start - radius < 0 ? 0 : m.start - radius;
      final end =
          m.end + radius > js.length ? js.length : m.end + radius;
      if (windows.isNotEmpty && start <= windows.last[1]) {
        if (end > windows.last[1]) windows.last[1] = end;
        windows.last[2]++;
      } else {
        windows.add(<int>[start, end, 1]);
      }
    }
    log.addNote(
      '[$file] kata kunci "$keyword": ${matches.length} kemunculan, '
      '${windows.length} segmen konteks.',
    );
    var seg = 0;
    for (final w in windows) {
      seg++;
      _logTargeted(
        '[$file] kata kunci "$keyword" — segmen $seg/${windows.length} '
        '(isi segmen: ${w[2]} kemunculan, posisi ${w[0]}–${w[1]})',
        js.substring(w[0], w[1]),
      );
    }
  }

  /// Jalankan penemuan terarah: unduh penuh empat file,
  /// pindai kata kunci spesifik per file (js/lib.js memakai
  /// radius konteks lebar ±2000, sisanya ±1200).
  Future<void> runTargeted() async {
    log.addNote('=== PENEMUAN TERARAH JS DIMULAI ===');
    for (final entry in _targets.entries) {
      final path = entry.key;
      final url = '$_base/$path';
      final name = ApiDiscovery._fileName(url);
      final res = await _getRaw(
        Uri.parse(url),
        timeout: const Duration(seconds: 20),
        note: 'Penemuan terarah: file $path',
      );
      if (res == null) {
        log.addNote(
          'File $name: GAGAL diunduh (jaringan) — dilewati.',
        );
        continue;
      }
      if (res.statusCode != 200) {
        log.addNote(
          'File $name: HTTP ${res.statusCode} — tidak ditemukan/'
          'gagal, dilewati.',
        );
        continue;
      }
      final js = res.body;
      final radius =
          path == 'js/lib.js' ? _contextRadiusWide : _contextRadius;
      log.addNote(
        'File $name terbaca penuh: ${res.bodyBytes.length} byte. '
        'Memindai kata kunci: ${entry.value.join(', ')} '
        '(case-insensitive, ejaan ganda dicari sekali; konteks '
        '±$radius karakter per kemunculan).',
      );
      final seen = <String>{};
      for (final kw in entry.value) {
        if (!seen.add(kw.toLowerCase())) continue;
        _scanTargeted(name, kw, js, radius: radius);
      }
    }
    log.addNote('=== PENEMUAN TERARAH JS SELESAI ===');
  }
}
