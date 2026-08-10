import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ThemeProvider with ChangeNotifier {
  static const String _darkModeKey = 'darkMode';

  final SharedPreferences _prefs;
  bool _isDarkMode;

  ThemeProvider(this._prefs)
      : _isDarkMode = _prefs.getBool(_darkModeKey) ?? true;

  bool get isDarkMode => _isDarkMode;
  ThemeData get theme => _isDarkMode ? darkTheme : lightTheme;

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _prefs.setBool(_darkModeKey, _isDarkMode);
    notifyListeners();
  }

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF090B0C),
    extensions: const [AppColors.dark],
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF00ACC1),
      secondary: Color(0xFF80CBC4),
      surface: Color(0xFF171A1D),
      surfaceTint: Colors.transparent,
      onSurface: Color(0xFFF5F7F8),
    ),
    cardTheme: CardThemeData(
      color: AppColors.dark.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color(0xFF090B0C),
      selectedItemColor: Color(0xFF00ACC1),
      unselectedItemColor: Color(0xFF7B878E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF171A1D),
      elevation: 0,
      foregroundColor: Color(0xFFF5F7F8),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.dark.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF171A1D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.dark.surfaceSunken,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00ACC1)),
      ),
    ),
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF7FAFA),
    extensions: const [AppColors.light],
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF00ACC1),
      secondary: Color(0xFF00796B),
      surface: Color(0xFFFFFFFF),
      surfaceTint: Colors.transparent,
      onSurface: Color(0xFF172125),
    ),
    cardTheme: CardThemeData(
      color: AppColors.light.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: Color(0xFF00ACC1),
      unselectedItemColor: Color(0xFF7B898F),
      elevation: 8,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: Color(0xFF172125),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.light.surfaceRaised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.light.surfaceSunken,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD7E0E3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD7E0E3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00ACC1)),
      ),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Color(0xFF172125)),
      bodyMedium: TextStyle(color: Color(0xFF526168)),
      titleLarge: TextStyle(color: Color(0xFF172125)),
      titleMedium: TextStyle(color: Color(0xFF526168)),
    ),
  );
}
