import 'dart:convert';

import 'package:carman_app/app.dart';
import 'package:carman_app/data/mock/mock_data.dart';
import 'package:carman_app/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'));
    await loader.load();
    await initializeDateFormatting('es');
  });

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const CarmanApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('desktop welcome renders the split layout', (tester) async {
    await pumpAt(tester, const Size(1440, 900));

    expect(find.text('Empezar'), findsOneWidget);
    expect(find.text('Carman'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet welcome stays centered', (tester) async {
    await pumpAt(tester, const Size(820, 1180));

    expect(find.text('Empezar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop authenticated shell shows side navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'carman.session.user': jsonEncode(MockData.demoUser.toJson()),
      'carman.session.token': 'token',
    });
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const CarmanApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Favoritos'), findsOneWidget);
    expect(find.text('Viajes'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
    expect(find.text('Cerca de ti'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile authenticated shell shows bottom navigation', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'carman.session.user': jsonEncode(MockData.demoUser.toJson()),
      'carman.session.token': 'token',
    });
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const CarmanApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Cerca de ti'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
