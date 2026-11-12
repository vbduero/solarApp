// Solar-Grow - Detalle de la planta sin datos inventados y con aviso de ejemplo
// Spec 005 · CA-6, CA-7, CA-11, CA-12, CA-14, CA-15, CA-16 y CA-20
// (decisiones D2, D3, D5, D7, D10 del plan).
//
// Sin red ni esperas reales: provider falso que extiende el real,
// AuthProvider sin sesión (no arranca el refresco de 3 s) y tiempo falso de
// flutter_test con `pump`. Nunca `pumpAndSettle`.
//
// Los textos van literales (no desde DemoMessages) para que la prueba falle
// si alguien los cambia.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/models/sensor_data_model.dart';
import 'package:solar_grow/providers/auth_provider.dart';
import 'package:solar_grow/providers/plant_provider.dart';
import 'package:solar_grow/screens/plant/plant_detail_screen.dart';
import 'package:solar_grow/widgets/sensor_card.dart';
import 'package:solar_grow/widgets/weather_bar.dart';

const _avisoEjemplo =
    'Modo demo: esta planta es de ejemplo y no tiene lecturas reales.';
const _sinConexion =
    'Sin conexión con el servidor: no se pueden mostrar las lecturas.';
const _noDisponible = 'No disponible en modo demo.';
const _completado = '¡Riego completado exitosamente!';

const _keyEjemplo = ValueKey('aviso-planta-ejemplo');
const _keySinConexion = ValueKey('aviso-sin-conexion');

/// PlantProvider falso: planta fija, lectura y estado que la prueba controla.
/// NO hace peticiones. Cuenta las llamadas a las acciones.
class _FakePlantProvider extends PlantProvider {
  _FakePlantProvider(this.fakeSelected, {SensorDataModel? data, bool? pump})
    : _data = data,
      _pumpOn = pump;

  final PlantModel fakeSelected;
  SensorDataModel? _data;
  bool _unavailable = false;
  final bool? _pumpOn;

  final List<int> activateCalls = [];
  final List<int> stopCalls = [];

  @override
  PlantModel? get selectedPlant => fakeSelected;

  @override
  SensorDataModel? get currentSensorData => _data;

  @override
  bool get sensorsUnavailable => _unavailable;

  @override
  bool? livePumpOn(int plantId) => _pumpOn;

  @override
  Future<void> loadSensorData(int plantId) async {}

  @override
  Future<bool> activateWatering(int plantId, {int durationSeconds = 10}) async {
    activateCalls.add(plantId);
    return true;
  }

  @override
  Future<bool> stopWatering(int plantId) async {
    stopCalls.add(plantId);
    return false;
  }

  void update({
    SensorDataModel? data,
    bool clearData = false,
    bool? unavailable,
  }) {
    if (data != null || clearData) _data = data;
    if (unavailable != null) _unavailable = unavailable;
    notifyListeners();
  }
}

PlantModel _demoPlant({DateTime? fertilize}) => PlantModel(
  id: 1,
  commonName: 'Echeveria',
  nextFertilizeDate: fertilize,
  isDemo: true,
);

PlantModel _realPlant({int id = 7, DateTime? fertilize}) =>
    PlantModel(id: id, commonName: 'Echeveria', nextFertilizeDate: fertilize);

SensorDataModel _empty([int id = 7]) =>
    SensorDataModel(plantId: id, plantName: 'Echeveria');

SensorDataModel _lectura({
  double? soil = 45,
  double? temp = 24,
  String estado = 'Sana',
}) => SensorDataModel(
  plantId: 7,
  plantName: 'Echeveria',
  soilHumidity: soil,
  temperature: temp,
  healthStatus: estado,
);

Widget _app(_FakePlantProvider fake) {
  return MultiProvider(
    providers: [
      // Sin sesión: el detalle no arranca su refresco de 3 s
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<PlantProvider>.value(value: fake),
    ],
    child: MaterialApp(
      routes: {
        '/plant-diagnoses': (_) => const Scaffold(body: Text('RUTA')),
        '/plant-info': (_) => const Scaffold(body: Text('RUTA')),
      },
      home: const PlantDetailScreen(),
    ),
  );
}

