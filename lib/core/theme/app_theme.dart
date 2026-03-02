import 'dart:ui';
import 'package:flutter/material.dart';
import 'color_scheme_data.dart';
import 'color_scheme_manager.dart';

class AppTheme {
  // Lotus Theme - Brand Colors
  // 莲花粉紫渐变作为主色调
  static const Color primaryColor = Color(0xFFE91E8C); // Lotus Pink
  static const Color primaryLight = Color(0xFFFF6EB4); // Light Pink
  static const Color primaryDark = Color(0xFFAD1457); // Deep Pink

  static const Color secondaryColor = Color(0xFF9C27B0); // Purple
  static const Color accentColor = Color(0xFF00BCD4); // Cyan accent

  // ============ Dark Theme Colors ============
  static const Color backgroundColorDark = Color(0xFF000000); // Pure Black
  static const Color surfaceColorDark = Color(0xFF0A0A0A); // Near Black
  static const Color cardColorDark = Color(0xFF121212); // Dark Grey
  static const Color cardHoverColorDark = Color(0xFF1A1A1A);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);
  static const Color textMutedDark = Color(0xFF757575);
  static const Color glassColorDark = Color(0x1AFFFFFF);
  static const Color glassBorderColorDark = Color(0x33FFFFFF);

  // ============ Light Theme Colors ============
  static const Color backgroundColorLight = Color(0xFFF5F5F5); // Light Grey
  static const Color surfaceColorLight = Color(0xFFFFFFFF); // White
  static const Color cardColorLight = Color(0xFFFFFFFF); // White
  static const Color cardHoverColorLight = Color(0xFFF0F0F0);
  static const Color focusBackgroundColorLight = Color(0xFFFCE4EC); // Light Pink for focus in light mode
  static const Color textPrimaryLight = Color(0xFF212121);
  static const Color textSecondaryLight = Color(0xFF616161);
  static const Color textMutedLight = Color(0xFF9E9E9E);
  static const Color glassColorLight = Color(0x1A000000);
  static const Color glassBorderColorLight = Color(0x33000000);

  // ============ Dynamic Colors (based on theme) ============
  // 这些是默认值（暗色主题），实际使用时通过 of(context) 获取
  static const Color backgroundColor = backgroundColorDark;
  static const Color surfaceColor = surfaceColorDark;
  static const Color cardColor = cardColorDark;
  static const Color cardHoverColor = cardHoverColorDark;
  static const Color textPrimary = textPrimaryDark;
  static const Color textSecondary = textSecondaryDark;
  static const Color textMuted = textMutedDark;
  static const Color glassColor = glassColorDark;
  static const Color glassBorderColor = glassBorderColorDark;
  static const Color glassHighlight = Color(0x0DFFFFFF);

  // Focus Colors (for TV navigation) - Lotus gradient
  static const Color focusColor = Color(0xFFE91E8C);
  static const Color focusBorderColor = Color(0xFFFF6EB4);

  // Status Colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFFF5252);
  static const Color warningColor = Color(0xFFFFB74D);
  static const Color infoColor = Color(0xFF29B6F6);

  // ============ Helper methods to get theme-aware colors ============
  static Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? backgroundColorDark : backgroundColorLight;
  }

  static Color getSurfaceColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? surfaceColorDark : surfaceColorLight;
  }

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? cardColorDark : cardColorLight;
  }

  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textPrimaryDark : textPrimaryLight;
  }

  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textSecondaryDark : textSecondaryLight;
  }

  static Color getTextMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? textMutedDark : textMutedLight;
  }

  static Color getGlassColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? glassColorDark : glassColorLight;
  }

  static Color getGlassBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? glassBorderColorDark : glassBorderColorLight;
  }

  static Color getFocusBackgroundColor(BuildContext context) {
    // 使用配色方案的主色，添加透明度作为焦点背景
    // 明亮主题需要更高的透明度才能看清
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.1 : 0.15);
  }

  // Lotus Gradient - 莲花渐变
  static const LinearGradient lotusGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE91E8C), // Pink
      Color(0xFF9C27B0), // Purple
    ],
  );
  
  /// 获取当前主题的渐变色（动态）
  static LinearGradient getGradient(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [colorScheme.primary, colorScheme.secondary],
    );
  }
  
  /// 获取当前主题的主色（动态）
  static Color getPrimaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.primary;
  }
  
  /// 获取当前主题的次色（动态）
  static Color getSecondaryColor(BuildContext context) {
    return Theme.of(context).colorScheme.secondary;
  }
  
  /// 获取当前主题的柔和渐变（动态）
  static LinearGradient getSoftGradient(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        colorScheme.primary.withOpacity(0.4),
        colorScheme.secondary.withOpacity(0.4),
      ],
    );
  }

  static const LinearGradient lotusSoftGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x66E91E8C), // Pink 40%
      Color(0x669C27B0), // Purple 40%
    ],
  );

  // Card Gradient - Glassmorphism

  /// 字体映射（使用项目内字体文件）
  static const Map<String, String?> fontMap = {
    'System': null, // 系统字体（所有平台）
    'Source Han Sans SC Normal': 'SourceHanSansSC-Normal', // 思源黑体-常规（开源）
    'Source Han Sans SC Bold': 'SourceHanSansSC-Bold', // 思源黑体-粗体（开源）
  };
  
  /// 字体迁移映射表 - 将旧的侵权字体映射到思源黑体粗体
  /// 用于自动迁移用户之前选择的字体
  static const Map<String, String> fontMigrationMap = {
    // 中文字体 → 思源黑体粗体
    'SimHei': 'Source Han Sans SC Bold',
    'SimSun': 'Source Han Sans SC Bold',
    'KaiTi': 'Source Han Sans SC Bold',
    'FangSong': 'Source Han Sans SC Bold',
    'Microsoft YaHei': 'Source Han Sans SC Bold',
    'MicrosoftYaHei': 'Source Han Sans SC Bold',
    // 英文字体 → 思源黑体粗体
    'Arial': 'Source Han Sans SC Bold',
    'Calibri': 'Source Han Sans SC Bold',
    'Georgia': 'Source Han Sans SC Bold',
    'Verdana': 'Source Han Sans SC Bold',
    'Tahoma': 'Source Han Sans SC Bold',
    'TimesNewRoman': 'Source Han Sans SC Bold',
    'Times New Roman': 'Source Han Sans SC Bold',
    'SegoeUI': 'Source Han Sans SC Bold',
    'Segoe UI': 'Source Han Sans SC Bold',
    'Impact': 'Source Han Sans SC Bold',
    // 已删除的字体 → 思源黑体粗体
    'Source Han Sans SC ExtraLight': 'Source Han Sans SC Bold',
    'OPPO Sans': 'Source Han Sans SC Bold',
    // System → 思源黑体粗体
    'System': 'Source Han Sans SC Bold',
  };
  
  /// 根据平台和语言获取可用的字体列表
  /// 所有平台都显示相同的字体选项（使用项目内字体文件）
  static List<String> getAvailableFonts([String? languageCode]) {
    return [
      'System',
      'Source Han Sans SC Normal',
      'Source Han Sans SC Bold',
    ];
  }
  
  /// 根据字体名称获取fontFamily
  /// 使用项目内字体文件，确保所有平台一致
  static String? resolveFontFamily(String fontName) {
    if (fontName == 'System') {
      return null;
    }
    return fontMap[fontName];
  }

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x1AFFFFFF), // 10% white
      Color(0x0DFFFFFF), // 5% white
    ],
  );

  // Overlay Gradients for Player
  static const LinearGradient overlayGradientTop = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xCC000000), // 80% black
      Colors.transparent,
    ],
    stops: [0.0, 1.0],
  );

  static const LinearGradient overlayGradientBottom = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Color(0xE6000000), // 90% black
    ],
    stops: [0.0, 1.0],
  );

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 24.0;
  static const double radiusPill = 50.0;

  // Spacing
  static const double spacingXSmall = 4.0;
  static const double spacingSmall = 8.0;
  static const double spacingMedium = 16.0;
  static const double spacingLarge = 24.0;
  static const double spacingXLarge = 32.0;

  // Animation Durations
  static const Duration animationFast = Duration(milliseconds: 150);
  static const Duration animationNormal = Duration(milliseconds: 300);
  static const Duration animationSlow = Duration(milliseconds: 500);

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(
        color: textSecondary,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimary,
          letterSpacing: -0.25,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textMuted,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimary,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: glassBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: glassBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: const TextStyle(color: textMuted),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLarge),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColor,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1F1F1F),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: glassColor,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withAlpha(51),
        trackHeight: 4,
      ),
    );
  }

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColorLight,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColorLight,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimaryLight,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: cardColorLight,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColorLight,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimaryLight),
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColorLight,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      iconTheme: const IconThemeData(
        color: textSecondaryLight,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimaryLight),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimaryLight),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimaryLight),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimaryLight),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimaryLight),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: textPrimaryLight),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimaryLight),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimaryLight),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondaryLight),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: textPrimaryLight),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textSecondaryLight),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: textMutedLight),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimaryLight),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textSecondaryLight),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: textMutedLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassColorLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: glassBorderColorLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: glassBorderColorLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: const TextStyle(color: textMutedLight),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cardColorLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: cardColorLight,
        contentTextStyle: const TextStyle(color: textPrimaryLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: primaryColor),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: glassColorLight,
        thumbColor: primaryColor,
        overlayColor: primaryColor.withAlpha(51),
        trackHeight: 4,
      ),
    );
  }
}

