import 'package:flutter/material.dart';

/// Token desain terpusat iPocket.
///
/// v4.0 — DESIGN SYSTEM PREMIUM (keputusan user: kebebasan
/// penuh berkreasi, rasa template dashboard modern gratis —
/// fintech / Material You / Linear / Ookla modern): navy pekat
/// bergradasi halus, kartu GLASSY (gradasi permukaan halus +
/// border tipis terang + bayangan lembut), skala spacing &
/// radius seragam, tipografi berjenjang tegas dengan angka
/// tabular untuk statistik & gauge. Identitas tetap: Logo A +
/// gradasi cyan → biru → ungu, tema gelap.
///
/// Riwayat: v3.0 struktur ala tpMiFi + palet Ookla (pink Advan
/// ditinggalkan total di UI). Fitur & perilaku TIDAK berubah
/// di v4.0 — hanya kulit & tata letak visual.
class AppColors {
  AppColors._();

  /// Latar utama aplikasi (navy pekat, diperdalam di v4.0).
  static const Color bg = Color(0xFF05081A);

  /// Latar header / ujung gradasi terang.
  static const Color header = Color(0xFF0C1338);

  /// Latar tab bar bawah.
  static const Color tabBar = Color(0xFF080D26);

  /// Latar kartu (ujung bawah gradasi permukaan glassy).
  static const Color card = Color(0xFF131C44);

  /// Ujung atas gradasi permukaan kartu glassy (v4.0).
  static const Color cardHi = Color(0xFF1B2763);

  /// Garis tepi kartu & panel.
  static const Color border = Color(0xFF26346C);

  /// Garis tepi terang untuk permukaan glassy yang menonjol
  /// (kartu utama Beranda, kartu masuk) — v4.0.
  static const Color borderBright = Color(0xFF3D55A8);

  /// Latar panel di dalam kartu (kotak ikon, bidang sekunder).
  static const Color panel = Color(0xFF182350);

  /// Busur latar gauge (jalur kosong).
  static const Color gaugeTrack = Color(0xFF1D2A5E);

  /// Cyan Ookla — aksen utama (tombol, state aktif, toggle ON,
  /// ikon aksen).
  static const Color primary = Color(0xFF00C2FF);

  /// Teks/ikon DI ATAS permukaan primary (tombol cyan) — navy
  /// sangat gelap agar kontras di atas cyan terang.
  static const Color onPrimary = Color(0xFF04121F);

  /// Ujung terang gradasi (cyan muda) — ikon aksen & gradasi.
  static const Color accent = Color(0xFF00E5FF);

  /// Ujung tengah gradasi gauge (biru).
  static const Color gradientMid = Color(0xFF2979FF);

  /// Ujung akhir gradasi gauge (ungu).
  static const Color gradientEnd = Color(0xFFB04DFF);

  /// Teks utama.
  static const Color textPrimary = Color(0xFFEAF2FF);

  /// Teks sekunder.
  static const Color textSecondary = Color(0xFF8FB8E8);

  /// Teks redup — label seksi, petunjuk.
  static const Color textFaint = Color(0xFF6883B8);

  /// Garis pembatas.
  static const Color divider = Color(0xFF26346C);

  /// Aksi berbahaya (matikan, reset pabrik, hapus).
  static const Color danger = Color(0xFFEF5350);

  /// Keadaan baik/aktif.
  static const Color success = Color(0xFF66BB6A);

  /// Peringatan.
  static const Color warning = Color(0xFFFFB74D);
}

/// Gradasi permukaan v4.0 — bahasa visual glassy: permukaan
/// kartu berupa gradasi halus (terang di atas → navy di bawah),
/// bukan warna datar.
class AppGradients {
  AppGradients._();

  /// Permukaan kartu glassy standar.
  static const LinearGradient surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[AppColors.cardHi, AppColors.card],
  );

  /// Permukaan kartu utama yang lebih menonjol (header
  /// Beranda, kartu masuk) — sentuhan biru lebih kuat di atas.
  static const LinearGradient surfaceAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF223379), Color(0xFF101736)],
  );

  /// Latar layar: navy terang redup di atas → pekat di bawah.
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[AppColors.header, AppColors.bg],
  );

  /// Garis/aksen identitas: cyan → biru → ungu (Logo A).
  static const LinearGradient accentLine = LinearGradient(
    colors: <Color>[
      AppColors.accent,
      AppColors.gradientMid,
      AppColors.gradientEnd,
    ],
  );
}

/// Bayangan v4.0: lembut & dalam untuk kartu (mengambang di
/// atas latar pekat) + glow aksen seperlunya untuk elemen
/// identitas (gauge, titik LIVE, tombol utama).
class AppShadows {
  AppShadows._();

