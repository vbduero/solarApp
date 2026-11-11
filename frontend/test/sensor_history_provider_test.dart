// Solar-Grow - Pruebas de PlantProvider.loadSensorHistory sin red (MockClient)
// Spec 001 · CA-1, CA-3, CA-5 y CA-8
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_grow/models/sensor_reading_model.dart';
import 'package:solar_grow/providers/plant_provider.dart';

/// Lectura tal como la devuelve GET /api/sensors/history/{plant_id}
/// (incluye las columnas de relleno, que el modelo debe ignorar).
Map<String, dynamic> readingJson({
  required int id,
  required DateTime recordedAt,
  Object? temperature = 24.5,
  Object? airHumidity = 55.0,
  Object? soilHumidity = 40.0,
  int plantId = 7,
}) {
  return {
    'id': id,
    'plant_id': plantId,
    'temperature': temperature,
    'air_humidity': airHumidity,
    'soil_humidity': soilHumidity,
    'light_level': 85.0,
    'solar_voltage': 12.4,
    'battery_level': 98.0,
    'pump_active': 0,
    'source': 'esp8266',
    'recorded_at': recordedAt.toUtc().toIso8601String(),
  };
}

http.Response jsonResponse(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Future<T> withApi<T>(
  Future<http.Response> Function(http.Request request) handler,
  Future<T> Function() action,
) {
  return http.runWithClient(action, () => MockClient(handler));
}

void main() {
  final base = DateTime.utc(2026, 11, 11, 12);

  group('loadSensorHistory', () {
    test(
      'loadSensorHistory deja las lecturas en orden ascendente por fecha',
      () async {
        final provider = PlantProvider();

        // El API responde de la más reciente a la más antigua
        final ok = await withApi(
          (_) async => jsonResponse([
            readingJson(
              id: 3,
              recordedAt: base,
              temperature: 26.0,
              airHumidity: 60, // entero: el modelo no debe fallar con int
              soilHumidity: 30.5,
            ),
            readingJson(
              id: 2,
              recordedAt: base.subtract(const Duration(hours: 1)),
            ),
            readingJson(
              id: 1,
              recordedAt: base.subtract(const Duration(hours: 2)),
              temperature: null,
            ),
          ]),
          () => provider.loadSensorHistory(7, hours: 24),
        );

        expect(ok, isTrue);
        expect(provider.sensorHistory.map((r) => r.id), [1, 2, 3]);
        expect(provider.isHistoryLoading, isFalse);
        expect(provider.historyError, isNull);

        final oldest = provider.sensorHistory.first;
        final newest = provider.sensorHistory.last;
        expect(oldest.plantId, 7);
        expect(oldest.temperature, isNull);
        expect(
          oldest.recordedAt.isAtSameMomentAs(
            base.subtract(const Duration(hours: 2)),
          ),
          isTrue,
        );
        expect(newest.temperature, 26.0);
        expect(newest.airHumidity, 60.0);
        expect(newest.soilHumidity, 30.5);
        expect(newest, isA<SensorReadingModel>());
      },
    );

    test('envía GET a /api/sensors/history/7 con hours y limit=200', () async {
      late http.Request sent;

      await withApi((request) async {
        sent = request;
        return jsonResponse(<Object>[]);
      }, () => PlantProvider().loadSensorHistory(7, hours: 168));

      expect(sent.method, 'GET');
      expect(sent.url.path, '/api/sensors/history/7');
      expect(sent.url.queryParameters, {'hours': '168', 'limit': '200'});
    });

    test(
      'si el API falla devuelve false, deja el error y vacía el historial anterior',
      () async {
        final provider = PlantProvider();

        final first = await withApi(
          (_) async => jsonResponse([readingJson(id: 1, recordedAt: base)]),
          () => provider.loadSensorHistory(7, hours: 24),
        );
        expect(first, isTrue);
        expect(provider.sensorHistory, hasLength(1));

        // Error HTTP del servidor
        final failed = await withApi(
          (_) async => jsonResponse({'detail': 'Error interno'}, status: 500),
          () => provider.loadSensorHistory(7, hours: 6),
        );

        expect(failed, isFalse);
        expect(provider.sensorHistory, isEmpty);
        expect(provider.historyError, isNotNull);
        expect(provider.historyError, isNotEmpty);
        expect(provider.isHistoryLoading, isFalse);

        // Un nuevo intento correcto limpia el error
        final retried = await withApi(
          (_) async => jsonResponse([readingJson(id: 2, recordedAt: base)]),
          () => provider.loadSensorHistory(7, hours: 6),
        );
        expect(retried, isTrue);
        expect(provider.historyError, isNull);
        expect(provider.sensorHistory.map((r) => r.id), [2]);

        // Servidor caído (excepción de red, no respuesta HTTP)
        final offline = await withApi(
          (_) async => throw http.ClientException('sin conexión'),
          () => provider.loadSensorHistory(7, hours: 6),
        );
        expect(offline, isFalse);
        expect(provider.sensorHistory, isEmpty);
        expect(provider.historyError, isNotEmpty);
        expect(provider.isHistoryLoading, isFalse);
      },
    );

    test(
      'si una respuesta anterior llega tarde se conserva la de la última petición',
      () async {
        final provider = PlantProvider();
        final slowGate = Completer<void>();

        final provider6hIds = [101];
        final provider24hIds = [201, 202];

        await withApi(
          (request) async {
            if (request.url.queryParameters['hours'] == '6') {
              await slowGate.future; // la respuesta de 6h llega tarde
              return jsonResponse([
                readingJson(id: provider6hIds.first, recordedAt: base),
              ]);
            }
            return jsonResponse([
              readingJson(id: provider24hIds[1], recordedAt: base),
              readingJson(
                id: provider24hIds[0],
                recordedAt: base.subtract(const Duration(hours: 1)),
              ),
            ]);
          },
          () async {
            final slow = provider.loadSensorHistory(7, hours: 6);
            final fast = provider.loadSensorHistory(7, hours: 24);

            await fast;
            expect(provider.sensorHistory.map((r) => r.id), provider24hIds);

            slowGate.complete();
            await slow;
          },
        );

        // La respuesta tardía de 6h no pisa a la última selección (24h)
        expect(provider.sensorHistory.map((r) => r.id), provider24hIds);
        expect(provider.isHistoryLoading, isFalse);
        expect(provider.historyError, isNull);
      },
    );

    test(
      'tras un fallo historyError es exactamente el mensaje de CA-5',
      () async {
        final provider = PlantProvider();

        final http500 = await withApi(
          (_) async => jsonResponse({'detail': 'Error interno'}, status: 500),
          () => provider.loadSensorHistory(7, hours: 24),
        );
        expect(http500, isFalse);
        expect(provider.historyError, 'No se pudieron cargar las estadísticas.');

        final offline = await withApi(
          (_) async => throw http.ClientException('sin conexión'),
          () => provider.loadSensorHistory(7, hours: 24),
        );
        expect(offline, isFalse);
        expect(provider.historyError, 'No se pudieron cargar las estadísticas.');
      },
    );

    test(
      'si una respuesta anterior llega tarde y falla no pisa los datos de la última petición',
      () async {
        final provider = PlantProvider();
        final slowGate = Completer<void>();

        await withApi(
          (request) async {
            if (request.url.queryParameters['hours'] == '6') {
              await slowGate.future; // la petición vieja falla cuando ya hay otra
              throw http.ClientException('sin conexión');
            }
            return jsonResponse([
              readingJson(id: 202, recordedAt: base),
              readingJson(
                id: 201,
                recordedAt: base.subtract(const Duration(hours: 1)),
              ),
            ]);
          },
          () async {
            final slow = provider.loadSensorHistory(7, hours: 6);
            final fast = provider.loadSensorHistory(7, hours: 24);

            expect(await fast, isTrue);
            expect(provider.sensorHistory.map((r) => r.id), [201, 202]);

            slowGate.complete();
            await slow;
          },
        );

        // El error de la petición vieja se descarta
        expect(provider.sensorHistory.map((r) => r.id), [201, 202]);
        expect(provider.historyError, isNull);
        expect(provider.isHistoryLoading, isFalse);
      },
    );

    test(
      'si las respuestas llegan en orden se conserva la de la última petición',
      () async {
        final provider = PlantProvider();
        final firstGate = Completer<void>();

        await withApi(
          (request) async {
            if (request.url.queryParameters['hours'] == '6') {
              await firstGate.future;
              return jsonResponse([readingJson(id: 101, recordedAt: base)]);
            }
            return jsonResponse([readingJson(id: 201, recordedAt: base)]);
          },
          () async {
            final first = provider.loadSensorHistory(7, hours: 6);
            final second = provider.loadSensorHistory(7, hours: 24);
            firstGate.complete();
            await Future.wait([first, second]);
          },
        );

        expect(provider.sensorHistory.map((r) => r.id), [201]);
        expect(provider.isHistoryLoading, isFalse);
      },
    );
  });
}
