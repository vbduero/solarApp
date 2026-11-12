// Solar-Grow - Pruebas de DiagnosisModel y DiagnosisProvider sin red (MockClient)
// Spec 002 · CA-10, CA-12, CA-14 y CA-15
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_grow/models/diagnosis_model.dart';
import 'package:solar_grow/providers/diagnosis_provider.dart';
import 'package:solar_grow/services/api_service.dart';

const loadErrorText = 'No se pudieron cargar los diagnósticos.';

/// Diagnóstico tal como lo devuelve GET /api/ai/diagnosis/{plant_id}
/// (incluye columnas que el modelo debe ignorar).
Map<String, dynamic> diagJson({
  required int id,
  required String createdAt,
  int plantId = 7,
  String healthStatus = 'Buena',
  String? diagnosis = 'ESTADO GENERAL: Saludable',
  bool withImage = true,
  String? imageUrl,
}) {
  return {
    'id': id,
    'plant_id': plantId,
    'health_status': healthStatus,
    'diagnosis': diagnosis,
    'image_url': withImage
        ? (imageUrl ?? '/static/diagnosticos/diag_${plantId}_$id.jpg')
        : null,
    'confidence': 87.5,
    'detected_issues': null,
    'suggested_actions': null,
    'created_at': createdAt,
  };
}

