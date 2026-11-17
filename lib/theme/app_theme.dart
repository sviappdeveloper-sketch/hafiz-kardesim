import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/l10n.dart';
import '../l10n/l10n.dart';

/// Renk takımı. Uygulama üç tema sunar: koyu "Gece Mavisi" (varsayılan, logodaki lacivert + gümüş),
/// koyu "Zümrüt" ve açık "Parşömen".
class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.light,
    required this.inkDeep,
    required this.ink,
    required this.inkSoft,
    required this.inkLine,
    required this.gold,
    required this.goldLight,
    required this.ivory,
    required this.muted,
    required this.reading,
    required this.done,
    required this.danger,
  });
  final String id, name;
  final bool light;
  final Color inkDeep, ink, inkSoft, inkLine, gold, goldLight, ivory, muted, reading, done, danger;

  /// Yeni logodaki gece laciverti ve parlak gümüş.
  static const night = AppPalette(
    id: 'gece',
    name: 'Gece Mavisi',
    light: false,
    inkDeep: Color(0xFF02060F),
    ink: Color(0xFF050E20),
    inkSoft: Color(0xFF0A1A36),
    inkLine: Color(0xFF1B3462),
    gold: Color(0xFFCDD5E1),
    goldLight: Color(0xFFF2F5FA),
    ivory: Color(0xFFEDF1F7),
    muted: Color(0xFF8D9DBA),
    reading: Color(0xFF6FA8E8),
    done: Color(0xFF86C29A),
    danger: Color(0xFFE08A78),
  );

  /// Eski logodaki derin zümrüt yeşili ve parlak altın; fildişi metin.
  static const emerald = AppPalette(
    id: 'zumrut',
    name: 'Zümrüt',
    light: false,
    inkDeep: Color(0xFF001A0D),
    ink: Color(0xFF002515),
    inkSoft: Color(0xFF053420),
    inkLine: Color(0xFF0F4A30),
    gold: Color(0xFFF2C14A),
    goldLight: Color(0xFFF8DC82),
    ivory: Color(0xFFFBF3DF),
    muted: Color(0xFF95B5A2),
    reading: Color(0xFF7BB0CF),
    done: Color(0xFF86C29A),
    danger: Color(0xFFD9826A),
  );

  /// Açılıştaki eski parşömenin ham kâğıt rengi; koyu kahve mürekkep ve koyu altın.
  static const parchment = AppPalette(
    id: 'parsomen',
    name: 'Parşömen',
    light: true,
    inkDeep: Color(0xFFE6D7B4),
    ink: Color(0xFFF1E6CB),
    inkSoft: Color(0xFFF8F0DC),
    inkLine: Color(0xFFD5C196),
    gold: Color(0xFF9C6F0E),
    goldLight: Color(0xFF7A5408),
    ivory: Color(0xFF2E2214),
    muted: Color(0xFF6F604A),
    reading: Color(0xFF2F6E8E),
    done: Color(0xFF3E7A52),
    danger: Color(0xFFA9462E),
  );

  static const all = [night, emerald, parchment];
  static AppPalette byId(String? id) => all.firstWhere((p) => p.id == id, orElse: () => night);

  /// Tema kartındaki kısa açıklama.
  String get aciklama => switch (id) {
        'gece' => 'Koyu · lacivert ve gümüş',
        'zumrut' => 'Koyu · zümrüt yeşili',
        _ => 'Açık · ham parşömen',
      };
}

/// Uygulamanın o anki renkleri (seçili temaya göre).
class AppColors {
  static AppPalette _p = AppPalette.night;
  static AppPalette get palette => _p;
  static void use(AppPalette p) => _p = p;
  static bool get isLight => _p.light;

  static Color get inkDeep => _p.inkDeep;
  static Color get ink => _p.ink;
  static Color get inkSoft => _p.inkSoft;
  static Color get inkLine => _p.inkLine;
  static Color get gold => _p.gold;
  static Color get goldLight => _p.goldLight;
  static Color get ivory => _p.ivory;
  static Color get muted => _p.muted;
  static Color get reading => _p.reading;
  static Color get done => _p.done;
  static Color get danger => _p.danger;
}

class AppText {
  /// Başlıklar: kuyruksuz (sans), dolgun ve az kullanılan bir yazı tipi (Sora).
  /// Eski serif yazı tipine göre daha iri durduğu için boyut %80 ölçeklenir; italik kullanılmaz.
  static TextStyle display(double size,
          {Color? color,
          FontWeight weight = FontWeight.w600,
          FontStyle style = FontStyle.normal}) =>
      (Lang.isAr ? GoogleFonts.cairo : GoogleFonts.sora)(
          fontSize: size * (Lang.isAr ? 0.86 : 0.8),
          color: color ?? AppColors.ivory,
          fontWeight: weight,
          height: 1.25,
          letterSpacing: -0.2,
          fontFeatures: const [FontFeature.liningFigures()]);

