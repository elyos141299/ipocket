import 'package:flutter/material.dart';

/// Token desain terpusat iPocket (v2.0 — poles profesional).
///
/// Satu sumber kebenaran untuk warna, spasi, radius, dan tipografi
/// di SEMUA tab (Status, SMS, Diagnostik, Pengaturan + seluruh
/// sub-halaman pengaturan). Tema dasar tetap yang disetujui user
/// sejak v1.4: GELAP + PUTIH, pink Advan #EC008D hanya aksen kecil
/// (tombol utama, state aktif, toggle ON, ikon aksen, ring).
class AppColors {
  AppColors._();

  /// Latar utama aplikasi.
  static const Color bg = Color(0xFF121016);

  /// Latar kartu.
  static const Color card = Color(0xFF1E1A24);

  /// Latar panel di dalam kartu (kotak ikon, bidang sekunder).
  static const Color panel = Color(0xFF262030);

  /// Pink Advan — aksen utama.
  static const Color primary = Color(0xFFEC008D);

  /// Pink terang — gradasi & ikon aksen.
  static const Color accent = Color(0xFFF95FB4);

  /// Teks utama.
  static const Color textPrimary = Colors.white;

  /// Teks sekunder (putih 70%).
  static const Color textSecondary = Color(0xB3FFFFFF);

  /// Teks redup (putih 38%) — label seksi, petunjuk.
  static const Color textFaint = Color(0x61FFFFFF);

  /// Garis pembatas (putih ±12%).
  static const Color divider = Color(0x1FFFFFFF);

  /// Aksi berbahaya (matikan, reset pabrik, hapus).
  static const Color danger = Color(0xFFEF5350);

  /// Keadaan baik/aktif.
  static const Color success = Color(0xFF66BB6A);

  /// Peringatan.
  static const Color warning = Color(0xFFFFB74D);

  /// Ujung gradasi header dashboard.
  static const Color headerDark = Color(0xFF16121A);
  static const Color headerDeep = Color(0xFF2A1530);
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
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    cardColor: AppColors.card,
    dividerColor: AppColors.divider,
    useMaterial3: true,
    appBarTheme: const AppBarThemeData(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
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
            : const Color(0xFF3A3345),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSecondary,
      titleTextStyle: AppText.rowTitle,
      subtitleTextStyle: AppText.rowSubtitle,
    ),
  );
}