http.Response jsonResponse(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

Future<T> withApi<T>(
  Future<http.Response> Function(http.Request request) handler,
  Future<T> Function() action,
) {
  return http.runWithClient(action, () => MockClient(handler));
}

void main() {
  group('DiagnosisModel', () {
    test(
      'healthLabel muestra Crítica con tilde y deja los demás valores igual',
      () {
        String labelOf(String status) => DiagnosisModel.fromJson(
          diagJson(
            id: 1,
            createdAt: '2026-11-11T12:00:00Z',
            healthStatus: status,
          ),
        ).healthLabel;

        expect(labelOf('Critica'), 'Crítica');
        expect(labelOf('Excelente'), 'Excelente');
        expect(labelOf('Buena'), 'Buena');
        expect(labelOf('Regular'), 'Regular');
        expect(labelOf('Mala'), 'Mala');
        // Un valor desconocido se muestra tal cual
        expect(labelOf('Rara'), 'Rara');
      },
    );

    test('fromJson lee los campos en snake_case y deja healthStatus tal cual', () {
      final d = DiagnosisModel.fromJson(
        diagJson(
          id: 5,
          plantId: 7,
          healthStatus: 'Critica',
          diagnosis: 'Texto completo',
          imageUrl: '/static/diagnosticos/diag_7_ab12cd34.jpg',
          createdAt: '2026-11-11T12:00:00Z',
        ),
      );
      expect(d.id, 5);
      expect(d.plantId, 7);
      expect(d.healthStatus, 'Critica');
      expect(d.diagnosis, 'Texto completo');
      expect(d.imageUrl, '/static/diagnosticos/diag_7_ab12cd34.jpg');

      final sinTexto = DiagnosisModel.fromJson(
        diagJson(
          id: 6,
          diagnosis: null,
          withImage: false,
          createdAt: '2026-11-11T12:00:00Z',
        ),
      );
      expect(sinTexto.diagnosis, isNull);
      expect(sinTexto.imageUrl, isNull);
    });

    test('fromJson lee una fecha sin zona como UTC y una con zona tal cual', () {
      final expected = DateTime.utc(2026, 11, 11, 12);

      // SQLite: sin zona -> se interpreta como UTC
      final sinZona = DiagnosisModel.fromJson(
        diagJson(id: 1, createdAt: '2026-11-11T12:00:00'),
      );
      expect(sinZona.createdAt.isAtSameMomentAs(expected), isTrue);

      // Con fracción de segundo y sin zona (formato de SQLAlchemy/Pydantic)
      final conFraccion = DiagnosisModel.fromJson(
        diagJson(id: 2, createdAt: '2026-11-11T12:00:00.250000'),
      );
      expect(
        conFraccion.createdAt.isAtSameMomentAs(
          DateTime.utc(2026, 11, 11, 12, 0, 0, 250),
        ),
        isTrue,
      );

      // PostgreSQL: con Z
      final conZ = DiagnosisModel.fromJson(
        diagJson(id: 3, createdAt: '2026-11-11T12:00:00Z'),
      );
      expect(conZ.createdAt.isAtSameMomentAs(expected), isTrue);

      // PostgreSQL: con desfase, es el mismo instante
      final conDesfase = DiagnosisModel.fromJson(
        diagJson(id: 4, createdAt: '2026-11-11T07:00:00-05:00'),
      );
      expect(conDesfase.createdAt.isAtSameMomentAs(expected), isTrue);
    });
  });

  group('DiagnosisProvider.loadDiagnoses', () {
    test(
      'loadDiagnoses pide /api/ai/diagnosis/7 y ordena del más reciente al más antiguo desempatando por id',
      () async {
        final provider = DiagnosisProvider();
        late http.Request sent;

        final ok = await withApi(
          (request) async {
            sent = request;
            // El API responde en un orden cualquiera
            return jsonResponse([
              diagJson(id: 1, createdAt: '2026-11-11T08:00:00Z'),
              diagJson(id: 4, createdAt: '2026-11-11T10:00:00'),
              diagJson(id: 3, createdAt: '2026-11-11T12:00:00Z'),
              diagJson(id: 5, createdAt: '2026-11-11T10:00:00Z'),
              // 10:30 UTC escrito con otro desfase
              diagJson(id: 2, createdAt: '2026-11-11T05:30:00-05:00'),
            ]);
          },
          () => provider.loadDiagnoses(7),
        );

        expect(ok, isTrue);
        expect(sent.method, 'GET');
        expect(sent.url.path, '/api/ai/diagnosis/7');
        expect(provider.diagnoses.map((d) => d.id), [3, 2, 5, 4, 1]);
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
        expect(provider.diagnoses.first, isA<DiagnosisModel>());
      },
    );

    test('con una lista vacía devuelve true y no deja error', () async {
      final provider = DiagnosisProvider();
      final ok = await withApi(
        (_) async => jsonResponse(<Object>[]),
        () => provider.loadDiagnoses(7),
      );
      expect(ok, isTrue);
      expect(provider.diagnoses, isEmpty);
      expect(provider.error, isNull);
      expect(provider.isLoading, isFalse);
    });

    test(
      'si el API falla devuelve false, vacía la lista y deja el mensaje exacto',
      () async {
        final provider = DiagnosisProvider();

        final first = await withApi(
          (_) async => jsonResponse([
            diagJson(id: 1, createdAt: '2026-11-11T12:00:00Z'),
          ]),
          () => provider.loadDiagnoses(7),
        );
        expect(first, isTrue);
        expect(provider.diagnoses, hasLength(1));

        // Error HTTP del servidor
        final http500 = await withApi(
          (_) async => jsonResponse({'detail': 'Error interno'}, status: 500),
          () => provider.loadDiagnoses(7),
        );
        expect(http500, isFalse);
        expect(provider.diagnoses, isEmpty);
        expect(provider.error, loadErrorText);
        expect(provider.isLoading, isFalse);

        // Un nuevo intento correcto limpia el error
        final retried = await withApi(
          (_) async => jsonResponse([
            diagJson(id: 2, createdAt: '2026-11-11T12:00:00Z'),
          ]),
          () => provider.loadDiagnoses(7),
        );
        expect(retried, isTrue);
        expect(provider.error, isNull);
        expect(provider.diagnoses.map((d) => d.id), [2]);

        // 404 (planta ajena o borrada)
        final http404 = await withApi(
          (_) async =>
              jsonResponse({'detail': 'Planta no encontrada'}, status: 404),
          () => provider.loadDiagnoses(7),
        );
        expect(http404, isFalse);
        expect(provider.diagnoses, isEmpty);
        expect(provider.error, loadErrorText);

        // Servidor caído (excepción de red, no respuesta HTTP)
        final offline = await withApi(
          (_) async => throw http.ClientException('sin conexión'),
          () => provider.loadDiagnoses(7),
        );
        expect(offline, isFalse);
        expect(provider.diagnoses, isEmpty);
        expect(provider.error, loadErrorText);
        expect(provider.isLoading, isFalse);
      },
    );

    test('al empezar una carga vacía los diagnósticos anteriores', () async {
      final provider = DiagnosisProvider();
      final gate = Completer<void>();

      await withApi(
        (request) async {
          if (request.url.path == '/api/ai/diagnosis/8') {
            await gate.future;
            return jsonResponse([
              diagJson(id: 20, plantId: 8, createdAt: '2026-11-11T12:00:00Z'),
            ]);
          }
          return jsonResponse([
            diagJson(id: 10, createdAt: '2026-11-11T12:00:00Z'),
          ]);
        },
        () async {
          // Planta 7 cargada con un diagnóstico
          expect(await provider.loadDiagnoses(7), isTrue);
          expect(provider.diagnoses.map((d) => d.id), [10]);

          // Se abre la planta 8 y su respuesta aún no llega
          final pending = provider.loadDiagnoses(8);
          expect(provider.diagnoses, isEmpty);
          expect(provider.isLoading, isTrue);
          expect(provider.error, isNull);

          gate.complete();
          expect(await pending, isTrue);
        },
      );

      expect(provider.diagnoses.map((d) => d.id), [20]);
      expect(provider.isLoading, isFalse);
    });

    test('al empezar una carga borra el error anterior y notifica', () async {
      final provider = DiagnosisProvider();
      final gate = Completer<void>();

      await withApi(
        (request) async {
          if (request.url.path == '/api/ai/diagnosis/8') {
            await gate.future;
            return jsonResponse(<Object>[]);
          }
          return jsonResponse({'detail': 'Error interno'}, status: 500);
        },
        () async {
          expect(await provider.loadDiagnoses(7), isFalse);
          expect(provider.error, loadErrorText);

          var notifications = 0;
          provider.addListener(() => notifications++);

          final pending = provider.loadDiagnoses(8);
          expect(provider.error, isNull);
          expect(provider.isLoading, isTrue);
          expect(notifications, greaterThanOrEqualTo(1));

          gate.complete();
          await pending;
        },
      );
      expect(provider.isLoading, isFalse);
    });

    test(
      'si una respuesta anterior llega tarde se conserva la de la última petición',
      () async {
        final provider = DiagnosisProvider();
        final slowGate = Completer<void>();

        await withApi(
          (request) async {
            if (request.url.path == '/api/ai/diagnosis/7') {
              await slowGate.future; // la primera petición llega tarde
              return jsonResponse([
                diagJson(id: 101, createdAt: '2026-11-11T12:00:00Z'),
              ]);
            }
            return jsonResponse([
              diagJson(id: 201, plantId: 8, createdAt: '2026-11-11T12:00:00Z'),
              diagJson(id: 202, plantId: 8, createdAt: '2026-11-11T13:00:00Z'),
            ]);
          },
          () async {
            final slow = provider.loadDiagnoses(7);
            final fast = provider.loadDiagnoses(8);

            expect(await fast, isTrue);
            expect(provider.diagnoses.map((d) => d.id), [202, 201]);

            slowGate.complete();
            await slow;
          },
        );

        // La respuesta tardía de la planta 7 no pisa a la última petición
        expect(provider.diagnoses.map((d) => d.id), [202, 201]);
        expect(provider.isLoading, isFalse);
        expect(provider.error, isNull);
      },
    );

    test(
      'si una respuesta anterior llega tarde y falla no pisa los datos de la última petición',
      () async {
        final provider = DiagnosisProvider();
        final slowGate = Completer<void>();

        await withApi(
          (request) async {
            if (request.url.path == '/api/ai/diagnosis/7') {
              await slowGate.future; // la petición vieja falla ya con otra en pie
              throw http.ClientException('sin conexión');
            }
            return jsonResponse([
              diagJson(id: 201, plantId: 8, createdAt: '2026-11-11T12:00:00Z'),
            ]);
          },
          () async {
            final slow = provider.loadDiagnoses(7);
            final fast = provider.loadDiagnoses(8);

            expect(await fast, isTrue);
            expect(provider.diagnoses.map((d) => d.id), [201]);

            slowGate.complete();
            await slow;
          },
        );

        // El error de la petición vieja se descarta
        expect(provider.diagnoses.map((d) => d.id), [201]);
        expect(provider.error, isNull);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'al terminar la última petición isLoading queda en false aunque una anterior siga abierta',
      () async {
        final provider = DiagnosisProvider();
        final gate = Completer<void>();

        await withApi(
          (request) async {
            if (request.url.path == '/api/ai/diagnosis/7') {
              await gate.future;
              return jsonResponse(<Object>[]);
            }
            return jsonResponse([
              diagJson(id: 201, plantId: 8, createdAt: '2026-11-11T12:00:00Z'),
            ]);
          },
          () async {
            final slow = provider.loadDiagnoses(7);
            await provider.loadDiagnoses(8);
            // La última terminó: no queda cargando aunque la vieja siga abierta
            expect(provider.isLoading, isFalse);
            gate.complete();
            await slow;
            expect(provider.isLoading, isFalse);
          },
        );
      },
    );
  });

  group('DiagnosisProvider.imageUrlFor', () {
    test('imageUrlFor arma la URL con image_url y devuelve null sin imagen', () {
      final provider = DiagnosisProvider();

      final withPhoto = DiagnosisModel.fromJson(
        diagJson(
          id: 1,
          imageUrl: '/static/diagnosticos/diag_7_ab12cd34.jpg',
          createdAt: '2026-11-11T12:00:00Z',
        ),
      );
      expect(
        provider.imageUrlFor(withPhoto),
        '${ApiService.baseUrl}/static/diagnosticos/diag_7_ab12cd34.jpg',
      );

      final otherPhoto = DiagnosisModel.fromJson(
        diagJson(
          id: 2,
          imageUrl: '/static/diagnosticos/diag_7_ffffffff.jpg',
          createdAt: '2026-11-11T12:00:00Z',
        ),
      );
      expect(
        provider.imageUrlFor(otherPhoto),
        isNot(provider.imageUrlFor(withPhoto)),
      );

      final withoutPhoto = DiagnosisModel.fromJson(
        diagJson(id: 3, withImage: false, createdAt: '2026-11-11T12:00:00Z'),
      );
      expect(provider.imageUrlFor(withoutPhoto), isNull);
    });
  });
}
