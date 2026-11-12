// Solar-Grow - Pruebas de PlantProvider: estado «según sensores» sin recalcular
// Spec 004 · CA-5, CA-8, CA-10 y CA-11 (decisión D6 del plan).
//
// Sin HTTP real: MockClient con las respuestas de clima-actual y de /latest.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_grow/providers/plant_provider.dart';

http.Response _json(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// Respuesta de clima-actual. Los campos de salud solo van si se pasan; con
/// [sinSuelo] se omite `humedad_suelo`.
Map<String, dynamic> _clima({
  String estado = 'En línea',
  int plantId = 7,
  num suelo = 45,
  bool sinSuelo = false,
  num temperatura = 24,
  num aire = 50,
  bool led = false,
  Object? status,
  Object? score,
}) {
  return {
    'estado_conexion': estado,
    'plant_id': plantId,
    'temperatura': temperatura,
    'humedad_aire': aire,
    if (!sinSuelo) 'humedad_suelo': suelo,
    'led_encendido': led,
    'health_status': ?status,
    'health_score': ?score,
  };
}

Map<String, dynamic> _latest({
  num suelo = 40,
  num temperatura = 22,
  Object? status,
  Object? score,
}) {
  return {
    'plant_id': 7,
    'plant_name': 'Echeveria',
    'temperature': temperatura,
    'air_humidity': 50.0,
    'soil_humidity': suelo,
    'light_level': 85.0,
    'solar_voltage': 12.4,
    'battery_level': 98.0,
    'pump_active': 0,
    'health_status': ?status,
    'health_score': ?score,
  };
}

Future<T> _withApi<T>(
  Future<http.Response> Function(http.Request request) handler,
  Future<T> Function() action,
) {
  return http.runWithClient(action, () => MockClient(handler));
}

/// Provider con las plantas 7 y 8 cargadas (la rama en vivo las necesita).
Future<PlantProvider> _providerWithPlants() async {
  final provider = PlantProvider();
  await _withApi((request) async {
    if (request.url.path == '/api/plants/') {
      return _json([
        {
          'id': 7,
          'common_name': 'Echeveria',
          'min_humidity': 25,
          'max_temperature': 35,
        },
        {'id': 8, 'common_name': 'Cactus'},
      ]);
    }
    return _json({'detail': 'no'}, status: 404);
  }, provider.loadPlants);
  expect(provider.plants, hasLength(2));
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('rama en vivo (clima-actual)', () {
    test(
      'en vivo usa el estado que manda clima-actual sin recalcularlo',
      () async {
        final provider = await _providerWithPlants();

        // Suelo 0 % y 45 °C parecerían críticos, pero el backend manda Sana
        await _withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return _json(
              _clima(suelo: 0, temperatura: 45, status: 'Sana', score: 100),
            );
          }
          return _json({'detail': 'no'}, status: 404);
        }, () => provider.loadSensorData(7));

        final data = provider.currentSensorData!;
        expect(data.healthStatus, 'Sana');
        expect(data.healthScore, 100.0);
        expect(data.needsWater, isFalse);
        // Las lecturas se muestran tal cual llegan
        expect(data.soilHumidity, 0.0);
        expect(data.temperature, 45.0);
      },
    );

    test(
      'en vivo con lecturas sanas pero estado Critica del backend se queda en Critica',
      () async {
        final provider = await _providerWithPlants();

        await _withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return _json(
              _clima(suelo: 60, temperatura: 20, status: 'Critica', score: 30),
            );
          }
          return _json({'detail': 'no'}, status: 404);
        }, () => provider.loadSensorData(7));

        expect(provider.currentSensorData!.healthStatus, 'Critica');
        expect(provider.currentSensorData!.healthScore, 30.0);
        expect(provider.currentSensorData!.needsWater, isTrue);
      },
    );

    test('en vivo conserva cada uno de los cinco estados del backend', () async {
      final provider = await _providerWithPlants();
      for (final estado in [
        'Sana',
        'Necesita agua',
        'Exceso de calor',
        'Critica',
        'Sin datos',
      ]) {
        await _withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return _json(_clima(status: estado, score: 77));
          }
          return _json({'detail': 'no'}, status: 404);
        }, () => provider.loadSensorData(7));
        expect(provider.currentSensorData!.healthStatus, estado);
      }
    });

    test(
      'en vivo un estado en inglés o desconocido del backend se trata como Sin datos',
      () async {
        final provider = await _providerWithPlants();
        for (final raro in ['healthy', 'needs_water', 'unknown', 'Buena']) {
          await _withApi((request) async {
            if (request.url.path == '/api/hardware/clima-actual') {
              return _json(_clima(suelo: 0, status: raro, score: 90));
            }
            return _json({'detail': 'no'}, status: 404);
          }, () => provider.loadSensorData(7));
          expect(
            provider.currentSensorData!.healthStatus,
            'Sin datos',
            reason: raro,
          );
          expect(provider.currentSensorData!.needsWater, isFalse);
        }
      },
    );

    test('en vivo con health_score nulo no rompe y deja puntaje null', () async {
      final provider = await _providerWithPlants();

      await _withApi((request) async {
        if (request.url.path == '/api/hardware/clima-actual') {
          final body = _clima(status: 'Necesita agua')..['health_score'] = null;
          return _json(body);
        }
        return _json({'detail': 'no'}, status: 404);
      }, () => provider.loadSensorData(7));

      expect(provider.currentSensorData!.healthStatus, 'Necesita agua');
      expect(provider.currentSensorData!.healthScore, isNull);
    });

    test(
      'en vivo sin humedad del suelo no usa la humedad del aire',
      () async {
        final provider = await _providerWithPlants();

        await _withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return _json(_clima(sinSuelo: true, aire: 50, status: 'Sin datos'));
          }
          return _json({'detail': 'no'}, status: 404);
        }, () => provider.loadSensorData(7));

        final data = provider.currentSensorData!;
        expect(data.soilHumidity, isNull);
        expect(data.airHumidity, 50.0);
        expect(data.healthStatus, 'Sin datos');
      },
    );

    test(
      'en vivo con humedad del suelo nula no usa la humedad del aire',
      () async {
        final provider = await _providerWithPlants();

        await _withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            final body = _clima(aire: 80)..['humedad_suelo'] = null;
            return _json(body);
          }
          return _json({'detail': 'no'}, status: 404);
        }, () => provider.loadSensorData(7));

        expect(provider.currentSensorData!.soilHumidity, isNull);
        expect(provider.currentSensorData!.healthStatus, 'Sin datos');
      },
    );

    test(
      'clima-actual en línea sin health_status deja Sin datos y livePumpOn sigue funcionando',
      () async {
        final provider = await _providerWithPlants();

        // Suelo 45 % y 24 °C: la app no puede inventar «Sana»
        await _withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return _json(_clima(led: true));
          }
          return _json({'detail': 'no'}, status: 404);
        }, () => provider.loadSensorData(7));

        expect(provider.currentSensorData!.healthStatus, 'Sin datos');
        expect(provider.currentSensorData!.healthScore, isNull);
        expect(provider.currentSensorData!.pumpActive, 1);
        expect(provider.livePumpOn(7), isTrue);
        expect(provider.livePumpOn(8), isNull);
      },
    );

    test(
      'en vivo con suelo seco y sin health_status no calcula Necesita agua',
      () async {
        final provider = await _providerWithPlants();

        await _withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return _json(_clima(suelo: 0, temperatura: 45));
          }
          return _json({'detail': 'no'}, status: 404);
        }, () => provider.loadSensorData(7));

        expect(provider.currentSensorData!.healthStatus, 'Sin datos');
        expect(provider.currentSensorData!.needsWater, isFalse);
      },
    );
  });

  group('rama de base (sensors latest)', () {
    test('desde la base usa el estado de sensors latest', () async {
      final provider = await _providerWithPlants();

      await _withApi((request) async {
        if (request.url.path == '/api/hardware/clima-actual') {
          return _json(_clima(estado: 'Desconectado'));
        }
        if (request.url.path == '/api/sensors/latest/7') {
          // Números sanos, estado del backend: Exceso de calor
          return _json(
            _latest(suelo: 60, temperatura: 20, status: 'Exceso de calor', score: 85),
          );
        }
        return _json({'detail': 'no'}, status: 404);
      }, () => provider.loadSensorData(7));

      final data = provider.currentSensorData!;
      expect(data.healthStatus, 'Exceso de calor');
      expect(data.healthScore, 85.0);
      expect(provider.livePumpOn(7), isNull);
    });

    test('latest sin lecturas (Sin datos y puntaje null) no rompe', () async {
      final provider = await _providerWithPlants();

      await _withApi((request) async {
        if (request.url.path == '/api/hardware/clima-actual') {
          return _json(_clima(estado: 'Desconectado'));
        }
        if (request.url.path == '/api/sensors/latest/7') {
          return _json({
            'plant_id': 7,
            'plant_name': 'Echeveria',
            'temperature': null,
            'air_humidity': null,
            'soil_humidity': null,
            'light_level': null,
            'solar_voltage': null,
            'battery_level': null,
            'pump_active': 0,
            'health_status': 'Sin datos',
            'health_score': null,
          });
        }
        return _json({'detail': 'no'}, status: 404);
      }, () => provider.loadSensorData(7));

      expect(provider.currentSensorData!.healthStatus, 'Sin datos');
      expect(provider.currentSensorData!.healthScore, isNull);
    });

    test('latest de un backend viejo (en inglés) se muestra como Sin datos', () async {
      final provider = await _providerWithPlants();

      await _withApi((request) async {
        if (request.url.path == '/api/hardware/clima-actual') {
          return _json(_clima(estado: 'Desconectado'));
        }
        return _json(_latest(status: 'healthy', score: 90));
      }, () => provider.loadSensorData(7));

      expect(provider.currentSensorData!.healthStatus, 'Sin datos');
      expect(provider.currentSensorData!.needsWater, isFalse);
    });
  });

  group('CA-10 la misma planta, el mismo estado', () {
    test(
      'el mismo estado en vivo y desde la base se ve igual aunque los números difieran',
      () async {
        final provider = await _providerWithPlants();
        var online = true;

        await _withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return online
                ? _json(
                    _clima(
                      suelo: 20,
                      temperatura: 28,
                      status: 'Necesita agua',
                      score: 90,
                    ),
                  )
                : _json(_clima(estado: 'Desconectado'));
          }
          if (request.url.path == '/api/sensors/latest/7') {
            // Los números "sugieren" otra cosa; el estado es el mismo
            return _json(
              _latest(
                suelo: 60,
                temperatura: 20,
                status: 'Necesita agua',
                score: 90,
              ),
            );
          }
          return _json({'detail': 'no'}, status: 404);
        }, () async {
          await provider.loadSensorData(7);
          final vivo = provider.currentSensorData!;
          expect(provider.livePumpOn(7), isFalse);

          online = false;
          await provider.loadSensorData(7);
          final base = provider.currentSensorData!;
          expect(provider.livePumpOn(7), isNull);

          expect(vivo.healthStatus, 'Necesita agua');
          expect(base.healthStatus, vivo.healthStatus);
          expect(base.healthScore, vivo.healthScore);
          expect(base.healthLabel, vivo.healthLabel);
          expect(base.needsWater, vivo.needsWater);
          expect(base.needsWater, isTrue);
        });
      },
    );
  });

  group('CA-11 fallos del API', () {
    test('si el API falla el estado es Sin datos', () async {
      final provider = await _providerWithPlants();

      await _withApi(
        (_) async => throw http.ClientException('sin conexión'),
        () => provider.loadSensorData(7),
      );

      final data = provider.currentSensorData!;
      expect(data.healthStatus, 'Sin datos');
      expect(data.healthScore, isNull);
      expect(data.needsWater, isFalse);
      expect(provider.livePumpOn(7), isNull);
    });

    test('si latest responde con error del servidor el estado es Sin datos', () async {
      final provider = await _providerWithPlants();

      await _withApi((request) async {
        if (request.url.path == '/api/hardware/clima-actual') {
          return _json(_clima(estado: 'Desconectado'));
        }
        return _json({'detail': 'error'}, status: 500);
      }, () => provider.loadSensorData(7));

      expect(provider.currentSensorData!.healthStatus, 'Sin datos');
      expect(provider.currentSensorData!.healthScore, isNull);
    });

    test('antes de la primera carga no hay datos de sensores inventados', () async {
      final provider = await _providerWithPlants();
      expect(provider.currentSensorData, isNull);
    });
  });
}
