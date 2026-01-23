import 'package:flutter/material.dart';

enum AppTheme {
  vibrant,
  minimal,
  sunset,
  ocean,
  forest,
}

class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.accentGradient,
    required this.glassBackground,
    required this.glassBorder,
    required this.cardHighlight,
  });

  final LinearGradient accentGradient;
  final Color glassBackground;
  final Color glassBorder;
  final Color cardHighlight;

  static AppThemeTokens vibrant = AppThemeTokens(
    accentGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF38BDF8), Color(0xFFA855F7), Color(0xFFEC4899)],
    ),
    glassBackground: Colors.white.withValues(alpha: 0.08),
    glassBorder: const Color(0xFFA855F7).withValues(alpha: 0.28),
    cardHighlight: const Color(0xFF7C3AED),
  );

  static AppThemeTokens minimal = const AppThemeTokens(
    accentGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFE5E7EB), Color(0xFFF8FAFC), Color(0xFFF8FAFC)],
    ),
    glassBackground: Color(0xCCFFFFFF),
    glassBorder: Color(0x1A0F172A),
    cardHighlight: Color(0xFF2563EB),
  );

  static AppThemeTokens sunset = AppThemeTokens(
    accentGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFFF7A59), Color(0xFFFD3A84), Color(0xFF8A2BE2)],
    ),
    glassBackground: const Color(0xFFFFFFFF).withValues(alpha: 0.10),
    glassBorder: const Color(0xFFFD3A84).withValues(alpha: 0.24),
    cardHighlight: const Color(0xFFFD3A84),
  );

  static AppThemeTokens ocean = AppThemeTokens(
    accentGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF00C6FF), Color(0xFF0072FF), Color(0xFF25D3A3)],
    ),
    glassBackground: const Color(0xFFFFFFFF).withValues(alpha: 0.10),
    glassBorder: const Color(0xFF0072FF).withValues(alpha: 0.22),
    cardHighlight: const Color(0xFF0072FF),
  );

  static AppThemeTokens forest = AppThemeTokens(
    accentGradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF22C55E), Color(0xFF16A34A), Color(0xFF0EA5E9)],
    ),
    glassBackground: const Color(0xFFFFFFFF).withValues(alpha: 0.10),
    glassBorder: const Color(0xFF16A34A).withValues(alpha: 0.22),
    cardHighlight: const Color(0xFF16A34A),
  );

  @override
  AppThemeTokens copyWith({
    LinearGradient? accentGradient,
    Color? glassBackground,
    Color? glassBorder,
    Color? cardHighlight,
  }) {
    return AppThemeTokens(
      accentGradient: accentGradient ?? this.accentGradient,
      glassBackground: glassBackground ?? this.glassBackground,
      glassBorder: glassBorder ?? this.glassBorder,
      cardHighlight: cardHighlight ?? this.cardHighlight,
    );
  }

  @override
  ThemeExtension<AppThemeTokens> lerp(
      ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) return this;
    return AppThemeTokens(
      accentGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: List.generate(3, (index) {
          final current = accentGradient.colors[index];
          final target = other.accentGradient.colors[index];
          return Color.lerp(current, target, t) ?? current;
        }),
      ),
      glassBackground: Color.lerp(glassBackground, other.glassBackground, t) ??
          glassBackground,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t) ?? glassBorder,
      cardHighlight:
          Color.lerp(cardHighlight, other.cardHighlight, t) ?? cardHighlight,
    );
  }
}

class _ThemePreset {
  const _ThemePreset({
    required this.seed,
    required this.scaffold,
    required this.card,
    required this.shadowAlpha,
    required this.tokens,
    this.buttonShadowAlpha = 0.18,
    this.cardElevation = 3,
    this.buttonElevation = 4,
  });

  final Color seed;
  final Color scaffold;
  final Color card;
  final double shadowAlpha;
  final double buttonShadowAlpha;
  final double cardElevation;
  final double buttonElevation;
  final AppThemeTokens tokens;
}

final Map<AppTheme, _ThemePreset> _themePresets = {
  AppTheme.vibrant: _ThemePreset(
    seed: const Color(0xFF7C3AED),
    scaffold: const Color(0xFFF5F1FF),
    card: Colors.white.withValues(alpha: 0.92),
    shadowAlpha: 0.18,
    tokens: AppThemeTokens.vibrant,
  ),
  AppTheme.minimal: _ThemePreset(
    seed: const Color(0xFF2563EB),
    scaffold: const Color(0xFFF7FBFF),
    card: const Color(0xFFF0F6FF),
    shadowAlpha: 0.08,
    buttonShadowAlpha: 0.12,
    cardElevation: 1,
    buttonElevation: 2,
    tokens: AppThemeTokens.minimal,
  ),
  AppTheme.sunset: _ThemePreset(
    seed: const Color(0xFFFD3A84),
    scaffold: const Color(0xFFFFF4F7),
    card: Colors.white.withValues(alpha: 0.94),
    shadowAlpha: 0.20,
    tokens: AppThemeTokens.sunset,
  ),
  AppTheme.ocean: _ThemePreset(
    seed: const Color(0xFF0072FF),
    scaffold: const Color(0xFFEFF7FF),
    card: Colors.white.withValues(alpha: 0.94),
    shadowAlpha: 0.18,
    tokens: AppThemeTokens.ocean,
  ),
  AppTheme.forest: _ThemePreset(
    seed: const Color(0xFF16A34A),
    scaffold: const Color(0xFFF2FBF5),
    card: Colors.white.withValues(alpha: 0.94),
    shadowAlpha: 0.18,
    tokens: AppThemeTokens.forest,
  ),
};

ThemeData buildAppTheme(AppTheme theme) {
  final preset = _themePresets[theme] ?? _themePresets[AppTheme.minimal]!;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: preset.seed,
    brightness: Brightness.light,
  );

  final cardColor = preset.card;
  final scaffoldBg = preset.scaffold;
  final shadowColor = preset.seed.withValues(alpha: preset.shadowAlpha);

  return ThemeData(
    useMaterial3: true,
    colorScheme: baseScheme,
    scaffoldBackgroundColor: scaffoldBg,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: baseScheme.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0.5,
      shadowColor: shadowColor,
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: preset.cardElevation,
      shadowColor: shadowColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: cardColor,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: baseScheme.primary,
        foregroundColor: baseScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shadowColor:
            baseScheme.primary.withValues(alpha: preset.buttonShadowAlpha),
        elevation: preset.buttonElevation,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.94),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    sliderTheme: SliderThemeData(
      thumbColor: baseScheme.primary,
      activeTrackColor: baseScheme.primary,
      inactiveTrackColor: baseScheme.primary.withValues(alpha: 0.2),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: baseScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: baseScheme.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    ),
  ).copyWith(
    extensions: [
      preset.tokens,
    ],
  );
}
