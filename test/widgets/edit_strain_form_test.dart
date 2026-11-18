import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/widgets/edit_strain_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edit sheet prefills, offers colours and saves to provider', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider = await KratomProvider.create(await SharedPreferences.getInstance());
    await provider.addStrain('Existing', 'EX', 0xFFB71C1C, 'lance');
    final strain = provider.strains.single;
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider.value(value: provider, child: MaterialApp(theme: ThemeProvider.darkTheme, home: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => EditStrainForm(strain: strain)), child: const Text('Open')))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Existing'), findsOneWidget);
    expect(find.text('EX'), findsOneWidget);
    for (final type in ['Green', 'Red', 'White', 'Yellow']) {
      expect(find.text(type), findsOneWidget);
    }
    expect(find.text('Ruby'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Updated');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(provider.strains.single.name, 'Updated');
    expect(provider.strains.single.color, 0xFFB71C1C);
  });
}
