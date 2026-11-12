// Solar-Grow - Pruebas de revisión del DiagnosisProvider (spec 002, ronda 2)
// Hallazgo 2: respuesta que llega con el provider ya destruido.
// Hallazgo 5: image_url vacía se trata como sin foto.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_grow/models/diagnosis_model.dart';
import 'package:solar_grow/providers/diagnosis_provider.dart';

Map<String, dynamic> diagJson(int id, {Object? imageUrl}) => {
  'id': id,
  'plant_id': 7,
  'health_status': 'Buena',
  'diagnosis': 'ESTADO GENERAL: Saludable',
  'image_url': imageUrl,
  'confidence': 87.5,
  'detected_issues': null,
  'suggested_actions': null,
  'created_at': '2026-11-11T12:00:00Z',
};

void main() {
  group('dispose con una carga pendiente (hallazgo 2)', () {
    test(
      'si el provider se destruye y la respuesta buena llega después no lanza ninguna excepción',
      () async {
        final provider = DiagnosisProvider();
        final gate = Completer<http.Response>();
        final requested = Completer<void>();

        final result = http.runWithClient(() async {
          final f = provider.loadDiagnoses(7);
          await requested.future;
          provider.dispose();
          gate.complete(
            http.Response(
              jsonEncode([diagJson(1)]),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          );
          return f;
        }, () => MockClient((_) {
          requested.complete();
          return gate.future;
        }));

        // La llamada no debe fallar con «used after being disposed»
        await expectLater(result, completes);
      },
    );

    test(
      'si el provider se destruye y la respuesta con error llega después no lanza ninguna excepción',
      () async {
        final provider = DiagnosisProvider();
        final gate = Completer<http.Response>();
        final requested = Completer<void>();

        final result = http.runWithClient(() async {
          final f = provider.loadDiagnoses(7);
          await requested.future;
          provider.dispose();
          gate.complete(
            http.Response(
              jsonEncode({'detail': 'Error interno'}),
              500,
              headers: {'content-type': 'application/json; charset=utf-8'},
            ),
          );
          return f;
        }, () => MockClient((_) {
          requested.complete();
          return gate.future;
        }));

        await expectLater(result, completes);
      },
    );
  });

  group('image_url vacía (hallazgo 5)', () {
    test('imageUrlFor con image_url vacía devuelve null', () {
      final provider = DiagnosisProvider();
      final d = DiagnosisModel.fromJson(diagJson(1, imageUrl: ''));
      expect(provider.imageUrlFor(d), isNull);
    });
  });
}
