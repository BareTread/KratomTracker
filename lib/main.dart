import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/kratom_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/manage_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/strains_screen.dart';

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
          theme: ThemeProvider.lightTheme,
          darkTheme: ThemeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
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
  void initState() {
    super.initState();
    // Once per launch: if storage reported load problems, say so where the
    // person is, before they log a day of doses without knowing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final warnings = context.read<KratomProvider>().loadWarnings;
      if (warnings.isEmpty) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: const Text(
            'Some saved data could not be loaded. Details in Manage.',
          ),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () => _onItemTapped(3),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: _TabBar(
        selectedIndex: _selectedIndex,
        onSelected: _onItemTapped,
      ),
    );
  }
}

/// The tab bar, drawn rather than Material's: no pill. The active tab is ink
/// with one small cyan dot under its label; the others are muted.
class _TabBar extends StatelessWidget {
  const _TabBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _tabs = [
    (icon: Icons.home_outlined, active: Icons.home, label: 'Home'),
    (icon: Icons.spa_outlined, active: Icons.spa, label: 'Strains'),
    (icon: Icons.bar_chart_outlined, active: Icons.bar_chart, label: 'Stats'),
    (icon: Icons.tune_outlined, active: Icons.tune, label: 'Manage'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: c.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _TabItem(
                    icon: i == selectedIndex ? _tabs[i].active : _tabs[i].icon,
                    label: _tabs[i].label,
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ink = selected ? c.textPrimary : c.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 32,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: ink),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppType.sans,
                fontSize: 11.5,
                letterSpacing: 0.2,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: ink,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? c.accent : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
