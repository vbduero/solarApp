// Solar-Grow - Pruebas de PlantProvider: estado en vivo de la bomba y stopWatering
// Spec 003 · CA-8 (livePumpOn) y CA-11 (stopWatering), decisiones D4 y D5 del plan.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/providers/plant_provider.dart';

http.Response jsonResponse(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> climaJson({
  String estado = 'En línea',
  int plantId = 7,
  bool led = true,
}) {
  return {
    'estado_conexion': estado,
    'plant_id': plantId,
    'temperatura': 24,
    'humedad_aire': 50,
    'humedad_suelo': 45,
    'led_encendido': led,
  };
}

Map<String, dynamic> latestJson({int plantId = 7, int pump = 0}) {
  return {
    'plant_id': plantId,
    'plant_name': 'Echeveria',
    'temperature': 22.0,
    'air_humidity': 50.0,
    'soil_humidity': 40.0,
    'light_level': 85.0,
    'solar_voltage': 12.4,
    'battery_level': 98.0,
    'pump_active': pump,
    'health_status': 'healthy',
    'health_score': 90.0,
  };
}

Future<T> withApi<T>(
  Future<http.Response> Function(http.Request request) handler,
  Future<T> Function() action,
) {
  return http.runWithClient(action, () => MockClient(handler));
}

/// Crea un provider con las plantas 7 y 8 cargadas (hace falta que `_plants`
/// tenga la planta para la rama de hardware).
Future<PlantProvider> providerWithPlants() async {
  final provider = PlantProvider();
  await withApi((request) async {
    if (request.url.path == '/api/plants/') {
      return jsonResponse([
        {'id': 7, 'common_name': 'Echeveria'},
        {'id': 8, 'common_name': 'Cactus'},
      ]);
    }
    return jsonResponse({'detail': 'no'}, status: 404);
  }, provider.loadPlants);
  expect(provider.plants, hasLength(2));
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('livePumpOn', () {
    test(
      'livePumpOn refleja led_encendido cuando el ESP8266 está en línea en esa planta',
      () async {
        final provider = await providerWithPlants();
        var led = true;

        await withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return jsonResponse(climaJson(led: led));
          }
          return jsonResponse({'detail': 'no'}, status: 404);
        }, () async {
          await provider.loadSensorData(7);
          expect(provider.livePumpOn(7), isTrue);
          expect(provider.currentSensorData?.pumpActive, 1);
          // Es dato en vivo solo de la planta 7
          expect(provider.livePumpOn(8), isNull);

          led = false;
          await provider.loadSensorData(7);
          expect(provider.livePumpOn(7), isFalse);
          expect(provider.currentSensorData?.pumpActive, 0);
        });
      },
    );

    test(
      'livePumpOn es null si el ESP8266 está desconectado aunque la lectura guardada diga bomba encendida',
      () async {
        final provider = await providerWithPlants();

        await withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return jsonResponse(climaJson(estado: 'Desconectado'));
          }
          if (request.url.path == '/api/sensors/latest/7') {
            return jsonResponse(latestJson(pump: 1));
          }
          return jsonResponse({'detail': 'no'}, status: 404);
        }, () => provider.loadSensorData(7));

        // La lectura guardada sí dice bomba encendida...
        expect(provider.currentSensorData?.pumpActive, 1);
        // ...pero no es un dato en vivo
        expect(provider.livePumpOn(7), isNull);
      },
    );

    test('livePumpOn es null si clima-actual es de otra planta', () async {
      final provider = await providerWithPlants();

      await withApi((request) async {
        if (request.url.path == '/api/hardware/clima-actual') {
          return jsonResponse(climaJson(plantId: 8, led: true));
        }
        if (request.url.path == '/api/sensors/latest/7') {
          return jsonResponse(latestJson(pump: 1));
        }
        return jsonResponse({'detail': 'no'}, status: 404);
      }, () => provider.loadSensorData(7));

      expect(provider.livePumpOn(7), isNull);
      expect(provider.livePumpOn(8), isNull);
    });

    test('livePumpOn es null con datos demo cuando el API falla', () async {
      final provider = await providerWithPlants();

      await withApi(
        (_) async => throw http.ClientException('sin conexión'),
        () => provider.loadSensorData(7),
      );

      // Datos demo (pumpActive 0): no cuentan como dato en vivo
      expect(provider.currentSensorData, isNotNull);
      expect(provider.livePumpOn(7), isNull);
    });

    test(
      'una lectura de base o demo borra el dato en vivo anterior',
      () async {
        final provider = await providerWithPlants();
        var online = true;

        await withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return jsonResponse(
              climaJson(estado: online ? 'En línea' : 'Desconectado'),
            );
          }
          if (request.url.path == '/api/sensors/latest/7') {
            return jsonResponse(latestJson(pump: 1));
          }
          return jsonResponse({'detail': 'no'}, status: 404);
        }, () async {
          await provider.loadSensorData(7);
          expect(provider.livePumpOn(7), isTrue);

          online = false;
          await provider.loadSensorData(7);
          expect(provider.livePumpOn(7), isNull);
        });
      },
    );

    test('selectPlant borra el estado en vivo de la planta anterior', () async {
      final provider = await providerWithPlants();
      final gate = Completer<void>();
      var climaCalls = 0;

      await withApi((request) async {
        if (request.url.path == '/api/hardware/clima-actual') {
          climaCalls++;
          if (climaCalls == 1) return jsonResponse(climaJson(led: true));
          await gate.future; // la carga de selectPlant queda en vuelo
          return jsonResponse(climaJson(estado: 'Desconectado'));
        }
        return jsonResponse(latestJson(plantId: 8), status: 200);
      }, () async {
        await provider.loadSensorData(7);
        expect(provider.livePumpOn(7), isTrue);

        // Se elige otra planta: el estado en vivo de la 7 no puede quedar
        final selecting = provider.selectPlant(
          PlantModel(id: 8, commonName: 'Cactus'),
        );
        expect(provider.selectedPlant?.id, 8);
        expect(provider.livePumpOn(7), isNull);
        expect(provider.livePumpOn(8), isNull);

        gate.complete();
        await selecting;
        expect(provider.livePumpOn(7), isNull);
        expect(provider.livePumpOn(8), isNull);
      });
    });

    test(
      'selectPlant de la misma planta limpia el estado en vivo hasta tener uno nuevo',
      () async {
        final provider = await providerWithPlants();
        final gate = Completer<void>();
        var climaCalls = 0;

        await withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            climaCalls++;
            if (climaCalls == 1) return jsonResponse(climaJson(led: true));
            await gate.future;
            return jsonResponse(climaJson(led: false));
          }
          return jsonResponse({'detail': 'no'}, status: 404);
        }, () async {
          await provider.loadSensorData(7);
          expect(provider.livePumpOn(7), isTrue);

          final selecting = provider.selectPlant(
            PlantModel(id: 7, commonName: 'Echeveria'),
          );
          expect(provider.livePumpOn(7), isNull);

          gate.complete();
          await selecting;
          expect(provider.livePumpOn(7), isFalse);
        });
      },
    );

    test(
      'una respuesta vieja de loadSensorData no pisa el estado en vivo más nuevo',
      () async {
        final provider = await providerWithPlants();
        final firstGate = Completer<void>();
        var climaCalls = 0;

        await withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            climaCalls++;
            if (climaCalls == 1) {
              await firstGate.future; // llega tarde, con la bomba encendida
              return jsonResponse(climaJson(led: true));
            }
            return jsonResponse(climaJson(led: false));
          }
          return jsonResponse({'detail': 'no'}, status: 404);
        }, () async {
          final slow = provider.loadSensorData(7);
          final fast = provider.loadSensorData(7);

          await fast;
          expect(provider.livePumpOn(7), isFalse);
          expect(provider.currentSensorData?.pumpActive, 0);

          firstGate.complete();
          await slow;
        });

        // La respuesta vieja (bomba encendida) se descarta
        expect(climaCalls, 2);
        expect(provider.livePumpOn(7), isFalse);
        expect(provider.currentSensorData?.pumpActive, 0);
      },
    );

    test(
      'una respuesta vieja que falla no pisa el dato en vivo más nuevo',
      () async {
        final provider = await providerWithPlants();
        final firstGate = Completer<void>();
        var climaCalls = 0;

        await withApi((request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            climaCalls++;
            if (climaCalls == 1) {
              await firstGate.future;
              throw http.ClientException('sin conexión');
            }
            return jsonResponse(climaJson(led: false));
          }
          // La lectura guardada de la petición vieja diría bomba encendida
          return jsonResponse(latestJson(pump: 1));
        }, () async {
          final slow = provider.loadSensorData(7);
          final fast = provider.loadSensorData(7);
          await fast;
          expect(provider.livePumpOn(7), isFalse);

          firstGate.complete();
          await slow;
        });

        expect(provider.livePumpOn(7), isFalse);
        expect(provider.currentSensorData?.pumpActive, 0);
      },
    );
  });

  group('stopWatering', () {
    test(
      'stopWatering envía plant_id a /api/controls/stop-water y devuelve true',
      () async {
        final provider = PlantProvider();
        late http.Request sent;
        var requests = 0;

        final ok = await withApi((request) async {
          requests++;
          sent = request;
          return jsonResponse({
            'success': true,
            'message': 'Riego detenido para Echeveria',
          });
        }, () => provider.stopWatering(7));

        expect(ok, isTrue);
        expect(sent.method, 'POST');
        expect(sent.url.path, '/api/controls/stop-water');
        expect(jsonDecode(sent.body), {'plant_id': 7});
        // No recarga sensores: la pantalla espera la confirmación
        expect(requests, 1);
        expect(provider.error, isNull);
      },
    );

    test('stopWatering con 503 devuelve false y deja el detail como error', () async {
      final provider = PlantProvider();
      const detail =
          'No se pudo detener el riego: el ESP8266 no está conectado al puerto serial del servidor.';

      final ok = await withApi(
        (_) async => jsonResponse({'detail': detail}, status: 503),
        () => provider.stopWatering(7),
      );

      expect(ok, isFalse);
      expect(provider.error, detail);
    });

    test('stopWatering con 409 deja el mensaje del servidor', () async {
      final provider = PlantProvider();

      final ok = await withApi(
        (_) async => jsonResponse({
          'detail': 'Esta planta no tiene el ESP8266 conectado.',
        }, status: 409),
        () => provider.stopWatering(7),
      );

      expect(ok, isFalse);
      expect(provider.error, 'Esta planta no tiene el ESP8266 conectado.');
    });

    test('stopWatering sin servidor devuelve false con el mensaje fijo', () async {
      final provider = PlantProvider();

      final ok = await withApi(
        (_) async => throw http.ClientException('sin conexión'),
        () => provider.stopWatering(7),
      );

      expect(ok, isFalse);
      expect(
        provider.error,
        'No se pudo conectar con el servidor para detener el riego.',
      );
    });

    test('stopWatering limpia el error anterior al empezar', () async {
      final provider = PlantProvider();

      await withApi(
        (_) async => jsonResponse({'detail': 'fallo'}, status: 503),
        () => provider.stopWatering(7),
      );
      expect(provider.error, 'fallo');

      final ok = await withApi(
        (_) async => jsonResponse({'success': true, 'message': 'ok'}),
        () => provider.stopWatering(7),
      );
      expect(ok, isTrue);
      expect(provider.error, isNull);
    });
  });
}
