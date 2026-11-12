// Solar-Grow - Pruebas del botón «Detener riego» en el detalle de la planta
// Spec 003 · CA-7 a CA-13 (decisiones D6 y D7 del plan).
//
// Sin red ni esperas reales: el provider es falso y el tiempo es el falso de
// flutter_test (`pump(Duration)`) para los 10 s de «Regar» y la confirmación.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/models/sensor_data_model.dart';
import 'package:solar_grow/providers/auth_provider.dart';
import 'package:solar_grow/providers/plant_provider.dart';
import 'package:solar_grow/screens/plant/plant_detail_screen.dart';

const _stopAviso =
    'Riego detenido. El riego automático puede volver a encender la bomba si la tierra sigue seca.';
const _sinConfirmar =
    'Se envió la orden, pero el ESP8266 no confirmó que la bomba se apagó. Revisa la maceta.';
const _sinServidor =
    'No se pudo conectar con el servidor para detener el riego.';
const _completado = '¡Riego completado exitosamente!';

/// PlantProvider falso: planta fija (id 7), estado en vivo de la bomba y
/// llamadas controladas por la prueba. No hace ninguna petición.
class FakePlantProvider extends PlantProvider {
  FakePlantProvider(this.fakeSelected);

  final PlantModel fakeSelected;

  /// Estado en vivo que devuelve `livePumpOn` (null = sin dato en vivo).
  bool? pumpOn;

  /// Valores que `loadSensorData` va aplicando a `pumpOn`, uno por llamada.
  /// Si la lista está vacía, `loadSensorData` no cambia nada.
  final List<bool?> pumpOnScript = [];

  SensorDataModel? fakeSensorData;
  String? fakeError;
  bool activateResult = true;
  Completer<bool> stopCompleter = Completer<bool>();

  final List<int> sensorLoads = [];
  final List<int> stopCalls = [];
  final List<int> activateCalls = [];

  @override
  PlantModel? get selectedPlant => fakeSelected;

  @override
  SensorDataModel? get currentSensorData => fakeSensorData;

  @override
  String? get error => fakeError;

  @override
  bool? livePumpOn(int plantId) => pumpOn;

  /// Cambia el estado en vivo y avisa a la pantalla.
  void setPumpOn(bool? value) {
    pumpOn = value;
    notifyListeners();
  }

  @override
  Future<void> loadSensorData(int plantId) async {
    sensorLoads.add(plantId);
    if (sensorLoadError != null) throw sensorLoadError!;
    if (pumpOnScript.isNotEmpty) {
      pumpOn = pumpOnScript.removeAt(0);
      notifyListeners();
    }
  }

  @override
  Future<bool> stopWatering(int plantId) {
    stopCalls.add(plantId);
    return stopCompleter.future;
  }

  /// Si no es null, `activateWatering` espera a que la prueba lo complete.
  Completer<bool>? activateCompleter;

  /// Si no es null, `loadSensorData` lo lanza como excepción.
  Object? sensorLoadError;

  @override
  Future<bool> activateWatering(int plantId, {int durationSeconds = 10}) async {
    activateCalls.add(plantId);
    final pending = activateCompleter;
    if (pending != null) return pending.future;
    return activateResult;
  }
}

FakePlantProvider _newFake() =>
    FakePlantProvider(PlantModel(id: 7, commonName: 'Echeveria'));

Widget _app(FakePlantProvider fake) {
  return MultiProvider(
    providers: [
      // Sin sesión: el detalle no arranca su refresco de 3 s
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<PlantProvider>.value(value: fake),
    ],
    child: const MaterialApp(home: PlantDetailScreen()),
  );
}

Future<void> _mount(WidgetTester tester, FakePlantProvider fake) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(fake));
  await tester.pump();
}

/// Desmonta y deja pasar el tiempo para que terminen el parpadeo de
/// AnimatedPlantWidget, la espera de 10 s de «Regar» y la de confirmación.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 15));
  expect(tester.takeException(), isNull);
}

/// Botón (GestureDetector) que contiene la etiqueta dada.
Finder _button(String label) => find
    .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
    .first;

bool _isTapEnabled(WidgetTester tester, String label) =>
    tester.widget<GestureDetector>(_button(label)).onTap != null;

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

