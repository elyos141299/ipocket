import 'package:flutter/material.dart';

/// Token desain terpusat iPocket v3.0 — ROMBAK TOTAL UI.
///
/// Struktur mengikuti aplikasi tpMiFi (TP-Link): Beranda fokus
/// perangkat + halaman Tools berisi grid ikon. Palet mengikuti
/// Speedtest by Ookla: navy sangat gelap, kartu navy terang,
/// aksen cyan elektrik, gradasi gauge cyan → biru → ungu.
/// Pink Advan (#EC008D/#F95FB4) dan palet gelap-ungu v1.4–v2.0
/// DITINGGALKAN total di UI (ikon aplikasi di home screen tidak
/// ikut berubah). Fitur & perilaku identik v2.0.2 — hanya kulit.
class AppColors {
  AppColors._();

  /// Latar utama aplikasi (navy sangat gelap ala Ookla).
  static const Color bg = Color(0xFF070B1F);

  /// Latar header / ujung gradasi terang.
  static const Color header = Color(0xFF0B1030);

  /// Latar tab bar bawah.
  static const Color tabBar = Color(0xFF0A0F28);

  /// Latar kartu.
  static const Color card = Color(0xFF121A3D);

  /// Garis tepi kartu & panel.
  static const Color border = Color(0xFF1E2A55);

  /// Latar panel di dalam kartu (kotak ikon, bidang sekunder).
  static const Color panel = Color(0xFF16224A);

  /// Busur latar gauge (jalur kosong).
  static const Color gaugeTrack = Color(0xFF1B2650);

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
  static const Color textFaint = Color(0xFF5F7DB3);

  /// Garis pembatas.
  static const Color divider = Color(0xFF1E2A55);

  /// Aksi berbahaya (matikan, reset pabrik, hapus).
  static const Color danger = Color(0xFFEF5350);

  /// Keadaan baik/aktif.
  static const Color success = Color(0xFF66BB6A);

  /// Peringatan.
  static const Color warning = Color(0xFFFFB74D);
}

/// Skala spasi seragam (kelipatan 4).
class AppSpace {
  AppSpace._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;

  /// Padding standar halaman daftar.
  static const EdgeInsets page = EdgeInsets.all(lg);

  /// Padding standar isi kartu.
  static const EdgeInsets cardInner = EdgeInsets.all(lg);
}

/// Radius sudut seragam.
class AppRadius {
  AppRadius._();

  static const double card = 16;
  static const double tile = 12;
  static const double small = 8;

  static const BorderRadius cardBorder =
      BorderRadius.all(Radius.circular(card));
  static const BorderRadius tileBorder =
      BorderRadius.all(Radius.circular(tile));
}

/// Gaya teks bersama.
class AppText {
  AppText._();

  /// Judul seksi kecil: uppercase, redup, spasi huruf lebar —
  /// gaya daftar Settings iPhone.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
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
        textStyle: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
        ),
      ),
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
