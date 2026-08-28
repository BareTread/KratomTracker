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

  testWidgets('support link surfaces an error when launchUrl returns false',
      (tester) async {
    launchSupportUrl = (url, {mode = LaunchMode.platformDefault}) async => false;

    await _pumpManage(tester);
    await tester.scrollUntilVisible(find.text('Support Development'), 300);
    await tester.tap(find.text('Support Development'));
    await tester.pumpAndSettle();

    expect(find.text('Could not open link'), findsOneWidget);
  });

  testWidgets('support link surfaces an error when launchUrl throws',
      (tester) async {
    launchSupportUrl = (url, {mode = LaunchMode.platformDefault}) async {
      throw Exception('no browser');
    };

    await _pumpManage(tester);
    await tester.scrollUntilVisible(find.text('Support Development'), 300);
    await tester.tap(find.text('Support Development'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not open link'), findsOneWidget);
    expect(find.textContaining('no browser'), findsOneWidget);
  });

  testWidgets('privacy policy still navigates from Manage', (tester) async {
    await _pumpManage(tester);
    await tester.scrollUntilVisible(find.text('Privacy Policy'), 300);
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
    expect(find.text('Data Collection and Storage'), findsOneWidget);
  });
}

Future<void> _pumpManage(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
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