/// Monta el detalle. Otras filas del detalle ya se desbordan en main a 320 px
/// (fuera de esta spec): solo se toleran errores «overflowed»; cualquier otro
/// error falla la prueba. Los textos nuevos se validan con
/// [_expectTextoEntero], que mira el párrafo y no solo el rectángulo.
Future<void> _mount(
  WidgetTester tester,
  _FakePlantProvider fake, {
  double width = 900,
}) async {
  tester.view.physicalSize = Size(width, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final original = FlutterError.onError;
  final errores = <FlutterErrorDetails>[];
  FlutterError.onError = errores.add;
  try {
    await tester.pumpWidget(_app(fake));
    await tester.pump();
  } finally {
    FlutterError.onError = original;
  }
  for (final e in errores) {
    expect(
      e.exceptionAsString(),
      contains('overflowed'),
      reason: 'Error inesperado distinto de un desborde: ${e.exception}',
    );
  }
  if (width >= 600) {
    expect(errores, isEmpty, reason: 'a 900 px no debe haber desbordes');
  }
}

/// Desmonta y deja pasar el tiempo (planta animada y 10 s de «Regar»).
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 15));
}

/// El texto se ve entero: sin tope de líneas, sin ajuste desactivado, sin
/// recorte en el párrafo ya maquetado y dentro de la pantalla.
///
/// [dentroDePantalla] en false solo para «Sin fecha»: esa fila existe desde
/// antes (un Row sin Flexible) y con la fuente de pruebas (Ahem, cada letra
/// mide lo que el cuerpo) «Fertilizar: » ya ocupa más que la tarjeta. Aun así
/// se comprueba que el texto nuevo no se recorta ni se fuerza.
void _expectTextoEntero(
  WidgetTester tester,
  Finder texto,
  double ancho, {
  bool dentroDePantalla = true,
}) {
  final n = texto.evaluate().length;
  expect(n, greaterThan(0), reason: 'no se encontró el texto');
  for (var i = 0; i < n; i++) {
    final f = texto.at(i);
    final t = tester.widget<Text>(f);
    final etiqueta = t.data ?? t.textSpan?.toPlainText() ?? '?';
    expect(t.maxLines, isNull, reason: 'maxLines de "$etiqueta"');
    expect(t.softWrap, isNot(false), reason: 'softWrap de "$etiqueta"');
    expect(
      t.overflow,
      isNot(anyOf(TextOverflow.ellipsis, TextOverflow.fade)),
      reason: 'overflow de "$etiqueta"',
    );
    final p = tester.renderObject<RenderParagraph>(f);
    expect(p.didExceedMaxLines, isFalse, reason: '"$etiqueta" se recorta');
    expect(
      p.getMinIntrinsicWidth(double.infinity),
      lessThanOrEqualTo(p.size.width + 0.5),
      reason: 'la palabra más ancha de "$etiqueta" no cabe',
    );
    final r = tester.getRect(f);
    expect(r.width, greaterThan(0), reason: etiqueta);
    if (!dentroDePantalla) continue;
    expect(r.left, greaterThanOrEqualTo(-0.01), reason: etiqueta);
    expect(r.right, lessThanOrEqualTo(ancho + 0.01), reason: etiqueta);
  }
}

