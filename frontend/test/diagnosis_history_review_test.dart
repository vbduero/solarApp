// Solar-Grow - Pruebas de revisión de la pantalla de historial (spec 002, ronda 2)
// Hallazgo 5: image_url vacía -> «Sin foto» y ninguna imagen.
// Hallazgo 4: color por estado (D8), SelectableText (D9) y miniatura de 64 (D8).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solar_grow/config/theme.dart';
import 'package:solar_grow/models/diagnosis_model.dart';
import 'package:solar_grow/providers/diagnosis_provider.dart';
import 'package:solar_grow/screens/plant/diagnosis_history_screen.dart';

/// Provider falso con la lista fija. NO sobreescribe imageUrlFor: se usa la
/// lógica real (así se comprueba el caso de la cadena vacía).
class _FixedProvider extends DiagnosisProvider {
  _FixedProvider(this._list);
  final List<DiagnosisModel> _list;
  bool _loaded = false;

  @override
  List<DiagnosisModel> get diagnoses => _loaded ? _list : [];

  @override
  bool get isLoading => false;

  @override
  String? get error => null;

  @override
  Future<bool> loadDiagnoses(int plantId) async {
    _loaded = true;
    notifyListeners();
    return true;
  }
}

DiagnosisModel _diag(
  int id, {
  String status = 'Buena',
  Object? imageUrl,
  String? text = 'ESTADO GENERAL: Saludable\nRiega cada tres dias.',
}) {
  return DiagnosisModel.fromJson({
    'id': id,
    'plant_id': 7,
    'health_status': status,
    'diagnosis': text,
    'image_url': imageUrl,
    'confidence': 87.5,
    'detected_issues': null,
    'suggested_actions': null,
    'created_at': '2026-11-11T12:00:00Z',
  });
}

Future<void> _pump(WidgetTester tester, List<DiagnosisModel> list) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<DiagnosisProvider>.value(
      value: _FixedProvider(list),
      child: const MaterialApp(
        home: DiagnosisHistoryScreen(plantId: 7, plantName: 'Echeveria'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Color? _colorOf(WidgetTester tester, String label) {
  final text = tester.widget<Text>(
    find.descendant(of: find.byType(Card), matching: find.text(label)),
  );
  return text.style?.color;
}

void main() {
  testWidgets(
    'un diagnóstico con image_url vacía muestra Sin foto y ninguna imagen',
    (tester) async {
      await _pump(tester, [_diag(1, imageUrl: '')]);

      expect(find.byType(Card), findsOneWidget);
      expect(find.text('Sin foto'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets(
    'el estado de cada tarjeta usa el color de D8: success, warning, error y textSecondary',
    (tester) async {
      await _pump(tester, [
        _diag(1, status: 'Excelente'),
        _diag(2, status: 'Buena'),
        _diag(3, status: 'Regular'),
        _diag(4, status: 'Mala'),
        _diag(5, status: 'Critica'),
        _diag(6, status: 'Rara'),
      ]);

      expect(_colorOf(tester, 'Excelente'), SolarColors.success);
      expect(_colorOf(tester, 'Buena'), SolarColors.success);
      expect(_colorOf(tester, 'Regular'), SolarColors.warning);
      expect(_colorOf(tester, 'Mala'), SolarColors.error);
      expect(_colorOf(tester, 'Crítica'), SolarColors.error);
      expect(_colorOf(tester, 'Rara'), SolarColors.textSecondary);
    },
  );

  testWidgets(
    'la miniatura de la tarjeta mide 64 por 64 (D8)',
    (tester) async {
      await _pump(tester, [_diag(1, imageUrl: null)]);

      final size = tester.getSize(
        find.ancestor(of: find.text('Sin foto'), matching: find.byType(Container)).first,
      );
      expect(size, const Size(64, 64));
    },
  );

  testWidgets(
    'el texto del detalle de un diagnóstico es un SelectableText con el texto completo',
    (tester) async {
      const full = 'ESTADO GENERAL: Saludable\nRiega cada tres dias.';
      await _pump(tester, [_diag(1, text: full)]);

      await tester.tap(find.byType(Card));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final selectable = find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == full,
      );
      expect(selectable, findsOneWidget);
      expect(find.text('Cerrar'), findsOneWidget);
    },
  );
}
