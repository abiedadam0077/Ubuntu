import 'package:flutter/material.dart';

/// هوية بصرية احترافية داكنة لتطبيق ElectroSim Pro
class AppColors {
  static const bg = Color(0xFF0B1220);
  static const surface = Color(0xFF121A2B);
  static const surfaceAlt = Color(0xFF182236);
  static const primary = Color(0xFF00E5A8); // أخضر كهربائي
  static const secondary = Color(0xFF3D9CFF); // أزرق تقني
  static const warning = Color(0xFFFFC24B);
  static const danger = Color(0xFFFF5470);
  static const textPrimary = Color(0xFFEAF0FB);
  static const textSecondary = Color(0xFF8FA0C3);
  static const grid = Color(0xFF1E2A42);
}

ThemeData buildAppTheme() {
  // نبني ColorScheme كاملاً وصريحاً (كل الأدوار) بدل الاكتفاء بتعديل جزئي
  // فوق ألوان Material 3 الافتراضية (البنفسجية). التعديل الجزئي كان يترك
  // أدواراً مثل secondaryContainer / surfaceContainerLow / onSurfaceVariant
  // بقيمها الافتراضية الباهتة، ما يظهر بوضوح في عناصر مثل ChoiceChip كبقع
  // بيضاء/رمادية شاحبة وسط واجهة داكنة — وهذا كان السبب الفعلي للمظهر
  // "الباهت/الرمادي" الذي أبلغ عنه المستخدم في بعض العناصر.
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.black,
    secondary: AppColors.secondary,
    onSecondary: Colors.black,
    secondaryContainer: AppColors.secondary.withOpacity(0.28),
    onSecondaryContainer: AppColors.textPrimary,
    tertiary: AppColors.warning,
    onTertiary: Colors.black,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    surfaceContainerLowest: AppColors.bg,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surfaceAlt,
    surfaceContainerHigh: AppColors.surfaceAlt,
    surfaceContainerHighest: AppColors.surfaceAlt,
    onSurfaceVariant: AppColors.textSecondary,
    outline: Colors.white24,
    outlineVariant: Colors.white12,
    error: AppColors.danger,
    onError: Colors.black,
    errorContainer: AppColors.danger.withOpacity(0.22),
    onErrorContainer: AppColors.textPrimary,
    inverseSurface: AppColors.textPrimary,
    onInverseSurface: AppColors.bg,
    shadow: Colors.black,
    scrim: Colors.black54,
  );
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: scheme,
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.surfaceAlt,
      disabledColor: AppColors.surfaceAlt,
      selectedColor: AppColors.primary,
      secondarySelectedColor: AppColors.primary,
      labelStyle: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      side: const BorderSide(color: Colors.white24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      checkmarkColor: Colors.black,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surfaceAlt,
      textStyle: const TextStyle(color: AppColors.textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      modalBackgroundColor: AppColors.surface,
    ),
    listTileTheme: const ListTileThemeData(
      textColor: AppColors.textPrimary,
      iconColor: AppColors.textSecondary,
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
      textStyle: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      foregroundColor: AppColors.textPrimary,
      centerTitle: true,
    ),
    cardColor: AppColors.surfaceAlt,
    dividerColor: Colors.white12,
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: Colors.white24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceAlt,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.primary,
      thumbColor: AppColors.primary,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? AppColors.primary : Colors.grey),
    ),
  );
}
