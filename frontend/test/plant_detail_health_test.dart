// Solar-Grow - Pruebas del estado «según sensores» en el detalle de la planta
// Spec 004 · CA-9 a CA-12 (decisiones D7 y D8 del plan).
//
// Sin red ni esperas reales: provider falso, AuthProvider sin sesión (no
// arranca el refresco de 3 s) y tiempo falso de flutter_test con `pump`.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solar_grow/config/theme.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/models/sensor_data_model.dart';
import 'package:solar_grow/providers/auth_provider.dart';
import 'package:solar_grow/providers/plant_provider.dart';
import 'package:solar_grow/screens/plant/plant_detail_screen.dart';

/// PlantProvider falso: planta fija (id 7) y lectura que la prueba puede
/// cambiar. `livePumpOn` no se sobreescribe (devuelve null: se ve «Regar»).
class _FakePlantProvider extends PlantProvider {
  _FakePlantProvider(this.fakeSelected, [this._data]);

  final PlantModel fakeSelected;
  SensorDataModel? _data;

  @override
  PlantModel? get selectedPlant => fakeSelected;

  @override
  SensorDataModel? get currentSensorData => _data;

  void setData(SensorDataModel? data) {
    _data = data;
    notifyListeners();
  }

  @override
  Future<void> loadSensorData(int plantId) async {}
}

SensorDataModel _data(
  String estado, {
  double? score,
  double? soil = 20,
  double? temp = 28,
}) {
  return SensorDataModel(
    plantId: 7,
    plantName: 'Echeveria',
    soilHumidity: soil,
    temperature: temp,
    airHumidity: 50,
    healthStatus: estado,
    healthScore: score,
  );
}

_FakePlantProvider _fake([SensorDataModel? data]) => _FakePlantProvider(
  PlantModel(id: 7, commonName: 'Echeveria'),
  data,
);

Widget _app(_FakePlantProvider fake) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
      ChangeNotifierProvider<PlantProvider>.value(value: fake),
    ],
    child: const MaterialApp(home: PlantDetailScreen()),
  );
}

Future<void> _mount(
  WidgetTester tester,
  _FakePlantProvider fake, {
  double width = 900,
}) async {
  tester.view.physicalSize = Size(width, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app(fake));
  await tester.pump();
}

/// Desmonta y deja pasar el tiempo para que termine el temporizador de
/// parpadeo de AnimatedPlantWidget. Nunca `pumpAndSettle`.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 10));
}

const _bocaFeliz = ValueKey('boca-feliz');
const _bocaTriste = ValueKey('boca-triste');
const _bocaCritica = ValueKey('boca-critica');

void _expectCara(ValueKey<String> esperada) {
  for (final key in [_bocaFeliz, _bocaTriste, _bocaCritica]) {
    expect(
      find.byKey(key),
      key == esperada ? findsOneWidget : findsNothing,
      reason: 'boca ${key.value} (esperada: ${esperada.value})',
    );
  }
}

/// Color del icono de «Regar»: error = resaltado, primaryDark = normal.
Color? _colorRegar(WidgetTester tester) =>
    tester.widget<Icon>(find.byIcon(Icons.water_drop_outlined)).color;

void _expectRegar(WidgetTester tester, {required bool resaltado}) {
  expect(
    _colorRegar(tester),
    resaltado ? SolarColors.error : SolarColors.primaryDark,
  );
}

