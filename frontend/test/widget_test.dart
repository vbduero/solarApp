// Solar-Grow - Test básico del widget principal
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_grow/main.dart';

void main() {
  testWidgets('Solar-Grow app se inicia correctamente', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SolarGrowApp());
    // Verificar que el splash screen se carga
    expect(find.text('Solar-Grow'), findsOneWidget);
  });
}
