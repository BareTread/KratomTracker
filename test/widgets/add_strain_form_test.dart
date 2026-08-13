import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kratom_tracker_plus/providers/kratom_provider.dart';
import 'package:kratom_tracker_plus/providers/theme_provider.dart';
import 'package:kratom_tracker_plus/widgets/add_strain_form.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('selecting a strain type reveals that type color palette',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final provider =
        await KratomProvider.create(await SharedPreferences.getInstance());
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: MaterialApp(
          theme: ThemeProvider.darkTheme,
          home: const Scaffold(body: AddStrainForm()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forest'), findsOneWidget);
    expect(find.text('Ruby'), findsNothing);

    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Radio<String> && widget.value == 'Red',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forest'), findsNothing);
    expect(find.text('Ruby'), findsOneWidget);
  });
}
