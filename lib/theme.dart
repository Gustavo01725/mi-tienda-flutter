import 'package:flutter/material.dart';

/// Colores y medidas tomados de la web guStore (aiz-core.css + layouts/app.blade.php).
class AppColors {
  static const primary = Color(0xFF679941); // --primary
  static const primaryDark = Color(0xFF4E7A2E); // degradado de "Mis pedidos"
  static const softPrimary = Color(0x26679941); // --soft-primary (15 %)
  static const tile = Color(0xFFE8EFE0); // fondo de "Compra por categoría"
  static const bg = Color(0xFFF2F3F8); // .aiz-main-wrapper
  static const text = Color(0xFF1B1B28);
  static const textSoft = Color(0xFF555555);
  static const muted = Color(0xFF6C757D);
  static const muted2 = Color(0xFF888888);
  static const muted3 = Color(0xFF999999);
  static const strike = Color(0xFFBBBBBB);
  static const border = Color(0xFFE2E5EC);
  static const borderLight = Color(0xFFE8EAED);
  static const divider = Color(0xFFEDF2F7);
  static const star = Color(0xFFF0AD00);
  static const danger = Color(0xFFE74C3C);
  static const dangerSoft = Color(0xFFFFEEEE);
  static const field = Color(0xFFF8F9FA);
  static const footer = Color(0xFF131A27);

  static const walletGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFC850C0), Color(0xFFF97794), Color(0xFFFCC5E4)],
    stops: [0, .55, 1],
  );
  static const ordersGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}

/// Sombra de las tarjetas de la web (.shadow-sm): 0 1px 2px rgba(0,0,0,.05).
const cardShadow = [BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1))];

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.primary,
    surface: Colors.white,
    onSurface: AppColors.text,
    error: AppColors.danger,
  );
  final radius = BorderRadius.circular(4);
  OutlineInputBorder border(Color c) => OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'OpenSans',
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 13, color: AppColors.text),
      bodyLarge: TextStyle(fontSize: 14, color: AppColors.text),
      bodySmall: TextStyle(fontSize: 12, color: AppColors.muted),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      hintStyle: const TextStyle(color: Color(0xFF898B92), fontSize: 14),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary),
      errorBorder: border(AppColors.danger),
      focusedErrorBorder: border(AppColors.danger),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: 'OpenSans', fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: AppColors.primary, width: 2),
        shape: RoundedRectangleBorder(borderRadius: radius),
        textStyle: const TextStyle(fontFamily: 'OpenSans', fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(fontFamily: 'OpenSans', fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: Color(0xFFADB5BD)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: AppColors.divider, space: 1, thickness: 1),
  );
}
