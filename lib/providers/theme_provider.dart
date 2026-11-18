import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  /// Current key: 'system' | 'light' | 'dark'.
  static const String themeModeKey = 'themeMode';

  /// Legacy on/off key from before the three-way choice. Still read so an
  /// existing install keeps what it had; never written again.
  static const String _legacyDarkModeKey = 'darkMode';

  final SharedPreferences _prefs;
  ThemeMode _themeMode;

  ThemeProvider(this._prefs) : _themeMode = _read(_prefs);

  static ThemeMode _read(SharedPreferences prefs) {
    switch (prefs.getString(themeModeKey)) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
    }
    final legacy = prefs.getBool(_legacyDarkModeKey);
    if (legacy != null) return legacy ? ThemeMode.dark : ThemeMode.light;
    if (prefs.containsKey(themeModeKey)) return ThemeMode.system;
    if (const ['strains', 'dosages', 'settings', 'user_name']
        .any(prefs.containsKey)) {
      prefs.setString(themeModeKey, ThemeMode.dark.name);
      return ThemeMode.dark;
    }
    // Fresh install: record the choice now, or the data keys written during
    // this first run would make the next launch look like an old install
    // and flip it to dark.
    prefs.setString(themeModeKey, ThemeMode.system.name);
    return ThemeMode.system;
  }

  /// System / Light / Dark, as chosen in Manage. Fed to
  /// `MaterialApp.themeMode`, which pairs it with [lightTheme]/[darkTheme].
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(themeModeKey, mode.name);
  }

  static final ThemeData darkTheme = _build(
    Brightness.dark,
    AppColors.dark,
    scaffold: const Color(0xFF0D0E0C),
    secondary: const Color(0xFF80CBC4),
  );

  static final ThemeData lightTheme = _build(
    Brightness.light,
    AppColors.light,
    scaffold: const Color(0xFFF4F1E8),
    secondary: const Color(0xFF00796B),
  );

  /// One builder for both brightnesses so the two themes cannot drift apart
  /// the way two hand-copied blocks do.
  static ThemeData _build(
    Brightness brightness,
    AppColors c, {
    required Color scaffold,
    required Color secondary,
  }) {
    final dark = brightness == Brightness.dark;
    final base = (dark ? ThemeData.dark() : ThemeData.light()).textTheme.apply(
          fontFamily: AppType.sans,
          bodyColor: c.textPrimary,
          displayColor: c.textPrimary,
        );
    final textTheme = base.copyWith(
      // Supporting copy (ListTile subtitles, dialog bodies) steps down one
      // tone so titles lead.
      bodyMedium: base.bodyMedium?.copyWith(color: c.textSecondary),
      titleMedium: base.titleMedium?.copyWith(color: c.textSecondary),
      headlineSmall: AppType.display(
        size: 30,
        color: c.textPrimary,
        height: 1.1,
      ),
    );
    final fieldBorder = dark ? BorderSide.none : BorderSide(color: c.hairline);
    OutlineInputBorder field(BorderSide side) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: side,
        );

    return ThemeData(
      brightness: brightness,
      fontFamily: AppType.sans,
      scaffoldBackgroundColor: scaffold,
      extensions: [c],
      textTheme: textTheme,
      colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light())
          .copyWith(
        primary: c.accent,
        secondary: secondary,
        surface: c.surfaceRaised,
        surfaceTint: Colors.transparent,
        onSurface: c.textPrimary,
        onSurfaceVariant: c.textSecondary,
        outline: c.hairline,
        outlineVariant: c.hairline,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        titleTextStyle: TextStyle(
          fontFamily: AppType.sans,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: AppType.sans,
          fontSize: 13.5,
          height: 1.3,
          color: c.textTertiary,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surfaceRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.hairline),
        ),
      ),
      // A tinted pill behind the active icon, so the tab is not told apart by
      // colour alone.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 66,
        indicatorColor: c.accent.withValues(alpha: 0.18),
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? c.accent
                : c.textTertiary,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppType.sans,
            fontSize: 11.5,
            letterSpacing: 0.2,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? c.accent
                : c.textTertiary,
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.textPrimary,
      ),
      dividerTheme: DividerThemeData(color: c.hairline, space: 1, thickness: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceRaised,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: AppType.display(size: 26, color: c.textPrimary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        modalBackgroundColor: c.surfaceRaised,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (dark ? c.textPrimary : Colors.white)
              : c.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? c.accent
              : c.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : c.hairline,
        ),
      ),
      // Without this, Material's default snackbar is a near-white bar, which
      // is jarring in an app that is otherwise black.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? c.surfaceRaised : c.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: AppType.sans,
          color: dark ? c.textPrimary : const Color(0xFFF1EEE4),
        ),
        actionTextColor: dark ? c.accent : c.accentMuted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceSunken,
        border: field(fieldBorder),
        enabledBorder: field(fieldBorder),
        focusedBorder: field(BorderSide(color: c.accent)),
      ),
    );
  }
}