void main() {
  // Tabla de CA-9: estado, etiqueta, cara y «Regar»
  final tabla = <({
    String estado,
    String etiqueta,
    ValueKey<String> cara,
    bool resaltado,
  })>[
    (
      estado: 'Sana',
      etiqueta: 'Según sensores: Sana',
      cara: _bocaFeliz,
      resaltado: false,
    ),
    (
      estado: 'Necesita agua',
      etiqueta: 'Según sensores: Necesita agua',
      cara: _bocaTriste,
      resaltado: true,
    ),
    (
      estado: 'Exceso de calor',
      etiqueta: 'Según sensores: Exceso de calor',
      cara: _bocaTriste,
      resaltado: false,
    ),
    (
      estado: 'Critica',
      etiqueta: 'Según sensores: Crítica',
      cara: _bocaCritica,
      resaltado: true,
    ),
    (
      estado: 'Sin datos',
      etiqueta: 'Según sensores: sin lecturas',
      cara: _bocaFeliz, // ni triste ni crítica (D7: usa la cara feliz)
      resaltado: false,
    ),
  ];

  for (final fila in tabla) {
    testWidgets(
      'muestra etiqueta, cara y Regar según el estado: ${fila.estado}',
      (tester) async {
        await _mount(tester, _fake(_data(fila.estado, score: 75)));

        expect(find.text(fila.etiqueta), findsOneWidget);
        _expectCara(fila.cara);
        _expectRegar(tester, resaltado: fila.resaltado);

        await _finish(tester);
      },
    );
  }

  testWidgets('Sin datos no es cara triste ni crítica', (tester) async {
    await _mount(tester, _fake(_data('Sin datos')));

    expect(find.byKey(_bocaTriste), findsNothing);
    expect(find.byKey(_bocaCritica), findsNothing);

    await _finish(tester);
  });

  group('la cara depende del estado y no del puntaje', () {
    testWidgets('Necesita agua con 65 se ve triste y con Regar resaltado', (
      tester,
    ) async {
      await _mount(tester, _fake(_data('Necesita agua', score: 65)));

      _expectCara(_bocaTriste);
      _expectRegar(tester, resaltado: true);
      expect(find.text('Según sensores: Necesita agua'), findsOneWidget);

      await _finish(tester);
    });

    testWidgets('Sana con 90 se ve feliz', (tester) async {
      await _mount(tester, _fake(_data('Sana', score: 90)));

      _expectCara(_bocaFeliz);
      _expectRegar(tester, resaltado: false);

      await _finish(tester);
    });

    testWidgets('Sana con puntaje bajo (20) sigue feliz y sin resaltar', (
      tester,
    ) async {
      await _mount(tester, _fake(_data('Sana', score: 20)));

      _expectCara(_bocaFeliz);
      _expectRegar(tester, resaltado: false);

      await _finish(tester);
    });

    testWidgets('Critica con puntaje alto (95) sigue crítica', (tester) async {
      await _mount(tester, _fake(_data('Critica', score: 95)));

      _expectCara(_bocaCritica);
      _expectRegar(tester, resaltado: true);

      await _finish(tester);
    });

    testWidgets('Exceso de calor con 85 se ve triste', (tester) async {
      await _mount(tester, _fake(_data('Exceso de calor', score: 85)));

      _expectCara(_bocaTriste);
      _expectRegar(tester, resaltado: false);

      await _finish(tester);
    });

    testWidgets('Necesita agua con puntaje nulo no rompe y se ve triste', (
      tester,
    ) async {
      await _mount(tester, _fake(_data('Necesita agua', score: null)));

      expect(tester.takeException(), isNull);
      _expectCara(_bocaTriste);
      expect(find.text('Según sensores: Necesita agua'), findsOneWidget);

      await _finish(tester);
    });

    testWidgets('el humedad del suelo no decide la cara ni Regar', (
      tester,
    ) async {
      // Suelo 0 % pero el backend dice Sana: la app no recalcula
      await _mount(tester, _fake(_data('Sana', score: 100, soil: 0, temp: 45)));

      expect(find.text('Según sensores: Sana'), findsOneWidget);
      _expectCara(_bocaFeliz);
      _expectRegar(tester, resaltado: false);

      await _finish(tester);
    });
  });

  group('la etiqueta Según sensores no se sale de la pantalla', () {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        'la etiqueta Según sensores no se sale de la pantalla a ${width.toInt()} px',
        (tester) async {
          tester.view.physicalSize = Size(width, 2600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          // Otras filas del detalle ya se desbordan en main (fuera de esta
          // spec): se recogen los errores y la etiqueta se valida midiéndola.
          final original = FlutterError.onError;
          final errores = <FlutterErrorDetails>[];
          FlutterError.onError = errores.add;
          try {
            await tester.pumpWidget(
              _app(_fake(_data('Exceso de calor', score: 85))),
            );
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

          final etiqueta = find.text('Según sensores: Exceso de calor');
          expect(etiqueta, findsOneWidget);
          final rect = tester.getRect(etiqueta);
          expect(rect.left, greaterThanOrEqualTo(-0.01));
          expect(rect.right, lessThanOrEqualTo(width + 0.01));
          expect(rect.width, greaterThan(0));

          // Ningún error de desborde puede ser de la etiqueta: se comprueba
          // que el texto no ocupa más que el ancho de la pantalla.
          expect(rect.width, lessThanOrEqualTo(width));

          await _finish(tester);
        },
      );
    }

    testWidgets('la etiqueta más larga (sin lecturas / Crítica) cabe a 320 px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final original = FlutterError.onError;
      FlutterError.onError = (_) {};
      try {
        for (final entrada in {
          'Sin datos': 'Según sensores: sin lecturas',
          'Critica': 'Según sensores: Crítica',
          'Necesita agua': 'Según sensores: Necesita agua',
        }.entries) {
          final fake = _fake(_data(entrada.key));
          await tester.pumpWidget(_app(fake));
          await tester.pump();
          final rect = tester.getRect(find.text(entrada.value));
          expect(rect.left, greaterThanOrEqualTo(-0.01));
          expect(rect.right, lessThanOrEqualTo(320.01));
        }
      } finally {
        FlutterError.onError = original;
      }

      await _finish(tester);
    });
  });

  group('la etiqueta Según sensores hace salto de línea y no se recorta', () {
    // El rectángulo del Text nunca se sale aunque el texto se recorte, así que
    // se revisa el párrafo ya maquetado. No depende de la fuente: solo de las
    // banderas de maquetación y de las cajas del texto dentro del párrafo.
    testWidgets(
      'la etiqueta Según sensores no se corta y hace salto de línea a 320 px',
      (tester) async {
        tester.view.physicalSize = const Size(320, 2600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final original = FlutterError.onError;
        FlutterError.onError = (_) {}; // desbordes de otras filas (fuera de spec)
        try {
          for (final entrada in {
            'Exceso de calor': 'Según sensores: Exceso de calor',
            'Necesita agua': 'Según sensores: Necesita agua',
            'Sin datos': 'Según sensores: sin lecturas',
            'Critica': 'Según sensores: Crítica',
          }.entries) {
            await tester.pumpWidget(_app(_fake(_data(entrada.key, score: 50))));
            await tester.pump();

            final finder = find.text(entrada.value);
            expect(finder, findsOneWidget);

            // Configuración del widget: sin tope de líneas ni ajuste desactivado
            final texto = tester.widget<Text>(finder);
            expect(texto.maxLines, isNull, reason: entrada.value);
            expect(texto.softWrap, isNot(false), reason: entrada.value);
            expect(
              texto.overflow,
              isNot(anyOf(TextOverflow.ellipsis, TextOverflow.fade)),
              reason: entrada.value,
            );

            // Párrafo maquetado: nada se pierde ni se pinta fuera de su caja
            final parrafo = tester.renderObject<RenderParagraph>(finder);
            expect(parrafo.maxLines, isNull, reason: entrada.value);
            expect(parrafo.softWrap, isTrue, reason: entrada.value);
            expect(parrafo.didExceedMaxLines, isFalse, reason: entrada.value);

            final cajas = parrafo.getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: entrada.value.length,
              ),
            );
            expect(cajas, isNotEmpty, reason: entrada.value);
            for (final caja in cajas) {
              expect(caja.left, greaterThanOrEqualTo(-0.01));
              expect(
                caja.right,
                lessThanOrEqualTo(parrafo.size.width + 0.01),
                reason: 'texto pintado fuera del ancho: ${entrada.value}',
              );
            }

            // Y el párrafo cabe en la pantalla de 320 px
            final rect = tester.getRect(finder);
            expect(rect.left, greaterThanOrEqualTo(-0.01));
            expect(rect.right, lessThanOrEqualTo(320.01));
          }
        } finally {
          FlutterError.onError = original;
        }

        await _finish(tester);
      },
    );
  });

  group('CA-10 la misma planta, la misma cara', () {
    testWidgets(
      'pasar de dato en vivo a lectura guardada con el mismo estado no cambia lo que se ve',
      (tester) async {
        final fake = _fake(
          _data('Necesita agua', score: 90, soil: 20, temp: 28),
        );
        await _mount(tester, fake);

        expect(find.text('Según sensores: Necesita agua'), findsOneWidget);
        _expectCara(_bocaTriste);
        _expectRegar(tester, resaltado: true);

        // Llega la lectura guardada: otros números, mismo estado
        fake.setData(_data('Necesita agua', score: 90, soil: 60, temp: 20));
        await tester.pump();

        expect(find.text('Según sensores: Necesita agua'), findsOneWidget);
        _expectCara(_bocaTriste);
        _expectRegar(tester, resaltado: true);

        await _finish(tester);
      },
    );

    testWidgets(
      'si el backend manda Sana aunque las lecturas parezcan secas se muestra Sana',
      (tester) async {
        final fake = _fake(
          _data('Sana', score: 100, soil: 0, temp: 45),
        );
        await _mount(tester, fake);

        expect(find.text('Según sensores: Sana'), findsOneWidget);
        _expectCara(_bocaFeliz);
        _expectRegar(tester, resaltado: false);

        await _finish(tester);
      },
    );

    testWidgets('cambiar de estado actualiza etiqueta, cara y Regar', (
      tester,
    ) async {
      final fake = _fake(_data('Sana', score: 100));
      await _mount(tester, fake);
      _expectCara(_bocaFeliz);

      fake.setData(_data('Critica', score: 30));
      await tester.pump();

      expect(find.text('Según sensores: Crítica'), findsOneWidget);
      expect(find.text('Según sensores: Sana'), findsNothing);
      _expectCara(_bocaCritica);
      _expectRegar(tester, resaltado: true);

      await _finish(tester);
    });
  });

  group('CA-11 sin lecturas o antes de la primera carga', () {
    testWidgets(
      'antes de la primera carga muestra sin lecturas y no resalta Regar',
      (tester) async {
        // currentSensorData nulo: el detalle usa su respaldo
        await _mount(tester, _fake());

        expect(find.text('Según sensores: sin lecturas'), findsOneWidget);
        expect(find.text('Según sensores: Sana'), findsNothing);
        _expectCara(_bocaFeliz);
        _expectRegar(tester, resaltado: false);
        expect(find.byKey(_bocaTriste), findsNothing);
        expect(find.byKey(_bocaCritica), findsNothing);

        await _finish(tester);
      },
    );

    testWidgets('lectura vacía (API caído) muestra sin lecturas, nunca Sana', (
      tester,
    ) async {
      await _mount(tester, _fake(SensorDataModel.empty(7, 'Echeveria')));

      expect(find.text('Según sensores: sin lecturas'), findsOneWidget);
      expect(find.text('Según sensores: Sana'), findsNothing);
      _expectRegar(tester, resaltado: false);

      await _finish(tester);
    });

    testWidgets('planta sin lecturas (Sin datos y puntaje null) no rompe', (
      tester,
    ) async {
      await _mount(
        tester,
        _fake(
          SensorDataModel.fromJson({
            'plant_id': 7,
            'plant_name': 'Echeveria',
            'health_status': 'Sin datos',
            'health_score': null,
          }),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Según sensores: sin lecturas'), findsOneWidget);
      _expectRegar(tester, resaltado: false);

      await _finish(tester);
    });

    testWidgets('un estado en inglés del backend viejo se ve como sin lecturas', (
      tester,
    ) async {
      await _mount(
        tester,
        _fake(
          SensorDataModel.fromJson({
            'plant_id': 7,
            'plant_name': 'Echeveria',
            'health_status': 'needs_water',
            'health_score': 40.0,
          }),
        ),
      );

      expect(find.text('Según sensores: sin lecturas'), findsOneWidget);
      _expectRegar(tester, resaltado: false);

      await _finish(tester);
    });
  });

  group('CA-12 el diagnóstico IA es otra cosa', () {
    testWidgets(
      'el detalle muestra el estado según sensores y no el del diagnóstico IA',
      (tester) async {
        // El diagnóstico IA «Buena» no entra en el modelo de sensores: aunque
        // llegara como health_status, no puede ser la etiqueta ni la cara.
        await _mount(tester, _fake(_data('Necesita agua', score: 65)));

        expect(find.text('Según sensores: Necesita agua'), findsOneWidget);
        expect(find.text('Buena'), findsNothing);
        expect(find.textContaining('Según sensores: Buena'), findsNothing);
        _expectCara(_bocaTriste);
        _expectRegar(tester, resaltado: true);

        await _finish(tester);
      },
    );

    testWidgets('un valor de diagnóstico (Buena) como estado de sensores es Sin datos', (
      tester,
    ) async {
      await _mount(
        tester,
        _fake(
          SensorDataModel.fromJson({
            'plant_id': 7,
            'plant_name': 'Echeveria',
            'health_status': 'Buena',
            'health_score': 90.0,
          }),
        ),
      );

      expect(find.text('Según sensores: sin lecturas'), findsOneWidget);
      expect(find.text('Según sensores: Buena'), findsNothing);

      await _finish(tester);
    });
  });
}
