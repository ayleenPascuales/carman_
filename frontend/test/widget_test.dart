import 'package:carman_app/shared/widgets/carman_logo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Carman brand lockup renders the wordmark', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: CarmanLogo())),
      ),
    );

    expect(find.text('Carman'), findsOneWidget);
    expect(find.text('MOBILITY REIMAGINED'), findsOneWidget);
  });
}
