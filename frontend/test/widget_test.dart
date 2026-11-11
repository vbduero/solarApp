// Solar-Grow - Test básico del widget principal
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_grow/main.dart';

void main() {
  testWidgets('Solar-Grow app se inicia correctamente', (
    WidgetTester tester,
  ) async {
    // Sin token guardado: tras el splash la app navega al login
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SolarGrowApp());
    // Verificar que el splash screen se carga
    expect(find.text('Solar-Grow'), findsOneWidget);

    // Dejar que terminen los temporizadores del splash (300 ms + 600 ms + 2 s)
    // para que no queden pendientes al cerrar la prueba
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 2));
  });
}