/// Toca «Detener riego», responde el API con `ok` y avanza 1 s (primera
/// vuelta de la espera de confirmación).
Future<void> _stopAndAdvanceOneSecond(
  WidgetTester tester,
  FakePlantProvider fake, {
  bool ok = true,
}) async {
  await _tap(tester, 'Detener riego');
  fake.stopCompleter.complete(ok);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Rect _buttonRect(WidgetTester tester, String label) =>
    tester.getRect(_button(label));

void main() {
  group('CA-7 · riego en curso', () {
    testWidgets(
      'con la bomba encendida en vivo muestra Detener riego en lugar de Regar',
      (tester) async {
        final fake = _newFake()..pumpOn = true;
        await _mount(tester, fake);

        expect(find.text('Detener riego'), findsOneWidget);
        expect(find.text('Regar'), findsNothing);
        expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
        expect(find.text('Info'), findsOneWidget);
        expect(find.text('Diagnósticos'), findsOneWidget);
        // Misma fila que Info y Diagnósticos, y habilitado
        final rowY = tester.getCenter(find.text('Info')).dy;
        expect(tester.getCenter(find.text('Detener riego')).dy, closeTo(rowY, 1));
        expect(
          tester.getCenter(find.text('Diagnósticos')).dy,
          closeTo(rowY, 1),
        );
        expect(_isTapEnabled(tester, 'Detener riego'), isTrue);
        // No se agrega un cuarto botón
        expect(find.text('Programar tarea'), findsOneWidget);

        await _finish(tester);
      },
    );

    testWidgets(
      'tras aceptar Regar muestra Detener riego aunque aún no haya dato en vivo',
      (tester) async {
        final fake = _newFake(); // pumpOn == null
        await _mount(tester, fake);
        expect(find.text('Regar'), findsOneWidget);

        await _tap(tester, 'Regar');
        await tester.pump(); // el API acepta el riego

        expect(fake.activateCalls, [7]);
        expect(fake.pumpOn, isNull);
        expect(find.text('Detener riego'), findsOneWidget);
        expect(find.text('Regar'), findsNothing);

        await _finish(tester);
      },
    );

    testWidgets(
      'si el API rechaza Regar no aparece Detener riego y se muestra el error',
      (tester) async {
        final fake = _newFake()
          ..activateResult = false
          ..fakeError = 'Esta planta no tiene el ESP8266 conectado.';
        await _mount(tester, fake);

        await _tap(tester, 'Regar');
        await tester.pump();

        expect(find.text('Esta planta no tiene el ESP8266 conectado.'),
            findsOneWidget);
        expect(find.text('Detener riego'), findsNothing);
        expect(find.text('Regar'), findsOneWidget);

        await _finish(tester);
      },
    );

    testWidgets(
      'sin detener, el flujo de Regar sigue igual: a los 10 s avisa riego completado',
      (tester) async {
        final fake = _newFake();
        await _mount(tester, fake);

        await _tap(tester, 'Regar');
        await tester.pump();
        expect(find.text('Detener riego'), findsOneWidget);
        expect(find.text(_completado), findsNothing);

        await tester.pump(const Duration(seconds: 10));
        await tester.pump();

        expect(find.text(_completado), findsOneWidget);
        expect(find.text('Regar'), findsOneWidget);
        expect(find.text('Detener riego'), findsNothing);

        await _finish(tester);
      },
    );

    for (final width in [320.0, 360.0]) {
      testWidgets(
        'la fila Info Detener riego Diagnósticos no se desborda a ${width.toInt()} px de ancho',
        (tester) async {
          tester.view.physicalSize = Size(width, 2600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final fake = _newFake()..pumpOn = true;

          // El detalle tiene otras filas que ya se desbordan en main: se
          // recogen los errores y la fila de botones se valida midiendo.
          final original = FlutterError.onError;
          final errores = <FlutterErrorDetails>[];
          FlutterError.onError = errores.add;
          try {
            await tester.pumpWidget(_app(fake));
            await tester.pump();
          } finally {
            FlutterError.onError = original;
          }

          // Solo se toleran errores de desborde (de otras filas)
          for (final e in errores) {
            expect(
              e.exceptionAsString(),
              contains('overflowed'),
              reason: 'Error inesperado distinto de un desborde: ${e.exception}',
            );
          }

          expect(find.text('Info'), findsOneWidget);
          expect(find.text('Detener riego'), findsOneWidget);
          expect(find.text('Diagnósticos'), findsOneWidget);

          // Fila que contiene los tres botones
          final fila = find
              .ancestor(of: find.text('Info'), matching: find.byType(Row))
              .evaluate()
              .map((el) => find.byWidget(el.widget))
              .firstWhere(
                (f) =>
                    find
                        .descendant(
                          of: f,
                          matching: find.text('Detener riego'),
                        )
                        .evaluate()
                        .isNotEmpty &&
                    find
                        .descendant(
                          of: f,
                          matching: find.text('Diagnósticos'),
                        )
                        .evaluate()
                        .isNotEmpty,
              );
          final filaRect = tester.getRect(fila);

          final rects = [
            _buttonRect(tester, 'Info'),
            _buttonRect(tester, 'Detener riego'),
            _buttonRect(tester, 'Diagnósticos'),
          ];
          for (final r in rects) {
            expect(r.left, greaterThanOrEqualTo(filaRect.left - 0.01));
            expect(r.right, lessThanOrEqualTo(filaRect.right + 0.01));
            expect(r.left, greaterThanOrEqualTo(-0.01));
            expect(r.right, lessThanOrEqualTo(width + 0.01));
          }
          // Sin solaparse entre sí
          expect(rects[0].right, lessThanOrEqualTo(rects[1].left + 0.01));
          expect(rects[1].right, lessThanOrEqualTo(rects[2].left + 0.01));

          // Etiquetas dentro de la pantalla
          for (final label in ['Info', 'Detener riego', 'Diagnósticos']) {
            final t = tester.getRect(find.text(label));
            expect(t.left, greaterThanOrEqualTo(-0.01));
            expect(t.right, lessThanOrEqualTo(width + 0.01));
          }

          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 15));
        },
      );
    }
  });

  group('CA-8 · sin dato en vivo no hay Detener riego', () {
    testWidgets('sin dato en vivo muestra Regar y no Detener riego', (
      tester,
    ) async {
      final fake = _newFake()..pumpOn = null;
      await _mount(tester, fake);

      expect(find.text('Regar'), findsOneWidget);
      expect(find.text('Detener riego'), findsNothing);

      await _finish(tester);
    });

    testWidgets(
      'una lectura guardada con la bomba encendida no basta para mostrar Detener riego',
      (tester) async {
        final fake = _newFake()
          ..pumpOn = null
          ..fakeSensorData = SensorDataModel.fromJson({
            'plant_id': 7,
            'plant_name': 'Echeveria',
            'pump_active': 1,
          });
        await _mount(tester, fake);

        expect(fake.fakeSensorData!.pumpActive, 1);
        expect(find.text('Regar'), findsOneWidget);
        expect(find.text('Detener riego'), findsNothing);

        await _finish(tester);
      },
    );

    testWidgets('con la bomba apagada en vivo muestra Regar', (tester) async {
      final fake = _newFake()..pumpOn = false;
      await _mount(tester, fake);

      expect(find.text('Regar'), findsOneWidget);
      expect(find.text('Detener riego'), findsNothing);

      await _finish(tester);
    });

    testWidgets(
      'si el dato en vivo se pierde Detener riego desaparece',
      (tester) async {
        final fake = _newFake()..pumpOn = true;
        await _mount(tester, fake);
        expect(find.text('Detener riego'), findsOneWidget);

        fake.setPumpOn(null);
        await tester.pump();

        expect(find.text('Detener riego'), findsNothing);
        expect(find.text('Regar'), findsOneWidget);

        await _finish(tester);
      },
    );
  });

  group('CA-9 y CA-13 · detener con confirmación', () {
    testWidgets(
      'mientras se confirma muestra Deteniendo con indicador de carga',
      (tester) async {
        final fake = _newFake()..pumpOn = true;
        await _mount(tester, fake);

        await _tap(tester, 'Detener riego');

        expect(fake.stopCalls, [7]);
        expect(find.text('Deteniendo…'), findsOneWidget);
        expect(find.text('Detener riego'), findsNothing);
        expect(
          find.descendant(
            of: _button('Deteniendo…'),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );

        // También mientras espera la confirmación del ESP8266 (API ya aceptó)
        fake.stopCompleter.complete(true);
        await tester.pump();
        expect(find.text('Deteniendo…'), findsOneWidget);
        expect(fake.stopCalls, [7]);

        await _finish(tester);
      },
    );

    testWidgets(
      'al confirmar la detención muestra Riego detenido con el aviso y vuelve Regar',
      (tester) async {
        final fake = _newFake()..pumpOn = true;
        await _mount(tester, fake);
        fake.pumpOnScript.add(false);

        await _stopAndAdvanceOneSecond(tester, fake);
        await tester.pump(); // pinta el SnackBar
        await tester.pump(const Duration(milliseconds: 300));

        expect(fake.sensorLoads, [7]);
        expect(find.text(_stopAviso), findsOneWidget);
        expect(find.text('Regar'), findsOneWidget);
        expect(find.text('Detener riego'), findsNothing);
        expect(find.text('Deteniendo…'), findsNothing);
        expect(_isTapEnabled(tester, 'Regar'), isTrue);
        expect(find.text(_completado), findsNothing);

        // «Regar» está habilitado de verdad
        await _tap(tester, 'Regar');
        expect(fake.activateCalls, [7]);

        await _finish(tester);
      },
    );

    testWidgets(
      'no dice Riego detenido hasta que el dato en vivo pasa a apagado',
      (tester) async {
        final fake = _newFake()..pumpOn = true;
        await _mount(tester, fake);
        // Primera vuelta: sigue encendida. Segunda: ya apagada.
        fake.pumpOnScript.addAll([true, false]);

        await _stopAndAdvanceOneSecond(tester, fake);
        await tester.pump();
        expect(find.textContaining('Riego detenido.'), findsNothing);
        expect(find.text('Deteniendo…'), findsOneWidget);

        await tester.pump(const Duration(seconds: 1));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fake.sensorLoads, [7, 7]);
        expect(find.text(_stopAviso), findsOneWidget);
        expect(find.text('Regar'), findsOneWidget);

        await _finish(tester);
      },
    );

    testWidgets(
      'después de detener no aparece Riego completado exitosamente',
      (tester) async {
        final fake = _newFake(); // sin dato en vivo
        await _mount(tester, fake);

        // Regar: el API acepta y aparece Detener riego
        await _tap(tester, 'Regar');
        await tester.pump();
        expect(find.text('Detener riego'), findsOneWidget);

        fake.pumpOnScript.add(false);
        await _stopAndAdvanceOneSecond(tester, fake);
        await tester.pump();
        expect(find.text(_stopAviso), findsOneWidget);
        expect(find.text(_completado), findsNothing);

        // Pasan de sobra los 10 s del riego: nunca aparece «completado»
        for (var s = 0; s < 12; s++) {
          await tester.pump(const Duration(seconds: 1));
          expect(find.text(_completado), findsNothing);
        }
        expect(find.text('Regar'), findsOneWidget);

        await _finish(tester);
      },
    );
  });

  group('CA-10 · sin confirmación del ESP8266', () {
    testWidgets(
      'si a los 10 s la bomba sigue encendida avisa que no se confirmó y deja Detener riego',
      (tester) async {
        final fake = _newFake()..pumpOn = true; // el script vacío no la apaga
        await _mount(tester, fake);

        await _tap(tester, 'Detener riego');
        fake.stopCompleter.complete(true);
        await tester.pump();

        for (var s = 1; s <= 10; s++) {
          expect(
            find.text(_sinConfirmar),
            findsNothing,
            reason: 'No debe avisar antes de los 10 s (segundo $s)',
          );
          await tester.pump(const Duration(seconds: 1));
        }
        await tester.pump(); // pinta el SnackBar
        await tester.pump(const Duration(milliseconds: 300));

        expect(fake.sensorLoads, hasLength(10));
        expect(find.text(_sinConfirmar), findsOneWidget);
        expect(find.textContaining('Riego detenido.'), findsNothing);
        expect(find.text('Deteniendo…'), findsNothing);
        expect(find.text('Detener riego'), findsOneWidget);
        expect(_isTapEnabled(tester, 'Detener riego'), isTrue);

        await _finish(tester);
      },
    );

    testWidgets(
      'si el ESP8266 deja de estar en línea avisa que no se confirmó',
      (tester) async {
        final fake = _newFake()..pumpOn = true;
        await _mount(tester, fake);
        fake.pumpOnScript.add(null); // dejó de estar en línea

        await _stopAndAdvanceOneSecond(tester, fake);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(_sinConfirmar), findsOneWidget);
        expect(find.textContaining('Riego detenido.'), findsNothing);
        expect(find.text('Deteniendo…'), findsNothing);
        expect(fake.sensorLoads, [7]);

        await _finish(tester);
      },
    );
  });

  group('CA-11 · error del API', () {
    testWidgets(
      'si el API responde error muestra su mensaje y deja Detener riego habilitado',
      (tester) async {
        const detail =
            'No se pudo detener el riego: el ESP8266 no está conectado al puerto serial del servidor.';
        final fake = _newFake()
          ..pumpOn = true
          ..fakeError = detail;
        await _mount(tester, fake);

        await _tap(tester, 'Detener riego');
        fake.stopCompleter.complete(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(detail), findsOneWidget);
        expect(find.text('Detener riego'), findsOneWidget);
        expect(find.text('Deteniendo…'), findsNothing);
        expect(_isTapEnabled(tester, 'Detener riego'), isTrue);
        expect(find.textContaining('Riego detenido.'), findsNothing);
        // Sin confirmación: no consulta sensores
        expect(fake.sensorLoads, isEmpty);

        await _finish(tester);
      },
    );

    testWidgets(
      'si el servidor no responde muestra el mensaje fijo y deja Detener riego habilitado',
      (tester) async {
        final fake = _newFake()
          ..pumpOn = true
          ..fakeError = null; // el provider real deja el mensaje fijo
        await _mount(tester, fake);

        await _tap(tester, 'Detener riego');
        fake.stopCompleter.complete(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text(_sinServidor), findsOneWidget);
        expect(find.text('Detener riego'), findsOneWidget);
        expect(_isTapEnabled(tester, 'Detener riego'), isTrue);
        expect(find.textContaining('Riego detenido.'), findsNothing);

        await _finish(tester);
      },
    );

    testWidgets('tras un error se puede volver a intentar', (tester) async {
      final fake = _newFake()
        ..pumpOn = true
        ..fakeError = 'Planta no encontrada';
      await _mount(tester, fake);

      await _tap(tester, 'Detener riego');
      fake.stopCompleter.complete(false);
      await tester.pump();
      expect(fake.stopCalls, [7]);

      fake.stopCompleter = Completer<bool>();
      await _tap(tester, 'Detener riego');
      expect(fake.stopCalls, [7, 7]);
      expect(find.text('Deteniendo…'), findsOneWidget);

      await _finish(tester);
    });
  });

  group('CA-12 · doble toque y cierre de pantalla', () {
    testWidgets(
      'un segundo toque mientras se detiene no envía otra petición',
      (tester) async {
        final fake = _newFake()..pumpOn = true;
        await _mount(tester, fake);

        await _tap(tester, 'Detener riego');
        expect(fake.stopCalls, [7]);

        // La orden aún no se confirma ni falla: se toca de nuevo el botón
        expect(_isTapEnabled(tester, 'Deteniendo…'), isFalse);
        await _tap(tester, 'Deteniendo…');
        await _tap(tester, 'Deteniendo…');
        expect(fake.stopCalls, [7]);

        // Ningún botón para regar ni para detener mientras tanto
        expect(find.text('Regar'), findsNothing);
        expect(find.text('Detener riego'), findsNothing);
        expect(fake.activateCalls, isEmpty);

        // Tampoco tras aceptar el API, mientras espera la confirmación
        fake.stopCompleter.complete(true);
        await tester.pump();
        await _tap(tester, 'Deteniendo…');
        expect(fake.stopCalls, [7]);
        expect(find.text('Regar'), findsNothing);
        expect(find.text('Detener riego'), findsNothing);
        expect(fake.activateCalls, isEmpty);

        await _finish(tester);
      },
    );

    testWidgets(
      'al cerrar la pantalla mientras espera la confirmación no hay errores',
      (tester) async {
        final fake = _newFake()..pumpOn = true;
        await _mount(tester, fake);
        fake.pumpOnScript.add(false); // si siguiera viva, confirmaría

        await _tap(tester, 'Detener riego');
        fake.stopCompleter.complete(true);
        await tester.pump();

        // Se cierra la pantalla con la confirmación pendiente
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 11));

        expect(tester.takeException(), isNull);
        // La espera murió con la pantalla: no pidió más datos
        expect(fake.sensorLoads, isEmpty);

        await _finish(tester);
      },
    );

    testWidgets(
      'al cerrar la pantalla mientras espera la respuesta del API tampoco hay errores',
      (tester) async {
        final fake = _newFake()..pumpOn = true;
        await _mount(tester, fake);

        await _tap(tester, 'Detener riego');
        await tester.pumpWidget(const SizedBox());

        // El API responde cuando la pantalla ya no existe
        fake.stopCompleter.complete(true);
        await tester.pump(const Duration(seconds: 11));

        expect(tester.takeException(), isNull);
        expect(fake.sensorLoads, isEmpty);

        await _finish(tester);
      },
    );

    testWidgets(
      'al cerrar la pantalla justo cuando el API devuelve error no hay errores',
      (tester) async {
        final fake = _newFake()
          ..pumpOn = true
          ..fakeError = 'fallo';
        await _mount(tester, fake);

        await _tap(tester, 'Detener riego');
        await tester.pumpWidget(const SizedBox());
        fake.stopCompleter.complete(false);
        await tester.pump(const Duration(seconds: 11));

        expect(tester.takeException(), isNull);

        await _finish(tester);
      },
    );
  });

  group('Revisión · obs. 1 y 3', () {
    testWidgets(
      'si Regar termina con éxito después de confirmar la detención no vuelve Detener riego ni Riego completado',
      (tester) async {
        final fake = _newFake() // sin dato en vivo
          ..activateCompleter = Completer<bool>();
        await _mount(tester, fake);

        // «Regar» queda pendiente: el API aún no responde
        await _tap(tester, 'Regar');
        expect(fake.activateCalls, [7]);

        // La bomba ya se ve encendida en vivo, así que aparece Detener riego
        fake.setPumpOn(true);
        await tester.pump();
        expect(find.text('Detener riego'), findsOneWidget);

        // Se detiene y se confirma mientras «Regar» sigue pendiente
        fake.pumpOnScript.add(false);
        await _stopAndAdvanceOneSecond(tester, fake);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text(_stopAviso), findsOneWidget);
        expect(find.text('Regar'), findsOneWidget);

        // Ahora la petición de «Regar» termina con éxito
        fake.activateCompleter!.complete(true);
        await tester.pump();
        await tester.pump();

        expect(find.text('Detener riego'), findsNothing);
        expect(find.text('Regar'), findsOneWidget);
        expect(_isTapEnabled(tester, 'Regar'), isTrue);
        expect(find.text(_completado), findsNothing);

        // Y tampoco aparece «completado» al pasar los 10 s
        for (var s = 0; s < 12; s++) {
          await tester.pump(const Duration(seconds: 1));
          expect(find.text(_completado), findsNothing);
        }
        expect(find.text('Regar'), findsOneWidget);
        expect(find.text('Detener riego'), findsNothing);

        await _finish(tester);
      },
    );

    testWidgets(
      'si loadSensorData lanza una excepción durante la confirmación sale de Deteniendo y avisa que no se confirmó',
      (tester) async {
        final fake = _newFake()
          ..pumpOn = true
          ..sensorLoadError = Exception('fallo de red');
        await _mount(tester, fake);

        await _stopAndAdvanceOneSecond(tester, fake);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fake.sensorLoads, isNotEmpty);
        expect(find.text('Deteniendo…'), findsNothing);
        expect(find.text(_sinConfirmar), findsOneWidget);
        expect(find.textContaining('Riego detenido.'), findsNothing);
        // La bomba sigue encendida en vivo: se puede volver a intentar
        expect(find.text('Detener riego'), findsOneWidget);
        expect(_isTapEnabled(tester, 'Detener riego'), isTrue);
        // Ninguna excepción sin capturar
        expect(tester.takeException(), isNull);

        await _finish(tester);
      },
    );
  });
}
