import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/kratom_provider.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color surfaceRaised;
  final Color surfaceSunken;
  final Color hairline;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color accent;
  final Color accentMuted;
  final Color positive;
  final Color caution;

  const AppColors({
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.hairline,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.accentMuted,
    required this.positive,
    required this.caution,
  });

  static const dark = AppColors(
    surfaceRaised: Color(0xFF171A1D),
    surfaceSunken: Color(0xFF0D0F11),
    hairline: Color(0xFF30363B),
    textPrimary: Color(0xFFF5F7F8),
    textSecondary: Color(0xFFB4BEC4),
    textTertiary: Color(0xFF7B878E),
    accent: Color(0xFF00ACC1),
    accentMuted: Color(0xFF075D68),
    positive: Color(0xFF4CAF70),
    caution: Color(0xFFFFB74D),
  );

  static const light = AppColors(
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFF0F4F5),
    hairline: Color(0xFFD7E0E3),
    textPrimary: Color(0xFF172125),
    textSecondary: Color(0xFF526168),
    textTertiary: Color(0xFF7B898F),
    accent: Color(0xFF00ACC1),
    accentMuted: Color(0xFFB9E8EE),
    positive: Color(0xFF2E7D4F),
    caution: Color(0xFFB56A00),
  );

  @override
  AppColors copyWith({
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? hairline,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? accent,
    Color? accentMuted,
    Color? positive,
    Color? caution,
  }) {
    return AppColors(
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      hairline: hairline ?? this.hairline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      accent: accent ?? this.accent,
      accentMuted: accentMuted ?? this.accentMuted,
      positive: positive ?? this.positive,
      caution: caution ?? this.caution,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      positive: Color.lerp(positive, other.positive, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

class AppMotion {
  const AppMotion._();

  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);
  static const emphasized = Curves.easeOutCubic;
  static const spring = Cubic(0.2, 0.9, 0.25, 1.0);

  static bool reduced(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return true;
    try {
      return Provider.of<KratomProvider>(context, listen: false)
          .settings
          .performanceMode;
    } on ProviderNotFoundException {
      return false;
    }
  }
}
