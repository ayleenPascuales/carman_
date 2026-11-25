import 'package:carman_app/app.dart';
import 'package:carman_app/providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Happy-path integration test: welcome → login → catalogue → detail →
/// checkout → payment → confirmation.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-Variable.ttf'));
    await loader.load();
    await initializeDateFormatting('es');
    await initializeDateFormatting('es_CO');
  });

  testWidgets('complete booking flow', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
        child: const CarmanApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Empezar'), findsOneWidget);

    // Welcome → login.
    await tester.tap(find.byType(TextButton).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Bienvenido'), findsOneWidget);

    // Fill demo credentials and enter.
    await tester.tap(find.text('Usar acceso demo'));
    await tester.pump();
    await tester.tap(find.text('Entrar'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Cerca de ti'), findsOneWidget);

    // Home → vehicle detail.
    await tester.tap(find.text('Porsche 911 Carrera S').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Reservar ahora'), findsOneWidget);

    // Detail → checkout.
    await tester.tap(find.text('Reservar ahora'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('Confirmar y pagar'), findsOneWidget);

    // Pay with the default Apple Pay method.
    await tester.tap(find.textContaining('Confirmar y pagar'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('¡Reserva confirmada!'), findsOneWidget);
    expect(find.text('Ver mis viajes'), findsOneWidget);
  });
}
