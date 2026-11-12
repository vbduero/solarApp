// Solar-Grow - El detalle de la planta no se desborda con el botón Diagnósticos
// Spec 002 · hallazgo 9 (fila Info / Regar / Diagnósticos a 320 y 360 px).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/providers/auth_provider.dart';
import 'package:solar_grow/providers/plant_provider.dart';
import 'package:solar_grow/screens/plant/plant_detail_screen.dart';

class _FakePlantProvider extends PlantProvider {
  _FakePlantProvider(this.fakeSelected);
  final PlantModel fakeSelected;

  @override
  PlantModel? get selectedPlant => fakeSelected;

  @override
  Future<void> loadSensorData(int plantId) async {}
}

/// Rectángulo del botón (círculo + etiqueta) que contiene la etiqueta dada.
Rect _buttonRect(WidgetTester tester, String label) {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byType(GestureDetector),
  );
  return tester.getRect(button.first);
}

void main() {
  for (final width in [320.0, 360.0]) {
    testWidgets(
      'la fila Info Regar Diagnósticos del detalle no se desborda a ${width.toInt()} px de ancho',
      (tester) async {
        tester.view.physicalSize = Size(width, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        // El detalle tiene otras filas que ya se desbordan en main (fuera de la
        // spec 002): se recogen los errores para que no hagan fallar esta prueba.
        // La fila de botones se valida midiendo su geometría.
        final original = FlutterError.onError;
        final errores = <FlutterErrorDetails>[];
        FlutterError.onError = errores.add;
        try {
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<AuthProvider>(
                  create: (_) => AuthProvider(),
                ),
                ChangeNotifierProvider<PlantProvider>.value(
                  value: _FakePlantProvider(
                    PlantModel(id: 7, commonName: 'Echeveria'),
                  ),
                ),
              ],
              child: const MaterialApp(home: PlantDetailScreen()),
            ),
          );
          await tester.pump();
        } finally {
          FlutterError.onError = original;
        }

        // Solo se toleran errores de desborde (de otras filas); cualquier otro falla
        for (final e in errores) {
          expect(
            e.exceptionAsString(),
            contains('overflowed'),
            reason: 'Error inesperado distinto de un desborde: ${e.exception}',
          );
        }

        expect(find.text('Info'), findsOneWidget);
        expect(find.text('Regar'), findsOneWidget);
        expect(find.text('Diagnósticos'), findsOneWidget);

        // Fila que contiene los tres botones
        final fila = find
            .ancestor(of: find.text('Info'), matching: find.byType(Row))
            .evaluate()
            .map((el) => find.byWidget(el.widget))
            .firstWhere(
              (f) =>
                  find
                      .descendant(of: f, matching: find.text('Regar'))
                      .evaluate()
                      .isNotEmpty &&
                  find
                      .descendant(of: f, matching: find.text('Diagnósticos'))
                      .evaluate()
                      .isNotEmpty,
            );
        final filaRect = tester.getRect(fila);

        final rects = [
          _buttonRect(tester, 'Info'),
          _buttonRect(tester, 'Regar'),
          _buttonRect(tester, 'Diagnósticos'),
        ];
        for (final r in rects) {
          // Dentro de la fila y de la pantalla
          expect(r.left, greaterThanOrEqualTo(filaRect.left - 0.01));
          expect(r.right, lessThanOrEqualTo(filaRect.right + 0.01));
          expect(r.left, greaterThanOrEqualTo(-0.01));
          expect(r.right, lessThanOrEqualTo(width + 0.01));
        }
        // Sin solaparse entre sí
        expect(rects[0].right, lessThanOrEqualTo(rects[1].left + 0.01));
        expect(rects[1].right, lessThanOrEqualTo(rects[2].left + 0.01));

        // Etiquetas dentro de la pantalla
        for (final label in ['Info', 'Regar', 'Diagnósticos']) {
          final t = tester.getRect(find.text(label));
          expect(t.left, greaterThanOrEqualTo(-0.01));
          expect(t.right, lessThanOrEqualTo(width + 0.01));
        }

        // AnimatedPlantWidget deja un temporizador de parpadeo
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 10));
      },
    );
  }
}
