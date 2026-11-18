import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/screens/manage_screen.dart';
import 'package:kratom_tracker_plus/screens/privacy_policy_screen.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    launchSupportUrl = launchUrl;
  });

  // Settings labels use sentence case throughout the grouped list.
  testWidgets('support link surfaces an error when launchUrl returns false',
      (tester) async {
    launchSupportUrl = (url, {mode = LaunchMode.platformDefault}) async => false;

    await _pumpManage(tester);
    await tester.scrollUntilVisible(find.text('Support development'), 300);
    await tester.tap(find.text('Support development'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open link'), findsOneWidget);
  });

  testWidgets('support link surfaces an error when launchUrl throws',
      (tester) async {
    launchSupportUrl = (url, {mode = LaunchMode.platformDefault}) async {
      throw Exception('no browser');
    };

    await _pumpManage(tester);
    await tester.scrollUntilVisible(find.text('Support development'), 300);
    await tester.tap(find.text('Support development'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not open link'), findsOneWidget);
    expect(find.textContaining('no browser'), findsOneWidget);
  });

  testWidgets('privacy policy still navigates from Manage', (tester) async {
    await _pumpManage(tester);
    await tester.scrollUntilVisible(find.text('Privacy policy'), 300);
    await tester.tap(find.text('Privacy policy'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.text('Data collection and storage'), findsOneWidget);
  });

  testWidgets('appearance choices persist and reminders are absent',
      (tester) async {
    await _pumpManage(tester);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Dosage Reminders'), findsNothing);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('themeMode'), 'light');
  });

  // Corrupt settings JSON makes KratomProvider.create report load warnings;
  // Manage must surface them in the persistent notice at the top.
  testWidgets('load warnings show a persistent notice', (tester) async {
    await _pumpManage(tester, initialValues: {'settings': '{not json'});

    expect(find.byKey(const Key('manage-load-warnings')), findsOneWidget);
    expect(
      find.text('Some saved data could not be loaded'),
      findsOneWidget,
    );
    // Each provider warning renders as a line prefixed with an en dash.
    expect(find.textContaining('– '), findsWidgets);
    expect(
      find.textContaining('Saved settings were damaged'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpManage(
  WidgetTester tester, {
  Map<String, Object> initialValues = const {},
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  final provider = await KratomProvider.create(prefs);

  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider.value(value: provider),
      ],
      child: MaterialApp(
        theme: ThemeProvider.darkTheme,
        home: const ManageScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
