// Solar-Grow - Botón «Modo Demo (sin servidor)» del login con la app real
// Spec 005 · CA-10 (D4 y nota del plan sobre CA-10).
//
// Se monta SolarGrowApp completa dentro de http.runWithClient con un MockClient
// que responde 500 a todo (servidor caído), como en diagnosis_route_test.dart.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_grow/main.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Modo Demo sin servidor lleva a Inicio con plantas de ejemplo y el aviso',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final requests = <http.Request>[];
      await http.runWithClient(() async {
        await tester.pumpWidget(const SolarGrowApp());
        // Splash: 300 ms + 600 ms + 2 s, y la navegación al login
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(seconds: 2));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        final boton = find.text('Modo Demo (sin servidor)');
        expect(boton, findsOneWidget);
        // Todavía no hay aviso: no se ha entrado a Inicio
        expect(find.byKey(const ValueKey('aviso-modo-demo')), findsNothing);

        await tester.tap(boton);
        await tester.pump();
        await tester.pump();
        // Deja pasar la transición y las peticiones (500) de Inicio
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.byKey(const ValueKey('aviso-modo-demo')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Modo demo: no se pudo conectar con el servidor. Las plantas y tareas que ves son de ejemplo.',
          ),
          findsOneWidget,
        );
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.text('Echeveria'), findsWidgets);

        // Cierra: desmonta y deja pasar el tiempo
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 15));
        expect(tester.takeException(), isNull);
      }, () => MockClient((r) async {
        requests.add(r);
        return http.Response(jsonEncode({'detail': 'x'}), 500);
      }));

      // Inicio sí pidió las plantas (y fallaron: por eso los ejemplos), pero
      // nada tocó la bomba
      expect(requests.where((r) => r.url.path.startsWith('/api/plants')),
          isNotEmpty);
      expect(requests.where((r) => r.url.path.contains('/api/controls')),
          isEmpty);
    },
  );
}
