import 'package:carman_app/shared/widgets/carman_image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('una URL de documentación no dispara una descarga de imagen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CarmanImage('https://example.com/foto.jpg')),
      ),
    );

    expect(find.byIcon(Icons.directions_car_filled_rounded), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
