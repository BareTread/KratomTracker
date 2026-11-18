import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ThemeProvider> providerWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return ThemeProvider(await SharedPreferences.getInstance());
  }

  test('new install follows system', () async {
    expect((await providerWith({})).themeMode, ThemeMode.system);
  });

  test('new install stays on system after its first data is written',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(ThemeProvider(prefs).themeMode, ThemeMode.system);
    await prefs.setString('strains', '[]');
    expect(ThemeProvider(prefs).themeMode, ThemeMode.system);
  });

  test('legacy dark mode true selects dark', () async {
    expect((await providerWith({'darkMode': true})).themeMode, ThemeMode.dark);
  });

  test('legacy dark mode false selects light', () async {
    expect((await providerWith({'darkMode': false})).themeMode, ThemeMode.light);
  });

  test('themeMode takes precedence over legacy setting', () async {
    expect(
      (await providerWith({'themeMode': 'system', 'darkMode': true})).themeMode,
      ThemeMode.system,
    );
  });

  test('existing installs without a theme retain and persist dark', () async {
    for (final key in ['strains', 'dosages', 'settings', 'user_name']) {
      final provider = await providerWith({key: ''});
      expect(provider.themeMode, ThemeMode.dark, reason: key);
      expect((await SharedPreferences.getInstance()).getString('themeMode'), 'dark');
    }
  });

  test('stored appearance overrides legacy data and dark mode', () async {
    final provider = await providerWith({
      'themeMode': 'light',
      'darkMode': true,
      'strains': '[]',
    });
    expect(provider.themeMode, ThemeMode.light);
  });

  test('setThemeMode persists the choice', () async {
    final provider = await providerWith({});
    for (final mode in [ThemeMode.light, ThemeMode.dark, ThemeMode.system]) {
      await provider.setThemeMode(mode);
      expect(provider.themeMode, mode);
      expect((await SharedPreferences.getInstance()).getString('themeMode'), mode.name);
    }
  });
}
