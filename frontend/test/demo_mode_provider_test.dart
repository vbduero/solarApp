// Solar-Grow - Pruebas de modelos y providers del modo demo
// Spec 005 · CA-1 a CA-7, CA-9, CA-11, CA-12 y CA-14 (decisiones D1 a D5 del plan).
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/models/sensor_data_model.dart';
import 'package:solar_grow/models/task_model.dart';
import 'package:solar_grow/providers/plant_provider.dart';
import 'package:solar_grow/providers/task_provider.dart';

http.Response jsonResponse(Object body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

Map<String, dynamic> plantJson(int id, String name) => {
  'id': id,
  'common_name': name,
};

Map<String, dynamic> taskJson(int id, {int plantId = 7}) => {
  'id': id,
  'plant_id': plantId,
  'plant_name': 'Echeveria',
  'task_type': 'Regar',
  'status': 'Pendiente',
  'due_date': '2026-11-12T08:00:00',
  'created_at': '2026-11-01T08:00:00',
};

Map<String, dynamic> latestJson({int plantId = 7}) => {
  'plant_id': plantId,
  'plant_name': 'Echeveria',
  'temperature': 22.0,
  'air_humidity': 50.0,
  'soil_humidity': 40.0,
  'pump_active': 0,
  'health_status': 'Sana',
  'health_score': 90.0,
};

/// Cliente falso que cuenta las peticiones y las guarda.
class Recorder {
  final List<http.Request> requests = [];
  int get count => requests.length;
  bool hit(String method, String path) =>
      requests.any((r) => r.method == method && r.url.path == path);
}

Future<T> withApi<T>(
  Recorder rec,
  Future<http.Response> Function(http.Request request) handler,
  Future<T> Function() action,
) {
  return http.runWithClient(
    action,
    () => MockClient((request) {
      rec.requests.add(request);
      return handler(request);
    }),
  );
}

Future<http.Response> _fail(http.Request _) async =>
    throw http.ClientException('sin conexión');

/// Provider con la lista de ejemplo cargada (falla la red) y la Echeveria 1 elegida.
Future<PlantProvider> demoProviderWithSelectedPlant(Recorder rec) async {
  final provider = PlantProvider();
  await withApi(rec, _fail, () async {
    await provider.loadPlants();
    await provider.selectPlant(provider.plants.first);
  });
  expect(provider.plants.first.id, 1);
  expect(provider.plants.first.isDemo, isTrue);
  return provider;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CA-1 plantas de ejemplo', () {
    final variantes = <String, Future<http.Response> Function(http.Request)>{
      'sin red': _fail,
      '401': (_) async => jsonResponse({'detail': 'x'}, status: 401),
      '500': (_) async => jsonResponse({'detail': 'x'}, status: 500),
    };

    for (final entry in variantes.entries) {
      test(
        'si loadPlants falla sin red, con 401 o con 500 carga plantas de ejemplo marcadas (${entry.key})',
        () async {
          final provider = PlantProvider();
          await withApi(Recorder(), entry.value, provider.loadPlants);

          expect(provider.plants, isNotEmpty);
          expect(provider.plants.every((p) => p.isDemo), isTrue);
          expect(provider.showingDemoPlants, isTrue);
          expect(provider.isLoading, isFalse);
        },
      );
    }

    test('las plantas que llegan del servidor nunca están marcadas como ejemplo', () {
      // isDemo no se lee del JSON, ni siquiera si el servidor lo manda
      final planta = PlantModel.fromJson({
        'id': 1,
        'common_name': 'Echeveria',
        'is_demo': true,
        'isDemo': true,
      });
      expect(planta.isDemo, isFalse);

      final tarea = TaskModel.fromJson({...taskJson(1), 'is_demo': true, 'isDemo': true});
      expect(tarea.isDemo, isFalse);

      // Y por defecto un modelo construido a mano tampoco es de ejemplo
      expect(PlantModel(id: 7, commonName: 'Echeveria').isDemo, isFalse);
    });

    test('las plantas del servidor cargadas por loadPlants no son de ejemplo', () async {
      final provider = PlantProvider();
      await withApi(
        Recorder(),
        (_) async => jsonResponse([
          {...plantJson(1, 'Echeveria'), 'is_demo': true},
        ]),
        provider.loadPlants,
      );
      expect(provider.plants.single.isDemo, isFalse);
      expect(provider.showingDemoPlants, isFalse);
    });
  });

  group('CA-2 tareas de ejemplo', () {
    test('si loadTodayTasks falla carga tareas de ejemplo marcadas', () async {
      final provider = TaskProvider();
      await withApi(Recorder(), _fail, provider.loadTodayTasks);

      expect(provider.todayTasks, isNotEmpty);
      expect(provider.todayTasks.every((t) => t.isDemo), isTrue);
      expect(provider.showingDemoTasks, isTrue);
    });
  });

  group('CA-3 y CA-4 sin ejemplos con respuestas 200', () {
    test('con respuestas 200, también con listas vacías, no hay nada de ejemplo', () async {
      final plants = PlantProvider();
      final tasks = TaskProvider();

      // Listas llenas
      await withApi(Recorder(), (request) async {
        if (request.url.path == '/api/plants/') {
          return jsonResponse([plantJson(7, 'Echeveria')]);
        }
        return jsonResponse([taskJson(1)]);
      }, () async {
        await plants.loadPlants();
        await tasks.loadTodayTasks();
      });
      expect(plants.plants, hasLength(1));
      expect(tasks.todayTasks, hasLength(1));
      expect(plants.showingDemoPlants, isFalse);
      expect(tasks.showingDemoTasks, isFalse);

      // Listas vacías: no es modo demo
      final plants2 = PlantProvider();
      final tasks2 = TaskProvider();
      await withApi(Recorder(), (_) async => jsonResponse([]), () async {
        await plants2.loadPlants();
        await tasks2.loadTodayTasks();
      });
      expect(plants2.plants, isEmpty);
      expect(tasks2.todayTasks, isEmpty);
      expect(plants2.showingDemoPlants, isFalse);
      expect(tasks2.showingDemoTasks, isFalse);
    });

    test('una carga correcta apaga el modo demo aunque la lista llegue vacía', () async {
      final plants = PlantProvider();
      final tasks = TaskProvider();
      await withApi(Recorder(), _fail, () async {
        await plants.loadPlants();
        await tasks.loadTodayTasks();
      });
      expect(plants.showingDemoPlants, isTrue);
      expect(tasks.showingDemoTasks, isTrue);

      await withApi(Recorder(), (_) async => jsonResponse([]), () async {
        await plants.loadPlants();
        await tasks.loadTodayTasks();
      });
      expect(plants.plants, isEmpty);
      expect(tasks.todayTasks, isEmpty);
      expect(plants.showingDemoPlants, isFalse);
      expect(tasks.showingDemoTasks, isFalse);
    });
  });

  group('CA-5 vuelve la conexión', () {
    test(
      'loadPlants con éxito reemplaza los ejemplos y suelta la planta de ejemplo elegida',
      () async {
        final rec = Recorder();
        final provider = await demoProviderWithSelectedPlant(rec);
        expect(provider.selectedPlant?.isDemo, isTrue);

        await withApi(
          rec,
          (_) async => jsonResponse([plantJson(1, 'Echeveria')]),
          provider.loadPlants,
        );

        expect(provider.showingDemoPlants, isFalse);
        expect(provider.plants.single.isDemo, isFalse);
        expect(provider.selectedPlant, isNull);
        expect(provider.currentSensorData, isNull);
        expect(provider.sensorsUnavailable, isFalse);
        expect(provider.livePumpOn(1), isNull);
      },
    );

    test('loadPlants con éxito conserva una planta real elegida', () async {
      final provider = PlantProvider();
      final rec = Recorder();
      Future<http.Response> handler(http.Request request) async {
        if (request.url.path == '/api/plants/') {
          return jsonResponse([plantJson(7, 'Echeveria')]);
        }
        if (request.url.path == '/api/sensors/latest/7') {
          return jsonResponse(latestJson());
        }
        return jsonResponse({'detail': 'no'}, status: 404);
      }

      await withApi(rec, handler, () async {
        await provider.loadPlants();
        await provider.selectPlant(provider.plants.first);
        expect(provider.currentSensorData?.healthStatus, 'Sana');

        await provider.loadPlants();
      });

      expect(provider.selectedPlant?.id, 7);
      expect(provider.currentSensorData?.healthStatus, 'Sana');
    });
  });

  group('CA-6 lecturas de una planta de ejemplo', () {
    test(
      'loadSensorData de una planta de ejemplo no hace ninguna petición y deja una lectura vacía',
      () async {
        final rec = Recorder();
        final provider = await demoProviderWithSelectedPlant(rec);
        final antes = rec.count;

        await withApi(rec, (_) async => jsonResponse(latestJson(plantId: 1)), () async {
          await provider.loadSensorData(1);
          await provider.selectPlant(provider.plants.first);
          await provider.loadSensorData(1);
        });

        expect(rec.count, antes);
        final data = provider.currentSensorData;
        expect(data, isNotNull);
        expect(data!.healthStatus, 'Sin datos');
        expect(data.healthScore, isNull);
        expect(data.temperature, isNull);
        expect(data.soilHumidity, isNull);
        expect(data.airHumidity, isNull);
        expect(data.lightLevel, isNull);
        expect(data.solarVoltage, isNull);
        expect(data.batteryLevel, isNull);
        expect(provider.sensorsUnavailable, isFalse);
        expect(provider.livePumpOn(1), isNull);
      },
    );
  });

  group('CA-7 bloqueo por objeto, no por id', () {
    test(
      'activateWatering y stopWatering con una planta de ejemplo elegida no hacen peticiones y devuelven false',
      () async {
        final rec = Recorder();
        final provider = await demoProviderWithSelectedPlant(rec);
        final antes = rec.count;

        late bool riego;
        late bool parar;
        String? errorTrasRiego;
        await withApi(rec, (_) async => jsonResponse({'success': true}), () async {
          riego = await provider.activateWatering(1);
          errorTrasRiego = provider.error;
          parar = await provider.stopWatering(1);
        });

        expect(riego, isFalse);
        expect(parar, isFalse);
        expect(errorTrasRiego, 'No disponible en modo demo.');
        expect(provider.error, 'No disponible en modo demo.');
        expect(rec.count, antes, reason: 'no debe salir ninguna petición');
        expect(rec.hit('POST', '/api/controls/water'), isFalse);
        expect(rec.hit('POST', '/api/controls/stop-water'), isFalse);
      },
    );

    test('activateWatering con la planta real de id 1 elegida sí hace la petición', () async {
      final provider = PlantProvider();
      final rec = Recorder();
      Future<http.Response> handler(http.Request request) async {
        if (request.url.path == '/api/plants/') {
          return jsonResponse([plantJson(1, 'Echeveria')]);
        }
        if (request.url.path == '/api/controls/water') {
          return jsonResponse({'success': true, 'message': 'ok'});
        }
        if (request.url.path == '/api/sensors/latest/1') {
          return jsonResponse(latestJson(plantId: 1));
        }
        return jsonResponse({'detail': 'no'}, status: 404);
      }

      late bool ok;
      await withApi(rec, handler, () async {
        await provider.loadPlants();
        await provider.selectPlant(provider.plants.first);
        ok = await provider.activateWatering(1);
      });

      expect(provider.plants.first.isDemo, isFalse);
      expect(ok, isTrue);
      expect(rec.hit('POST', '/api/controls/water'), isTrue);
      expect(provider.error, isNull);
    });
  });

  group('CA-9 cerrar sesión', () {
    test('clearSession vacía plantas, planta elegida, lectura, historial y tareas', () async {
      final plants = PlantProvider();
      final tasks = TaskProvider();
      Future<http.Response> handler(http.Request request) async {
        final path = request.url.path;
        if (path == '/api/plants/') return jsonResponse([plantJson(7, 'Echeveria')]);
        if (path == '/api/sensors/latest/7') return jsonResponse(latestJson());
        if (path.startsWith('/api/sensors/history')) {
          return jsonResponse([
            {
              'id': 1,
              'plant_id': 7,
              'recorded_at': '2026-11-12T08:00:00',
              'temperature': 22.0,
              'air_humidity': 50.0,
              'soil_humidity': 40.0,
            },
          ]);
        }
        if (path == '/api/tasks/') return jsonResponse([taskJson(1)]);
        return jsonResponse({'detail': 'no'}, status: 404);
      }

      await withApi(Recorder(), handler, () async {
        await plants.loadPlants();
        await plants.selectPlant(plants.plants.first);
        await plants.loadSensorHistory(7, hours: 24);
        await tasks.loadTodayTasks();
        await tasks.loadUpcomingTasks();
      });
      expect(plants.plants, isNotEmpty);
      expect(plants.selectedPlant, isNotNull);
      expect(plants.currentSensorData, isNotNull);
      expect(plants.sensorHistory, isNotEmpty);
      expect(tasks.todayTasks, isNotEmpty);
      expect(tasks.upcomingTasks, isNotEmpty);

      plants.clearSession();
      tasks.clearSession();

      expect(plants.plants, isEmpty);
      expect(plants.selectedPlant, isNull);
      expect(plants.currentSensorData, isNull);
      expect(plants.sensorsUnavailable, isFalse);
      expect(plants.sensorHistory, isEmpty);
      expect(plants.historyError, isNull);
      expect(plants.isHistoryLoading, isFalse);
      expect(plants.error, isNull);
      expect(plants.isLoading, isFalse);
      expect(plants.livePumpOn(7), isNull);
      expect(plants.showingDemoPlants, isFalse);
      expect(tasks.todayTasks, isEmpty);
      expect(tasks.upcomingTasks, isEmpty);
      expect(tasks.isLoading, isFalse);
      expect(tasks.showingDemoTasks, isFalse);
    });

    test('clearSession también borra los ejemplos y la planta de ejemplo elegida', () async {
      final provider = await demoProviderWithSelectedPlant(Recorder());
      final tasks = TaskProvider();
      await withApi(Recorder(), _fail, tasks.loadTodayTasks);
      expect(provider.showingDemoPlants, isTrue);
      expect(tasks.showingDemoTasks, isTrue);

      provider.clearSession();
      tasks.clearSession();

      expect(provider.plants, isEmpty);
      expect(provider.selectedPlant, isNull);
      expect(provider.currentSensorData, isNull);
      expect(provider.showingDemoPlants, isFalse);
      expect(tasks.todayTasks, isEmpty);
      expect(tasks.showingDemoTasks, isFalse);
    });

    test(
      'una respuesta de la sesión anterior que llega después de clearSession no se aplica (plantas)',
      () async {
        final provider = PlantProvider();
        final gate = Completer<void>();

        await withApi(Recorder(), (_) async {
          await gate.future;
          return jsonResponse([plantJson(7, 'Echeveria')]);
        }, () async {
          final pending = provider.loadPlants();
          provider.clearSession();
          gate.complete();
          await pending;
        });

        expect(provider.plants, isEmpty);
        expect(provider.isLoading, isFalse);
      },
    );

    test(
      'una respuesta de la sesión anterior que llega después de clearSession no se aplica (plantas, fallo tardío)',
      () async {
        final provider = PlantProvider();
        final gate = Completer<void>();

        await withApi(Recorder(), (_) async {
          await gate.future;
          throw http.ClientException('sin conexión');
        }, () async {
          final pending = provider.loadPlants();
          provider.clearSession();
          gate.complete();
          await pending;
        });

        // Un fallo tardío tampoco puede meter plantas de ejemplo
        expect(provider.plants, isEmpty);
        expect(provider.showingDemoPlants, isFalse);
      },
    );

    test(
      'una respuesta de la sesión anterior que llega después de clearSession no se aplica (tareas de hoy)',
      () async {
        final provider = TaskProvider();
        final gate = Completer<void>();

        await withApi(Recorder(), (_) async {
          await gate.future;
          return jsonResponse([taskJson(1)]);
        }, () async {
          final pending = provider.loadTodayTasks();
          provider.clearSession();
          gate.complete();
          await pending;
        });
        expect(provider.todayTasks, isEmpty);
        expect(provider.isLoading, isFalse);

        // Fallo tardío: tampoco aparecen tareas de ejemplo
        final provider2 = TaskProvider();
        final gate2 = Completer<void>();
        await withApi(Recorder(), (_) async {
          await gate2.future;
          throw http.ClientException('sin conexión');
        }, () async {
          final pending = provider2.loadTodayTasks();
          provider2.clearSession();
          gate2.complete();
          await pending;
        });
        expect(provider2.todayTasks, isEmpty);
        expect(provider2.showingDemoTasks, isFalse);
      },
    );

    test(
      'una respuesta de la sesión anterior que llega después de clearSession no se aplica (próximas)',
      () async {
        final provider = TaskProvider();
        final gate = Completer<void>();

        await withApi(Recorder(), (_) async {
          await gate.future;
          return jsonResponse([taskJson(1)]);
        }, () async {
          final pending = provider.loadUpcomingTasks();
          provider.clearSession();
          gate.complete();
          await pending;
        });
        expect(provider.upcomingTasks, isEmpty);
      },
    );

    test(
      'una respuesta de la sesión anterior que llega después de clearSession no se aplica (lecturas)',
      () async {
        final provider = PlantProvider();
        final gate = Completer<void>();

        await withApi(Recorder(), (request) async {
          await gate.future;
          if (request.url.path == '/api/hardware/clima-actual') {
            return jsonResponse({
              'estado_conexion': 'En línea',
              'plant_id': 7,
              'temperatura': 24,
              'led_encendido': true,
            });
          }
          return jsonResponse(latestJson());
        }, () async {
          final pending = provider.loadSensorData(7);
          provider.clearSession();
          gate.complete();
          await pending;
        });

        expect(provider.currentSensorData, isNull);
        expect(provider.livePumpOn(7), isNull);
        expect(provider.sensorsUnavailable, isFalse);
      },
    );

    for (final falla in [false, true]) {
      test(
        'una respuesta de la sesión anterior que llega después de clearSession no se aplica (historial${falla ? ', fallo tardío' : ''})',
        () async {
          final provider = PlantProvider();
          final gate = Completer<void>();

          await withApi(Recorder(), (_) async {
            await gate.future;
            if (falla) throw http.ClientException('sin conexión');
            return jsonResponse([
              {
                'id': 1,
                'plant_id': 7,
                'recorded_at': '2026-11-12T08:00:00',
                'temperature': 22.0,
                'air_humidity': 50.0,
                'soil_humidity': 40.0,
              },
            ]);
          }, () async {
            final pending = provider.loadSensorHistory(7, hours: 24);
            provider.clearSession();
            gate.complete();
            await pending;
          });

          expect(provider.sensorHistory, isEmpty);
          expect(provider.historyError, isNull);
          expect(provider.isHistoryLoading, isFalse);
        },
      );
    }
  });

  group('CA-11 y CA-12 lecturas nunca inventadas', () {
    test(
      'si las lecturas fallan queda una lectura vacía y sensorsUnavailable; al volver se apaga',
      () async {
        final provider = PlantProvider();
        final rec = Recorder();
        var caido = true;
        Future<http.Response> handler(http.Request request) async {
          if (request.url.path == '/api/plants/') {
            return jsonResponse([plantJson(7, 'Echeveria')]);
          }
          if (caido) throw http.ClientException('sin conexión');
          if (request.url.path == '/api/sensors/latest/7') {
            return jsonResponse(latestJson());
          }
          return jsonResponse({'detail': 'no'}, status: 404);
        }

        await withApi(rec, handler, () async {
          await provider.loadPlants();
          await provider.selectPlant(provider.plants.first);

          final data = provider.currentSensorData;
          expect(data, isNotNull);
          expect(data!.plantId, 7);
          expect(data.plantName, 'Echeveria');
          expect(data.healthStatus, 'Sin datos');
          expect(data.healthScore, isNull);
          expect(data.temperature, isNull);
          expect(data.soilHumidity, isNull);
          expect(data.airHumidity, isNull);
          expect(data.lightLevel, isNull);
          expect(data.solarVoltage, isNull);
          expect(data.batteryLevel, isNull);
          expect(data.recordedAt, isNull);
          expect(provider.sensorsUnavailable, isTrue);
          expect(provider.livePumpOn(7), isNull);

          // Vuelve la conexión: el siguiente refresco apaga el aviso
          caido = false;
          await provider.loadSensorData(7);
          expect(provider.sensorsUnavailable, isFalse);
          expect(provider.currentSensorData?.temperature, 22.0);
        });
      },
    );

    test('con 401 o 500 en las lecturas también queda sensorsUnavailable', () async {
      for (final status in [401, 500]) {
        final provider = PlantProvider();
        await withApi(
          Recorder(),
          (_) async => jsonResponse({'detail': 'x'}, status: status),
          () => provider.loadSensorData(7),
        );
        expect(provider.sensorsUnavailable, isTrue, reason: 'status $status');
        expect(provider.currentSensorData?.healthStatus, 'Sin datos');
        expect(provider.currentSensorData?.soilHumidity, isNull);
      }
    });

    test('si las lecturas fallan con la lista de plantas vacía no lanza', () async {
      final provider = PlantProvider();
      expect(provider.plants, isEmpty);

      await withApi(Recorder(), _fail, () => provider.loadSensorData(7));

      expect(provider.currentSensorData, isNotNull);
      expect(provider.currentSensorData!.plantId, 7);
      expect(provider.currentSensorData!.healthStatus, 'Sin datos');
      expect(provider.sensorsUnavailable, isTrue);
    });

    test('selectPlant pone sensorsUnavailable en false mientras carga', () async {
      final provider = PlantProvider();
      await withApi(Recorder(), _fail, () => provider.loadSensorData(7));
      expect(provider.sensorsUnavailable, isTrue);

      final gate = Completer<void>();
      await withApi(Recorder(), (request) async {
        await gate.future;
        return jsonResponse(latestJson());
      }, () async {
        final selecting = provider.selectPlant(
          PlantModel(id: 7, commonName: 'Echeveria'),
        );
        expect(provider.sensorsUnavailable, isFalse);
        gate.complete();
        await selecting;
      });
    });

    test('latest 200 sin lecturas deja sensorsUnavailable en false', () async {
      final provider = PlantProvider();
      await withApi(Recorder(), (request) async {
        if (request.url.path == '/api/sensors/latest/7') {
          return jsonResponse({
            'plant_id': 7,
            'plant_name': 'Echeveria',
            'temperature': null,
            'air_humidity': null,
            'soil_humidity': null,
          });
        }
        return jsonResponse({'detail': 'no'}, status: 404);
      }, () => provider.loadSensorData(7));

      expect(provider.sensorsUnavailable, isFalse);
      expect(provider.currentSensorData, isNotNull);
      expect(provider.currentSensorData!.temperature, isNull);
      expect(provider.currentSensorData!.soilHumidity, isNull);
    });

    test('empty trae lecturas nulas, Sin datos y puntaje null', () {
      final e = SensorDataModel.empty(7, 'Echeveria');
      expect(e.plantId, 7);
      expect(e.plantName, 'Echeveria');
      expect(e.temperature, isNull);
      expect(e.airHumidity, isNull);
      expect(e.soilHumidity, isNull);
      expect(e.lightLevel, isNull);
      expect(e.solarVoltage, isNull);
      expect(e.batteryLevel, isNull);
      expect(e.pumpActive, 0);
      expect(e.healthStatus, 'Sin datos');
      expect(e.healthScore, isNull);
      expect(e.recordedAt, isNull);
      expect(e.needsWater, isFalse);
      expect(e.healthLabel, 'sin lecturas');
    });
  });

  group('CA-14 lectura en vivo', () {
    Map<String, dynamic> clima({Map<String, dynamic> extra = const {}}) => {
      'estado_conexion': 'En línea',
      'plant_id': 7,
      'temperatura': 24,
      'humedad_suelo': 45,
      'led_encendido': true,
      ...extra,
    };

    test(
      'en vivo la lectura no trae luz, voltaje ni batería y sin humedad del aire queda vacía',
      () async {
        final provider = PlantProvider();
        await withApi(Recorder(), (request) async {
          if (request.url.path == '/api/hardware/clima-actual') {
            return jsonResponse(clima());
          }
          return jsonResponse({'detail': 'no'}, status: 404);
        }, () => provider.loadSensorData(7));

        final data = provider.currentSensorData;
        expect(data, isNotNull);
        expect(data!.temperature, 24.0);
        expect(data.soilHumidity, 45.0);
        expect(data.lightLevel, isNull);
        expect(data.solarVoltage, isNull);
        expect(data.batteryLevel, isNull);
        expect(data.airHumidity, isNull);
        expect(provider.sensorsUnavailable, isFalse);
      },
    );

    test('en vivo livePumpOn y la salud siguen funcionando', () async {
      final provider = PlantProvider();
      await withApi(Recorder(), (request) async {
        if (request.url.path == '/api/hardware/clima-actual') {
          return jsonResponse(clima(extra: {
            'humedad': 60,
            'health_status': 'Necesita agua',
            'health_score': 35,
          }));
        }
        return jsonResponse({'detail': 'no'}, status: 404);
      }, () => provider.loadSensorData(7));

      expect(provider.livePumpOn(7), isTrue);
      expect(provider.livePumpOn(8), isNull);
      expect(provider.currentSensorData?.pumpActive, 1);
      expect(provider.currentSensorData?.healthStatus, 'Necesita agua');
      expect(provider.currentSensorData?.healthScore, 35.0);
      expect(provider.currentSensorData?.needsWater, isTrue);
      // La humedad que sí llega se respeta (alias `humedad`)
      expect(provider.currentSensorData?.airHumidity, 60.0);
    });

    test('una lectura en vivo apaga sensorsUnavailable', () async {
      final provider = PlantProvider();
      await withApi(Recorder(), _fail, () => provider.loadSensorData(7));
      expect(provider.sensorsUnavailable, isTrue);

      await withApi(Recorder(), (request) async {
        if (request.url.path == '/api/hardware/clima-actual') {
          return jsonResponse(clima());
        }
        return jsonResponse({'detail': 'no'}, status: 404);
      }, () => provider.loadSensorData(7));
      expect(provider.sensorsUnavailable, isFalse);
    });
  });
}