  /// Bayangan kartu standar.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(
      color: Color(0x5903091A),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  /// Glow cyan lembut untuk elemen aksen yang menyala.
  static const List<BoxShadow> glowPrimary = <BoxShadow>[
    BoxShadow(
      color: Color(0x384CC9FF),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
}

/// Skala spasi seragam (kelipatan 4).
class AppSpace {
  AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Padding standar halaman daftar.
  static const EdgeInsets page = EdgeInsets.all(lg);

  /// Padding standar isi kartu.
  static const EdgeInsets cardInner = EdgeInsets.all(lg);
}

/// Radius sudut seragam (v4.0: diperbesar agar terasa modern
/// & lembut — kartu 20, tile 14, kecil 10, pil penuh).
class AppRadius {
  AppRadius._();

  static const double card = 20;
  static const double tile = 14;
  static const double small = 10;
  static const double pill = 999;

  static const BorderRadius cardBorder =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius tileBorder =
      BorderRadius.all(Radius.circular(tile));
  static const BorderRadius pillBorder =
      BorderRadius.all(Radius.circular(pill));
}

/// Gaya teks bersama.
class AppText {
  AppText._();

  /// Fitur angka tabular: semua angka statistik & gauge
  /// sejajar kolom (tidak bergeser saat nilainya berubah) —
  /// ciri dashboard premium (v4.0).
  static const List<FontFeature> tabular = <FontFeature>[
    FontFeature.tabularFigures(),
  ];

  /// Angka tampilan besar (tengah gauge, angka hero).
  static const TextStyle displayNumber = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    fontFeatures: tabular,
    color: AppColors.textPrimary,
  );

  /// Nilai statistik pada kartu ringkas Beranda.
  static const TextStyle statValue = TextStyle(
    fontSize: 16.5,
    fontWeight: FontWeight.w700,
    fontFeatures: tabular,
    color: AppColors.textPrimary,
  );

  /// Judul seksi kecil: uppercase, redup, spasi huruf lebar —
  /// gaya daftar Settings iPhone.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: AppColors.textFaint,
  );

  /// Judul baris daftar / nama item.
  static const TextStyle rowTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Subjudul baris daftar.
  static const TextStyle rowSubtitle = TextStyle(
    fontSize: 12.5,
    color: AppColors.textSecondary,
  );

  /// Nilai pada baris label–nilai.
  static const TextStyle rowValue = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Petunjuk kecil di bawah form.
  static const TextStyle hint = TextStyle(
    fontSize: 12,
    color: AppColors.textFaint,
  );
}

/// Tema Material aplikasi — dibangun dari token di atas agar
/// semua permukaan (dialog, field, tombol, kartu) konsisten.
///
/// CATATAN Flutter 3.32 (terbukti dari CI v2.0.x): appBarTheme
/// bertipe AppBarTheme (TANPA "Data"), cardTheme bertipe
/// CardThemeData (DENGAN "Data") — jangan tertukar.
ThemeData buildAppTheme() {
  // PERBAIKAN v3.1: ColorScheme.fromSeed dalam mode gelap
  // menurunkan primary menjadi nada TERANG dari seed — itulah
  // sebabnya FilledButton di seluruh aplikasi tampil biru pucat
  // bawaan Material (temuan screenshot user v3.0). Timpa primary
  // & onPrimary secara eksplisit ke cyan Ookla + navy gelap, dan
  // kunci gaya FilledButton lewat filledButtonTheme.
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    cardColor: AppColors.card,
    dividerColor: AppColors.divider,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      // v4.0: garis bawah rambut memisahkan header dari isi —
      // detail dashboard modern (Linear/fintech).
      shape: Border(
        bottom: BorderSide(color: AppColors.border, width: 0.8),
      ),
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.panel,
      border: OutlineInputBorder(
        borderRadius: AppRadius.tileBorder,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.tileBorder,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.tileBorder,
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: AppColors.textSecondary),
      hintStyle: TextStyle(color: AppColors.textFaint),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        disabledBackgroundColor: AppColors.gaugeTrack,
        disabledForegroundColor: AppColors.textFaint,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.tileBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        textStyle: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    // v4.0: OutlinedButton seragam (aksi sekunder SMS dll.) —
    // tepi token border, teks utama, radius tile.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.tileBorder,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    // v4.0: dialog glassy mengikuti kartu (latar kartu, sudut
    // 20, tanpa surface tint bawaan).
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardBorder,
      ),
    ),
    // v4.0: indikator tab aktif = PIL (Material You) — warna
    // & bentuk dikunci di tema agar konsisten.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.tabBar,
      indicatorColor: AppColors.primary.withValues(alpha: 0.16),
      indicatorShape: const StadiumBorder(),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? AppColors.textPrimary
              : AppColors.textFaint,
        ),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.gaugeTrack,
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.tileBorder),
      textStyle: AppText.rowTitle,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.panel,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      // v4.0: snackbar melayang membulat (floating) ala
      // dashboard modern, bukan menempel di tepi bawah.
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.tileBorder,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.white
            : AppColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : const Color(0xFF26336B),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSecondary,
      titleTextStyle: AppText.rowTitle,
      subtitleTextStyle: AppText.rowSubtitle,
    ),
    // v3.1.1: transisi antar-halaman fade + geser tipis yang
    // konsisten untuk SEMUA MaterialPageRoute (hub → detail,
    // tile → halaman) — aplikasi tidak terasa kaku lagi.
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: _FadeSlideTransitionsBuilder(),
        TargetPlatform.iOS: _FadeSlideTransitionsBuilder(),
        TargetPlatform.macOS: _FadeSlideTransitionsBuilder(),
        TargetPlatform.windows: _FadeSlideTransitionsBuilder(),
        TargetPlatform.linux: _FadeSlideTransitionsBuilder(),
      },
    ),
  );
}

/// Builder transisi v3.1.1: halaman masuk memudar sambil
/// bergeser 4% dari kanan, 260 ms easeOutCubic (balik
/// easeInCubic) — halus, singkat, tetap 60fps karena hanya
/// opacity + transform.
class _FadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.04, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
