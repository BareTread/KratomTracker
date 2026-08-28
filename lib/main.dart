import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/kratom_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/manage_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/strains_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Prefs are loaded after [runApp] so a platform failure can render
  // [_ErrorScreen] instead of dying on a pre-widget exception.
  runApp(const AppBootstrap());
}

/// Shown when startup prefs or [KratomProvider.create] fails.
/// Without this the [FutureBuilder] would spin forever.
class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Herbal Tracker+',
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to start',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '$error',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, this.prefs, this.loadPrefs});

  /// Test seam: skip [SharedPreferences.getInstance] when already loaded.
  final SharedPreferences? prefs;

  /// Test seam: force a failing prefs load without going through the plugin.
  @visibleForTesting
  final Future<SharedPreferences> Function()? loadPrefs;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final Future<({ThemeProvider theme, KratomProvider kratom})> _boot =
      _load();

  Future<({ThemeProvider theme, KratomProvider kratom})> _load() async {
    final prefs = widget.prefs ??
        await (widget.loadPrefs ?? SharedPreferences.getInstance)();
    return (
      theme: ThemeProvider(prefs),
      kratom: await KratomProvider.create(prefs),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({ThemeProvider theme, KratomProvider kratom})>(
      future: _boot,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorScreen(error: snapshot.error!);
        }
        if (!snapshot.hasData) {
          return MaterialApp(
            title: 'Herbal Tracker+',
            theme: ThemeProvider.darkTheme,
            home: const _LoadingScreen(),
          );
        }
        final boot = snapshot.requireData;
        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: boot.theme),
            ChangeNotifierProvider.value(value: boot.kratom),
          ],
          child: const MyApp(),
        );
      },
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, KratomProvider>(
      builder: (context, themeProvider, kratomProvider, child) {
        return MaterialApp(
          title: 'Herbal Tracker+',
          theme: themeProvider.theme,
          home: kratomProvider.isReady
              ? const MainScreen()
              : const _LoadingScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const StrainsScreen(),
    const StatsScreen(),
    const ManageScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          selectedItemColor: context.c.accent,
          unselectedItemColor: context.c.textTertiary,
          items: const [
            // Outline when inactive, filled when active — same Material
            // family and optical weight across all four tabs.
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.spa_outlined),
              activeIcon: Icon(Icons.spa),
              label: 'Strains',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Stats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_outlined),
              activeIcon: Icon(Icons.tune),
              label: 'Manage',
            ),
          ],
        ),
      ),
    );
  }
}