// Glassmorphism Card Decoration
class GlassDecoration extends BoxDecoration {
  GlassDecoration({
    required BuildContext context,
    bool focused = false,
    double borderRadius = AppTheme.radiusMedium,
    Color? glowColor,
  }) : super(
          borderRadius: BorderRadius.circular(borderRadius),
          color: AppTheme.glassColor,
          border: Border.all(
            color: focused ? (glowColor ?? AppTheme.getPrimaryColor(context)) : AppTheme.glassBorderColor,
            width: focused ? 2 : 1,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: (glowColor ?? AppTheme.getPrimaryColor(context)).withAlpha(102),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        );
}

// TV-specific focus decoration with Lotus glow
class TVFocusDecoration extends BoxDecoration {
  TVFocusDecoration({required BuildContext context, bool focused = false})
      : super(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(
            color: focused ? AppTheme.getPrimaryColor(context) : Colors.transparent,
            width: focused ? 3 : 0,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: AppTheme.getPrimaryColor(context).withAlpha(102),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ]
              : null,
        );
}

// Glass Card Widget
class GlassCard extends StatelessWidget {
  final Widget child;
  final bool focused;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;

  const GlassCard({
    super.key,
    required this.child,
    this.focused = false,
    this.borderRadius = AppTheme.radiusMedium,
    this.padding,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: AppTheme.animationFast,
          decoration: GlassDecoration(
            context: context,
            focused: focused,
            borderRadius: borderRadius,
            glowColor: glowColor,
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

// ============ Dynamic Theme Generation with Color Schemes ============

extension AppThemeDynamic on AppTheme {
  /// 根据配色方案 ID 生成黑暗主题
  static ThemeData getDarkTheme(String schemeId, [String? fontFamily]) {
    final scheme = ColorSchemeManager.instance.getDarkScheme(schemeId);
    // ServiceLocator.log.d('AppTheme: 生成黑暗主题 - schemeId=$schemeId, primaryColor=${scheme.primaryColor}, secondaryColor=${scheme.secondaryColor}, fontFamily=$fontFamily');
    return _buildDarkTheme(scheme, fontFamily);
  }
  
  /// 根据配色方案 ID 生成明亮主题
  static ThemeData getLightTheme(String schemeId, [String? fontFamily]) {
    final scheme = ColorSchemeManager.instance.getLightScheme(schemeId);
    // ServiceLocator.log.d('AppTheme: 生成明亮主题 - schemeId=$schemeId, primaryColor=${scheme.primaryColor}, secondaryColor=${scheme.secondaryColor}, fontFamily=$fontFamily');
    return _buildLightTheme(scheme, fontFamily);
  }
  
  /// 构建黑暗主题（使用配色方案）
  static ThemeData _buildDarkTheme(ColorSchemeData scheme, [String? fontFamily]) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: scheme.primaryColor,
      scaffoldBackgroundColor: AppTheme.backgroundColorDark,
      fontFamily: fontFamily,
      hoverColor: scheme.primaryColor.withOpacity(0.08),
      focusColor: scheme.primaryColor.withOpacity(0.12),
      highlightColor: scheme.primaryColor.withOpacity(0.1),
      splashColor: scheme.primaryColor.withOpacity(0.12),
      colorScheme: ColorScheme.dark(
        primary: scheme.primaryColor,
        secondary: scheme.secondaryColor,
        surface: AppTheme.surfaceColorDark,
        error: AppTheme.errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppTheme.textPrimaryDark,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppTheme.cardColorDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryDark),
        titleTextStyle: TextStyle(
          color: AppTheme.textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppTheme.surfaceColorDark,
        selectedItemColor: scheme.primaryColor,
        unselectedItemColor: AppTheme.textMutedDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      iconTheme: const IconThemeData(
        color: AppTheme.textSecondaryDark,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryDark, letterSpacing: -0.25),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryDark),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppTheme.textPrimaryDark),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: AppTheme.textSecondaryDark),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppTheme.textMutedDark),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryDark),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryDark),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textMutedDark),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          side: BorderSide(color: scheme.primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.glassColorDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.glassBorderColorDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.glassBorderColorDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: scheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        hintStyle: const TextStyle(color: AppTheme.textMutedDark),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTheme.cardColorDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        elevation: 8,
        shadowColor: Colors.black54,
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: scheme.primaryColor.withOpacity(0.1),
        selectedColor: scheme.primaryColor,
        iconColor: AppTheme.textSecondaryDark,
        textColor: AppTheme.textPrimaryDark,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTheme.cardColorDark,
        contentTextStyle: const TextStyle(color: AppTheme.textPrimaryDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1F1F1F),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primaryColor),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primaryColor,
        inactiveTrackColor: AppTheme.glassColorDark,
        thumbColor: scheme.primaryColor,
        overlayColor: scheme.primaryColor.withAlpha(51),
        trackHeight: 4,
      ),
    );
  }
  
  /// 构建明亮主题（使用配色方案）
  static ThemeData _buildLightTheme(ColorSchemeData scheme, [String? fontFamily]) {
    final bgColor = scheme.backgroundColor ?? AppTheme.backgroundColorLight;
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: scheme.primaryColor,
      scaffoldBackgroundColor: bgColor,
      fontFamily: fontFamily,
      hoverColor: scheme.primaryColor.withOpacity(0.12),
      focusColor: scheme.primaryColor.withOpacity(0.15),
      highlightColor: scheme.primaryColor.withOpacity(0.15),
      splashColor: scheme.primaryColor.withOpacity(0.2),
      colorScheme: ColorScheme.light(
        primary: scheme.primaryColor,
        secondary: scheme.secondaryColor,
        surface: AppTheme.surfaceColorLight,
        error: AppTheme.errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppTheme.textPrimaryLight,
        onError: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: AppTheme.cardColorLight,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTheme.surfaceColorLight,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppTheme.textPrimaryLight),
        titleTextStyle: TextStyle(
          color: AppTheme.textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppTheme.surfaceColorLight,
        selectedItemColor: scheme.primaryColor,
        unselectedItemColor: AppTheme.textMutedLight,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      iconTheme: const IconThemeData(
        color: AppTheme.textSecondaryLight,
        size: 24,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryLight),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryLight),
        titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimaryLight),
        titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryLight),
        titleSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryLight),
        bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppTheme.textPrimaryLight),
        bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: AppTheme.textSecondaryLight),
        bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: AppTheme.textMutedLight),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryLight),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryLight),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: AppTheme.textMutedLight),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          side: BorderSide(color: scheme.primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusPill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppTheme.glassColorLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.glassBorderColorLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.glassBorderColorLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: BorderSide(color: scheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        hintStyle: const TextStyle(color: AppTheme.textMutedLight),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppTheme.cardColorLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLarge)),
        elevation: 8,
        shadowColor: Colors.black26,
      ),
      listTileTheme: ListTileThemeData(
        selectedTileColor: scheme.primaryColor.withOpacity(0.15),
        selectedColor: scheme.primaryColor,
        iconColor: AppTheme.textSecondaryLight,
        textColor: AppTheme.textPrimaryLight,
        tileColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppTheme.cardColorLight,
        contentTextStyle: const TextStyle(color: AppTheme.textPrimaryLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primaryColor),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primaryColor,
        inactiveTrackColor: AppTheme.glassColorLight,
        thumbColor: scheme.primaryColor,
        overlayColor: scheme.primaryColor.withAlpha(51),
        trackHeight: 4,
      ),
    );
  }
}
