// Solar-Grow - Prueba de la ruta REAL '/plant-diagnoses' de main.dart
// Spec 002 · hallazgos 1 y 3 (D6, D7, D10).
//
// No hace falta cambiar main.dart: se monta SolarGrowApp completa y se empuja
// la ruta con el NavigatorState del MaterialApp real.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_grow/main.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/providers/diagnosis_provider.dart';
import 'package:solar_grow/screens/plant/diagnosis_history_screen.dart';

/// Deja correr los temporizadores del splash (300 ms + 600 ms + 2 s) con la
/// ruta de diagnósticos ya cerrada, para que no queden pendientes.
Future<void> drainSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(seconds: 2));
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pushRoute(WidgetTester tester, {Object? arguments}) async {
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/plant-diagnoses', arguments: arguments);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> closeRoute(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await drainSplash(tester);
  }

  testWidgets(
    'la ruta /plant-diagnoses sin argumentos muestra Planta no encontrada y no pide diagnósticos',
    (tester) async {
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(const SolarGrowApp());
        await pushRoute(tester);

        expect(tester.takeException(), isNull);
        expect(find.text('Planta no encontrada'), findsOneWidget);
        expect(find.byType(DiagnosisHistoryScreen), findsNothing);

        await closeRoute(tester);
      }, () => MockClient((r) async {
        requests.add(r);
        return http.Response('[]', 200);
      }));
      expect(requests.where((r) => r.url.path.contains('/api/ai/diagnosis')),
          isEmpty);
    },
  );

  testWidgets(
    'la ruta /plant-diagnoses con un argumento que no es PlantModel muestra Planta no encontrada y no pide diagnósticos',
    (tester) async {
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(const SolarGrowApp());
        await pushRoute(tester, arguments: 'no soy una planta');

        expect(tester.takeException(), isNull);
        expect(find.text('Planta no encontrada'), findsOneWidget);
        expect(find.byType(DiagnosisHistoryScreen), findsNothing);

        await closeRoute(tester);
      }, () => MockClient((r) async {
        requests.add(r);
        return http.Response('[]', 200);
      }));
      expect(requests.where((r) => r.url.path.contains('/api/ai/diagnosis')),
          isEmpty);
    },
  );

  testWidgets(
    'la ruta /plant-diagnoses con un PlantModel muestra el historial de esa planta con su propio DiagnosisProvider',
    (tester) async {
      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(const SolarGrowApp());
        await pushRoute(
          tester,
          arguments: PlantModel(id: 7, commonName: 'Echeveria'),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(DiagnosisHistoryScreen), findsOneWidget);
        expect(find.text('Planta no encontrada'), findsNothing);
        expect(find.text('Diagnósticos'), findsOneWidget);
        expect(find.text('Echeveria'), findsOneWidget);

        // Pidió los diagnósticos de la planta 7, una sola vez
        final asked = requests
            .where((r) => r.url.path == '/api/ai/diagnosis/7')
            .toList();
        expect(asked, hasLength(1));

        // El provider es local a la pantalla (D6): existe bajo la pantalla y
        // NO en el MultiProvider global de la app.
        final screen = tester.element(find.byType(DiagnosisHistoryScreen));
        expect(screen.read<DiagnosisProvider>(), isA<DiagnosisProvider>());
        final appContext = tester.element(find.byType(MaterialApp));
        expect(
          () => appContext.read<DiagnosisProvider>(),
          throwsA(isA<ProviderNotFoundException>()),
        );

        await closeRoute(tester);
      }, () => MockClient((r) async {
        requests.add(r);
        return http.Response(
          jsonEncode([]),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }));
    },
  );
}
