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

  // Warm ink rather than cold slate: the neutrals lean a few degrees toward
  // green-brown so the one cool accent reads as chosen, and strain colours
  // sit on a ground that does not fight them.
  static const dark = AppColors(
    surfaceRaised: Color(0xFF161814),
    surfaceSunken: Color(0xFF0A0B09),
    hairline: Color(0xFF2B2E27),
    textPrimary: Color(0xFFF1EEE4),
    textSecondary: Color(0xFFB6B3A5),
    textTertiary: Color(0xFF8B897C),
    accent: Color(0xFF00ACC1),
    accentMuted: Color(0xFF075D68),
    positive: Color(0xFF5DBB7E),
    caution: Color(0xFFF2B04C),
  );

  static const light = AppColors(
    surfaceRaised: Color(0xFFFBFAF5),
    surfaceSunken: Color(0xFFECE8DB),
    hairline: Color(0xFFDAD4C2),
    textPrimary: Color(0xFF1C201B),
    textSecondary: Color(0xFF55594F),
    textTertiary: Color(0xFF686B5F),
    accent: Color(0xFF0592A5),
    accentMuted: Color(0xFFB9E8EE),
    positive: Color(0xFF2E7D4F),
    caution: Color(0xFFA85F00),
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

/// Strain colours are chosen to look right as *fills*. Used as text they fail:
/// the dark reds sit around 0.30 lightness, which is nearly invisible on the
/// near-black surfaces, and the pale whites vanish on light backgrounds.
/// Clamp lightness into a readable band, keeping hue and saturation so the
/// strain stays recognisable.
Color legibleStrainColor(Color color, Brightness brightness) {
  final hsl = HSLColor.fromColor(color);
  final lightness = brightness == Brightness.dark
      ? hsl.lightness.clamp(0.62, 0.92)
      : hsl.lightness.clamp(0.24, 0.46);
  return hsl.withLightness(lightness).toColor();
}

/// A soft chip in a strain's colour: low-alpha fill, colour carried by the
/// text. Reads as identity rather than as an alert, which a saturated red
/// fill does not.
({Color background, Color foreground}) strainChipColors(
  Color strainColor,
  Brightness brightness,
) {
  final foreground = legibleStrainColor(strainColor, brightness);
  return (
    background: foreground.withValues(
      alpha: brightness == Brightness.dark ? 0.16 : 0.14,
    ),
    foreground: foreground,
  );
}

/// Two voices. Hanken Grotesk carries everything that is read or tapped;
/// Instrument Serif is reserved for the figures and titles a person looks at
/// first (a dose amount, a headline number, a screen name). Keeping the serif
/// rare is what makes it feel like a choice rather than a theme.
class AppType {
  const AppType._();

  static const sans = 'Hanken';
  static const serif = 'InstrumentSerif';

  /// Serif figure/title. Instrument Serif is a single, fairly condensed
  /// weight, so size does the work; no fontWeight (faux bold would smear it).
  static TextStyle display({
    required double size,
    required Color color,
    double height = 1.0,
    double letterSpacing = -0.2,
    FontStyle fontStyle = FontStyle.normal,
  }) =>
      TextStyle(
        fontFamily: serif,
        fontSize: size,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
        fontStyle: fontStyle,
        fontWeight: FontWeight.w400,
        fontFeatures: const [FontFeature.liningFigures()],
      );

  /// Small, tracked caps for section labels. Reads as a printed label.
  static TextStyle eyebrow(Color color) => TextStyle(
        fontFamily: sans,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.3,
        height: 1.2,
        color: color,
      );
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
