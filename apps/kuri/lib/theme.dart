import 'package:flutter/material.dart';

// ─── Color palette class (ThemeExtension for theme-aware access) ───────────

class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color borderStrong;
  final Color primary;
  final Color primaryFg;
  final Color primaryMid;
  final Color primaryLight;
  final Color text;
  final Color textSub;
  final Color textMuted;
  final Color textDim;
  final Color danger;
  final Color dangerDark;
  final Color dangerFg;
  final Color green;
  final Color greenDark;
  final Color greenFg;
  final Color warn;
  final Color warnBg;
  final Color inputFill;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.borderStrong,
    required this.primary,
    required this.primaryFg,
    required this.primaryMid,
    required this.primaryLight,
    required this.text,
    required this.textSub,
    required this.textMuted,
    required this.textDim,
    required this.danger,
    required this.dangerDark,
    required this.dangerFg,
    required this.green,
    required this.greenDark,
    required this.greenFg,
    required this.warn,
    required this.warnBg,
    required this.inputFill,
  });

  // ── Dark greyish theme (Apple-inspired dark mode) ───────────────────────
  static const dark = AppColors(
    bg: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceHigh: Color(0xFF2C2C2E),
    border: Color(0xFF2C2C2E),
    borderStrong: Color(0xFF3A3A3C),
    primary: Color(0xFF22D3EE),
    primaryFg: Color(0xFF083344),
    primaryMid: Color(0xFF0E7490),
    primaryLight: Color(0xFF164E63),
    text: Color(0xFFFFFFFF),
    textSub: Color(0xFFEBEBF5),
    textMuted: Color(0xFFAEAEB2),
    textDim: Color(0xFF636366),
    danger: Color(0xFFFF453A),
    dangerDark: Color(0xFF4A0000),
    dangerFg: Color(0xFFFFD7D5),
    green: Color(0xFF30D158),
    greenDark: Color(0xFF0A3D1A),
    greenFg: Color(0xFFD4F4DC),
    warn: Color(0xFFFFD60A),
    warnBg: Color(0xFF3A2800),
    inputFill: Color(0xFF1C1C1E),
  );

  // ── Light theme (iOS-inspired) ─────────────────────────────────────────
  static const light = AppColors(
    bg: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF2F2F7),
    border: Color(0xFFC6C6C8),
    borderStrong: Color(0xFFAEAEB2),
    primary: Color(0xFF0891B2),
    primaryFg: Color(0xFFFFFFFF),
    primaryMid: Color(0xFF0E7490),
    primaryLight: Color(0xFFE0F7FA),
    text: Color(0xFF000000),
    textSub: Color(0xFF1C1C1E),
    textMuted: Color(0xFF3C3C43),
    textDim: Color(0xFF8E8E93),
    danger: Color(0xFFFF3B30),
    dangerDark: Color(0xFFFFEEEE),
    dangerFg: Color(0xFFCC0000),
    green: Color(0xFF34C759),
    greenDark: Color(0xFFECFDF5),
    greenFg: Color(0xFF065F46),
    warn: Color(0xFFFF9F0A),
    warnBg: Color(0xFFFFF3CD),
    inputFill: Color(0xFFFFFFFF),
  );

  @override
  AppColors copyWith({
    Color? bg, Color? surface, Color? surfaceHigh, Color? border, Color? borderStrong,
    Color? primary, Color? primaryFg, Color? primaryMid, Color? primaryLight,
    Color? text, Color? textSub, Color? textMuted, Color? textDim,
    Color? danger, Color? dangerDark, Color? dangerFg,
    Color? green, Color? greenDark, Color? greenFg,
    Color? warn, Color? warnBg, Color? inputFill,
  }) {
    return AppColors(
      bg: bg ?? this.bg, surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      border: border ?? this.border, borderStrong: borderStrong ?? this.borderStrong,
      primary: primary ?? this.primary, primaryFg: primaryFg ?? this.primaryFg,
      primaryMid: primaryMid ?? this.primaryMid, primaryLight: primaryLight ?? this.primaryLight,
      text: text ?? this.text, textSub: textSub ?? this.textSub,
      textMuted: textMuted ?? this.textMuted, textDim: textDim ?? this.textDim,
      danger: danger ?? this.danger, dangerDark: dangerDark ?? this.dangerDark,
      dangerFg: dangerFg ?? this.dangerFg,
      green: green ?? this.green, greenDark: greenDark ?? this.greenDark,
      greenFg: greenFg ?? this.greenFg,
      warn: warn ?? this.warn, warnBg: warnBg ?? this.warnBg,
      inputFill: inputFill ?? this.inputFill,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryFg: Color.lerp(primaryFg, other.primaryFg, t)!,
      primaryMid: Color.lerp(primaryMid, other.primaryMid, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSub: Color.lerp(textSub, other.textSub, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerDark: Color.lerp(dangerDark, other.dangerDark, t)!,
      dangerFg: Color.lerp(dangerFg, other.dangerFg, t)!,
      green: Color.lerp(green, other.green, t)!,
      greenDark: Color.lerp(greenDark, other.greenDark, t)!,
      greenFg: Color.lerp(greenFg, other.greenFg, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnBg: Color.lerp(warnBg, other.warnBg, t)!,
      inputFill: Color.lerp(inputFill, other.inputFill, t)!,
    );
  }
}

// ── BuildContext extension for easy access ──────────────────────────────────
extension AppThemeX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

// ── Backward-compat constants (dark values, for screens not yet updated) ───
const bgColor = Color(0xFF000000);
const surfaceColor = Color(0xFF1C1C1E);
const borderColor = Color(0xFF2C2C2E);
const primaryColor = Color(0xFF22D3EE);
const primaryFg = Color(0xFF083344);
const primaryMid = Color(0xFF0E7490);
const primaryLight = Color(0xFF164E63);
const textColor = Color(0xFFFFFFFF);
const textMuted = Color(0xFFAEAEB2);
const textDim = Color(0xFF636366);
const dangerColor = Color(0xFFFF453A);
const greenColor = Color(0xFF30D158);
const warnColor = Color(0xFFFFD60A);
const warnBg = Color(0xFF3A2800);

// ─── Theme builders ────────────────────────────────────────────────────────

ThemeData buildDarkTheme() => _buildTheme(Brightness.dark, AppColors.dark);
ThemeData buildLightTheme() => _buildTheme(Brightness.light, AppColors.light);

ThemeData _buildTheme(Brightness brightness, AppColors c) {
  return ThemeData(
    brightness: brightness,
    extensions: [c],
    scaffoldBackgroundColor: c.bg,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: c.primary,
      onPrimary: c.primaryFg,
      secondary: c.primaryMid,
      onSecondary: c.text,
      error: c.danger,
      onError: c.dangerFg,
      surface: c.surface,
      onSurface: c.text,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w700),
      iconTheme: IconThemeData(color: c.textMuted),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: c.surface,
      selectedItemColor: c.primary,
      unselectedItemColor: c.textDim,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: c.border),
      ),
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c.primary, width: 1.5),
      ),
      labelStyle: TextStyle(color: c.textMuted),
      hintStyle: TextStyle(color: c.textDim),
      prefixIconColor: c.textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.primaryFg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.primary,
        side: BorderSide(color: c.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.primary),
    ),
    iconTheme: IconThemeData(color: c.textMuted),
    dividerColor: c.border,
    listTileTheme: ListTileThemeData(
      iconColor: c.textMuted,
      textColor: c.text,
      subtitleTextStyle: TextStyle(color: c.textMuted, fontSize: 13),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.surfaceHigh,
      labelStyle: TextStyle(color: c.text, fontSize: 13),
      side: BorderSide(color: c.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: c.primary,
      unselectedLabelColor: c.textMuted,
      indicatorColor: c.primary,
      dividerColor: c.border,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.primary,
      foregroundColor: c.primaryFg,
      elevation: 2,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceHigh,
      contentTextStyle: TextStyle(color: c.text),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: c.text, fontSize: 16),
      bodyMedium: TextStyle(color: c.text, fontSize: 14),
      bodySmall: TextStyle(color: c.textMuted, fontSize: 12),
      titleLarge: TextStyle(color: c.text, fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: c.text, fontSize: 17, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: c.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
      labelLarge: TextStyle(color: c.primary, fontSize: 15, fontWeight: FontWeight.w600),
      headlineMedium: TextStyle(color: c.text, fontSize: 24, fontWeight: FontWeight.bold),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.w700),
      contentTextStyle: TextStyle(color: c.textMuted, fontSize: 14),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primaryFg : c.textDim),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.border),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.surface,
      headerBackgroundColor: c.primary,
      headerForegroundColor: c.primaryFg,
      dayForegroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return c.primaryFg;
        if (s.contains(WidgetState.disabled)) return c.textDim;
        return c.text;
      }),
      yearForegroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return c.primaryFg;
        if (s.contains(WidgetState.disabled)) return c.textDim;
        return c.text;
      }),
      todayForegroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return c.primaryFg;
        return c.primary;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return c.primary;
        return Colors.transparent;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((s) {
        if (s.contains(WidgetState.selected)) return c.primary;
        return Colors.transparent;
      }),
      dividerColor: c.border,
    ),
  );
}

// Keep this for backward compat
ThemeData buildAppTheme() => buildDarkTheme();
