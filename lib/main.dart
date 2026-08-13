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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(AppBootstrap(prefs: prefs));
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late final ThemeProvider _themeProvider = ThemeProvider(widget.prefs);
  late final Future<KratomProvider> _provider =
      KratomProvider.create(widget.prefs);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _themeProvider,
      child: FutureBuilder<KratomProvider>(
        future: _provider,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Consumer<ThemeProvider>(
              builder: (context, theme, child) => MaterialApp(
                title: 'Herbal Tracker+',
                theme: theme.theme,
                home: const _LoadingScreen(),
              ),
            );
          }
          return ChangeNotifierProvider.value(
            value: snapshot.requireData,
            child: const MyApp(),
          );
        },
      ),
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
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.grey,
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