  static TextStyle body(double size,
          {Color? color, FontWeight weight = FontWeight.w400, double height = 1.45}) =>
      (Lang.isAr ? GoogleFonts.cairo : GoogleFonts.manrope)(fontSize: size, color: color ?? AppColors.ivory, fontWeight: weight, height: Lang.isAr ? height + 0.1 : height);

  static TextStyle label({Color? color, double size = 11}) => (Lang.isAr ? GoogleFonts.cairo : GoogleFonts.manrope)(
      fontSize: Lang.isAr ? size + 1 : size, color: color ?? AppColors.gold, fontWeight: FontWeight.w700, letterSpacing: Lang.isAr ? 0 : 1.8);

  /// Rakamlar için: düz (lining), eşit genişlikli ve kolay okunan sayılar.
  static TextStyle number(double size, {Color? color, FontWeight weight = FontWeight.w700}) =>
      GoogleFonts.manrope(
        fontSize: size,
        color: color ?? AppColors.ivory,
        fontWeight: weight,
        height: 1.1,
        fontFeatures: const [FontFeature.tabularFigures(), FontFeature.liningFigures()],
      );

  static TextStyle arabic(double size, {Color? color}) =>
      GoogleFonts.amiri(fontSize: size, color: color ?? AppColors.goldLight, height: 1.9);
}

class AppTheme {
  static ThemeData get theme {
    final base = ThemeData(
      brightness: AppColors.isLight ? Brightness.light : Brightness.dark,
      useMaterial3: true,
      colorScheme: (AppColors.isLight ? const ColorScheme.light() : const ColorScheme.dark()).copyWith(
        primary: AppColors.gold,
        secondary: AppColors.goldLight,
        // Varsayılan koyu şemadaki turkuaz tonlarını (seçili segment, chip vb.) altına çek.
        onSecondary: AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep,
        primaryContainer: AppColors.gold,
        onPrimaryContainer: AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep,
        secondaryContainer: AppColors.gold,
        onSecondaryContainer: AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep,
        tertiary: AppColors.goldLight,
        onTertiary: AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep,
        tertiaryContainer: AppColors.gold,
        onTertiaryContainer: AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep,
        outline: AppColors.inkLine,
        surface: AppColors.inkSoft,
        onPrimary: AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep,
        onSurface: AppColors.ivory,
        error: AppColors.danger,
      ),
    );
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.inkLine),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ink,
      textTheme: Lang.isAr ? GoogleFonts.cairoTextTheme(base.textTheme) : GoogleFonts.manropeTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.ivory, displayColor: AppColors.ivory),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ivory,
        titleTextStyle: AppText.display(24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inkDeep.withValues(alpha: 0.55),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: BorderSide(color: AppColors.gold, width: 1.4)),
        labelStyle: AppText.body(14, color: AppColors.muted),
        hintStyle: AppText.body(14, color: AppColors.muted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inkSoft,
        contentTextStyle: AppText.body(14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.gold, textStyle: AppText.body(14, weight: FontWeight.w600)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.goldLight,
        unselectedLabelColor: AppColors.muted,
        indicatorColor: AppColors.gold,
        dividerColor: AppColors.inkLine,
        labelStyle: AppText.body(14, weight: FontWeight.w700),
        unselectedLabelStyle: AppText.body(14),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        selectedColor: AppColors.gold,
        backgroundColor: Colors.transparent,
        side: BorderSide(color: AppColors.gold.withValues(alpha: 0.5)),
        labelStyle: AppText.body(13, weight: FontWeight.w600, color: AppColors.ivory),
        secondaryLabelStyle: AppText.body(13, weight: FontWeight.w700,
            color: AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? AppColors.gold : Colors.transparent),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
              ? (AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep)
              : AppColors.ivory),
          iconColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
              ? (AppColors.isLight ? const Color(0xFFFFF8E8) : AppColors.inkDeep)
              : AppColors.ivory),
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.gold.withValues(alpha: 0.55))),
          textStyle: WidgetStatePropertyAll(AppText.body(14, weight: FontWeight.w600)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
        ),
      ),
      dividerColor: AppColors.inkLine,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.inkSoft,
        showDragHandle: true,
        dragHandleColor: AppColors.gold,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.inkSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.gold),
    );
  }
}