/// Texto completo de la fila «Fertilizar» (la que lleva el icono de ciencia),
/// sin depender de si está en uno o en varios Text.
String _filaFertilizar(WidgetTester tester) {
  final fila = find.ancestor(
    of: find.byIcon(Icons.science_outlined),
    matching: find.byType(Row),
  );
  final textos = find.descendant(of: fila.first, matching: find.byType(Text));
  return tester
      .widgetList<Text>(textos)
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .join();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  group('CA-6 · detalle de una planta de ejemplo', () {
    testWidgets(
      'una planta de ejemplo muestra su aviso, Sin datos y sin lecturas',
      (tester) async {
        final fake = _FakePlantProvider(_demoPlant(), data: _empty(1));
        await _mount(tester, fake);

        expect(find.byKey(_keyEjemplo), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(_keyEjemplo),
            matching: find.text(_avisoEjemplo),
          ),
          findsOneWidget,
        );
        // Humedad y temperatura: «Sin datos» en cada tarjeta
        expect(find.text('Sin datos'), findsNWidgets(2));
        expect(find.text('Según sensores: sin lecturas'), findsOneWidget);
        // Nunca números inventados
        expect(find.textContaining(' %'), findsNothing);
        expect(find.textContaining('°C'), findsNothing);
        // La planta es de ejemplo: no se dice que falló la conexión
        expect(find.byKey(_keySinConexion), findsNothing);
        expect(find.text(_sinConexion), findsNothing);

        await _finish(tester);
      },
    );

    testWidgets(
      'una planta de ejemplo sin lectura todavía (nula) también muestra el aviso y Sin datos',
      (tester) async {
        final fake = _FakePlantProvider(_demoPlant()); // currentSensorData nulo
        await _mount(tester, fake);

        expect(find.byKey(_keyEjemplo), findsOneWidget);
        expect(find.text('Sin datos'), findsNWidgets(2));
        expect(find.text('Según sensores: sin lecturas'), findsOneWidget);

        await _finish(tester);
      },
    );

    testWidgets(
      'como mucho un aviso: planta de ejemplo con sensorsUnavailable',
      (tester) async {
        final fake = _FakePlantProvider(_demoPlant(), data: _empty(1))
          ..update(unavailable: true);
        await _mount(tester, fake);

        expect(find.byKey(_keyEjemplo), findsOneWidget);
        expect(find.byKey(_keySinConexion), findsNothing);
        expect(find.text(_sinConexion), findsNothing);

        await _finish(tester);
      },
    );

    testWidgets('una planta real no muestra el aviso de ejemplo (CA-3)', (
      tester,
    ) async {
      final fake = _FakePlantProvider(_realPlant(), data: _lectura());
      await _mount(tester, fake);

      expect(find.byKey(_keyEjemplo), findsNothing);
      expect(find.text(_avisoEjemplo), findsNothing);
      expect(find.byKey(_keySinConexion), findsNothing);
      expect(find.textContaining('Modo demo'), findsNothing);

      await _finish(tester);
    });
  });

  group('CA-7 · acciones sobre una planta de ejemplo', () {
    void expectNadaPasa(WidgetTester tester, _FakePlantProvider fake) {
      expect(find.text(_noDisponible), findsOneWidget);
      expect(fake.activateCalls, isEmpty);
      expect(fake.stopCalls, isEmpty);
      expect(find.text('RUTA'), findsNothing);
      expect(find.text('Tipo de tarea'), findsNothing);
      expect(find.text(_completado), findsNothing);
      expect(find.textContaining('Tarea programada'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }

    testWidgets(
      'Regar sobre una planta de ejemplo avisa y no llama al provider',
      (tester) async {
        final fake = _FakePlantProvider(_demoPlant(), data: _empty(1));
        await _mount(tester, fake);

        await _tap(tester, 'Regar');
        await tester.pump(const Duration(milliseconds: 300));

        expectNadaPasa(tester, fake);
        // El botón sigue siendo «Regar»: no se queda en estado de riego
        expect(find.text('Regar'), findsOneWidget);
        expect(find.text('Detener riego'), findsNothing);

        // Pasan de sobra los 10 s del riego: nunca aparece «completado»
        await tester.pump(const Duration(seconds: 12));
        expect(find.text(_completado), findsNothing);
        expect(fake.activateCalls, isEmpty);

        await _finish(tester);
      },
    );

    testWidgets(
      'Programar tarea sobre una planta de ejemplo avisa y no abre el formulario',
      (tester) async {
        final fake = _FakePlantProvider(_demoPlant(), data: _empty(1));
        await _mount(tester, fake);

        await _tap(tester, 'Programar tarea');
        await tester.pump(const Duration(milliseconds: 300));

        expectNadaPasa(tester, fake);

        await _finish(tester);
      },
    );

    testWidgets('Diagnósticos sobre una planta de ejemplo avisa y no navega', (
      tester,
    ) async {
      final fake = _FakePlantProvider(_demoPlant(), data: _empty(1));
      await _mount(tester, fake);

      await _tap(tester, 'Diagnósticos');
      await tester.pump(const Duration(seconds: 1));

      expectNadaPasa(tester, fake);

      await _finish(tester);
    });

    testWidgets(
      'Detener riego sobre una planta de ejemplo avisa y no llama a stopWatering',
      (tester) async {
        // Caso defensivo: aunque el provider dijera que la bomba está
        // encendida, una planta de ejemplo no manda nada
        final fake = _FakePlantProvider(
          _demoPlant(),
          data: _empty(1),
          pump: true,
        );
        await _mount(tester, fake);
        expect(find.text('Detener riego'), findsOneWidget);

        await _tap(tester, 'Detener riego');
        await tester.pump(const Duration(milliseconds: 300));

        expectNadaPasa(tester, fake);
        expect(find.text('Deteniendo…'), findsNothing);

        await _finish(tester);
      },
    );

    testWidgets('Regar en una planta real con id 1 llama a activateWatering', (
      tester,
    ) async {
      // El bloqueo va por planta de ejemplo, no por id: la Echeveria 1
      // sembrada en el servidor se riega con normalidad.
      final fake = _FakePlantProvider(_realPlant(id: 1), data: _lectura());
      await _mount(tester, fake);

      await _tap(tester, 'Regar');
      await tester.pump();

      expect(fake.activateCalls, [1]);
      expect(find.text(_noDisponible), findsNothing);

      await _finish(tester);
    });

    testWidgets(
      'en una planta real Diagnósticos navega y no dice No disponible en modo demo',
      (tester) async {
        final fake = _FakePlantProvider(_realPlant(), data: _lectura());
        await _mount(tester, fake);

        await _tap(tester, 'Diagnósticos');
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('RUTA'), findsOneWidget);
        expect(find.text(_noDisponible), findsNothing);

        await _finish(tester);
      },
    );

    testWidgets(
      'Detener riego en una planta real sigue funcionando (spec 003)',
      (tester) async {
        final fake = _FakePlantProvider(
          _realPlant(),
          data: _lectura(),
          pump: true,
        );
        await _mount(tester, fake);
        expect(find.text('Detener riego'), findsOneWidget);

        await _tap(tester, 'Detener riego');

        expect(fake.stopCalls, [7]);
        expect(find.text(_noDisponible), findsNothing);

        await _finish(tester);
      },
    );
  });

  group('CA-11 · fallan las lecturas de una planta real', () {
    testWidgets(
      'si las lecturas fallan se ve Sin conexión y Sin datos, sin el aviso de ejemplo',
      (tester) async {
        final fake = _FakePlantProvider(_realPlant(), data: _empty())
          ..update(unavailable: true);
        await _mount(tester, fake);

        expect(find.byKey(_keySinConexion), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(_keySinConexion),
            matching: find.text(_sinConexion),
          ),
          findsOneWidget,
        );
        expect(find.text('Sin datos'), findsNWidgets(2));
        expect(find.text('Según sensores: sin lecturas'), findsOneWidget);
        // Nunca 50 %, 26 °C, «0 %» ni «0 °C»
        expect(find.textContaining(' %'), findsNothing);
        expect(find.textContaining('°C'), findsNothing);
        expect(find.text('50 %'), findsNothing);
        expect(find.text('26 °C'), findsNothing);
        // La planta es real: ni aviso de ejemplo ni modo demo
        expect(find.byKey(_keyEjemplo), findsNothing);
        expect(find.text(_avisoEjemplo), findsNothing);
        expect(find.textContaining('Modo demo'), findsNothing);

        await _finish(tester);
      },
    );

    testWidgets(
      'cuando vuelve una lectura desaparece Sin conexión y se ven los valores',
      (tester) async {
        final fake = _FakePlantProvider(_realPlant(), data: _empty())
          ..update(unavailable: true);
        await _mount(tester, fake);
        expect(find.text(_sinConexion), findsOneWidget);

        fake.update(data: _lectura(soil: 45, temp: 24), unavailable: false);
        await tester.pump();

        expect(find.text(_sinConexion), findsNothing);
        expect(find.byKey(_keySinConexion), findsNothing);
        expect(find.text('45 %'), findsOneWidget);
        expect(find.text('24 °C'), findsOneWidget);
        expect(find.text('Sin datos'), findsNothing);
        expect(find.text('Según sensores: Sana'), findsOneWidget);

        await _finish(tester);
      },
    );
  });

  group('CA-12 · sin lecturas o lectura incompleta', () {
    testWidgets(
      'sin lecturas o antes de la primera carga se ve Sin datos y nunca 0 %',
      (tester) async {
        // 1) antes de la primera respuesta (currentSensorData nulo)
        final antes = _FakePlantProvider(_realPlant());
        await _mount(tester, antes);
        expect(find.text('Sin datos'), findsNWidgets(2));
        expect(find.textContaining(' %'), findsNothing);
        expect(find.textContaining('°C'), findsNothing);
        expect(find.text(_sinConexion), findsNothing);
        expect(find.byKey(_keySinConexion), findsNothing);
        expect(find.byKey(_keyEjemplo), findsNothing);
        await _finish(tester);

        // 2) el servidor respondió 200 con las lecturas en null
        final vacia = _FakePlantProvider(
          _realPlant(),
          data: SensorDataModel.fromJson({
            'plant_id': 7,
            'plant_name': 'Echeveria',
            'temperature': null,
            'soil_humidity': null,
            'health_status': 'Sin datos',
            'health_score': null,
          }),
        );
        await _mount(tester, vacia);
        expect(find.text('Sin datos'), findsNWidgets(2));
        expect(find.text('0 %'), findsNothing);
        expect(find.text('0 °C'), findsNothing);
        expect(find.text(_sinConexion), findsNothing);
        expect(find.byKey(_keySinConexion), findsNothing);
        expect(find.text('Según sensores: sin lecturas'), findsOneWidget);
        await _finish(tester);
      },
    );

    testWidgets('con temperatura y sin suelo se ve 24 °C y Sin datos', (
      tester,
    ) async {
      final fake = _FakePlantProvider(
        _realPlant(),
        data: _lectura(soil: null, temp: 24),
      );
      await _mount(tester, fake);

      expect(find.text('24 °C'), findsOneWidget);
      expect(find.text('Sin datos'), findsOneWidget);
      expect(find.text('0 %'), findsNothing);
      expect(find.textContaining(' %'), findsNothing);
      expect(find.text(_sinConexion), findsNothing);

      await _finish(tester);
    });

    testWidgets('con suelo y sin temperatura se ve 40 % y Sin datos', (
      tester,
    ) async {
      final fake = _FakePlantProvider(
        _realPlant(),
        data: _lectura(soil: 40, temp: null),
      );
      await _mount(tester, fake);

      expect(find.text('40 %'), findsOneWidget);
      expect(find.text('Sin datos'), findsOneWidget);
      expect(find.text('0 °C'), findsNothing);
      expect(find.textContaining('°C'), findsNothing);

      await _finish(tester);
    });
  });

  group('CA-14 · luz, voltaje y batería', () {
    testWidgets('el detalle no muestra luz, voltaje ni batería', (
      tester,
    ) async {
      final fake = _FakePlantProvider(
        _realPlant(),
        data: SensorDataModel(
          plantId: 7,
          plantName: 'Echeveria',
          soilHumidity: 45,
          temperature: 24,
          lightLevel: 67,
          solarVoltage: 15.5,
          batteryLevel: 85,
          healthStatus: 'Sana',
        ),
      );
      await _mount(tester, fake);

      for (final palabra in [
        'Luz',
        'luz',
        'Voltaje',
        'voltaje',
        'Batería',
        'batería',
        'Panel',
        'lux',
        '15.5',
        '67',
        '85',
      ]) {
        expect(
          find.textContaining(palabra),
          findsNothing,
          reason: 'no debe mostrarse "$palabra"',
        );
      }
      expect(find.byType(SensorCard), findsNothing);

      await _finish(tester);
    });
  });

  group('CA-15 · sin clima', () {
    testWidgets('el detalle no muestra clima', (tester) async {
      final fake = _FakePlantProvider(_realPlant(), data: _lectura());
      await _mount(tester, fake);

      expect(find.byType(WeatherBar), findsNothing);
      expect(find.textContaining('Parcialmente'), findsNothing);
      expect(find.textContaining('nublado'), findsNothing);
      expect(find.textContaining('soleado'), findsNothing);
      expect(find.textContaining('Neiva'), findsNothing);
      // La temperatura del sensor solo aparece en su tarjeta (una vez)
      expect(find.text('24 °C'), findsOneWidget);
      expect(find.textContaining('24°C'), findsNothing);
      expect(find.textContaining('26'), findsNothing);

      await _finish(tester);
    });

    testWidgets('el detalle de una planta de ejemplo tampoco muestra clima', (
      tester,
    ) async {
      final fake = _FakePlantProvider(_demoPlant(), data: _empty(1));
      await _mount(tester, fake);

      expect(find.byType(WeatherBar), findsNothing);
      expect(find.textContaining('Parcialmente'), findsNothing);
      expect(find.textContaining('26'), findsNothing);

      await _finish(tester);
    });
  });

  group('CA-16 · Fertilizar', () {
    testWidgets('Fertilizar muestra Sin fecha cuando no hay fecha', (
      tester,
    ) async {
      final fake = _FakePlantProvider(_realPlant(), data: _lectura());
      await _mount(tester, fake);

      expect(_filaFertilizar(tester), 'Fertilizar: Sin fecha');
      expect(find.textContaining('26 de Junio'), findsNothing);
      expect(find.textContaining('Junio'), findsNothing);

      await _finish(tester);
    });

    testWidgets('Fertilizar muestra la fecha real cuando existe', (
      tester,
    ) async {
      final fake = _FakePlantProvider(
        _realPlant(fertilize: DateTime(2026, 12, 3)),
        data: _lectura(),
      );
      await _mount(tester, fake);

      expect(_filaFertilizar(tester), 'Fertilizar: 3 de Diciembre');
      expect(find.textContaining('Sin fecha'), findsNothing);

      await _finish(tester);
    });
  });

  group('CA-20 · nada se desborda ni se corta', () {
    for (final ancho in [320.0, 360.0]) {
      testWidgets(
        'avisos, Sin datos y Sin fecha se ven enteros a ${ancho.toInt()} px (planta de ejemplo)',
        (tester) async {
          final fake = _FakePlantProvider(_demoPlant(), data: _empty(1));
          await _mount(tester, fake, width: ancho);

          _expectTextoEntero(tester, find.text(_avisoEjemplo), ancho);
          _expectTextoEntero(tester, find.text('Sin datos'), ancho);
          _expectTextoEntero(
            tester,
            find.textContaining('Sin fecha'),
            ancho,
            dentroDePantalla: false,
          );

          // El texto del aviso está dentro de su caja y de la pantalla
          final aviso = tester.getRect(find.byKey(_keyEjemplo));
          expect(aviso.left, greaterThanOrEqualTo(-0.01));
          expect(aviso.right, lessThanOrEqualTo(ancho + 0.01));

          await _finish(tester);
        },
      );

      testWidgets(
        'el texto de Sin conexión y Sin datos se ve entero a ${ancho.toInt()} px (planta real)',
        (tester) async {
          final fake = _FakePlantProvider(_realPlant(), data: _empty())
            ..update(unavailable: true);
          await _mount(tester, fake, width: ancho);

          _expectTextoEntero(tester, find.text(_sinConexion), ancho);
          _expectTextoEntero(tester, find.text('Sin datos'), ancho);
          _expectTextoEntero(
            tester,
            find.textContaining('Sin fecha'),
            ancho,
            dentroDePantalla: false,
          );

          final aviso = tester.getRect(find.byKey(_keySinConexion));
          expect(aviso.left, greaterThanOrEqualTo(-0.01));
          expect(aviso.right, lessThanOrEqualTo(ancho + 0.01));

          await _finish(tester);
        },
      );

    }
  });

  group('Specs 003 y 004 siguen en una planta real', () {
    testWidgets('la etiqueta Según sensores muestra el estado del backend', (
      tester,
    ) async {
      final fake = _FakePlantProvider(
        _realPlant(),
        data: _lectura(estado: 'Necesita agua'),
      );
      await _mount(tester, fake);

      expect(find.text('Según sensores: Necesita agua'), findsOneWidget);
      expect(find.text('45 %'), findsOneWidget);
      expect(find.text('24 °C'), findsOneWidget);

      await _finish(tester);
    });
  });
}
