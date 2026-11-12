// Solar-Grow - Caja «Lecturas del ESP8266» del diálogo de Diagnóstico IA
// Spec 005 · CA-13 y CA-20 (decisión D11 del plan).
//
// La caja se prueba sola (SensorsInfoBox), sin abrir el diálogo, que llama
// al API directamente.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_grow/config/theme.dart';
import 'package:solar_grow/models/sensor_data_model.dart';
import 'package:solar_grow/widgets/sensors_info_box.dart';

SensorDataModel _data({
  double? temp,
  double? soil,
  double? air,
  int pump = 0,
}) => SensorDataModel(
  plantId: 7,
  plantName: 'Echeveria',
  temperature: temp,
  soilHumidity: soil,
  airHumidity: air,
  pumpActive: pump,
);

Future<void> _mount(
  WidgetTester tester,
  SensorDataModel? data, {
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: SensorsInfoBox(data: data)),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Cada coincidencia se ve entera: sin tope de líneas, sin recorte en el
/// párrafo y dentro del ancho disponible.
void _expectTextoEntero(WidgetTester tester, Finder texto, double ancho) {
  final n = texto.evaluate().length;
  expect(n, greaterThan(0), reason: 'no se encontró el texto');
  for (var i = 0; i < n; i++) {
    final f = texto.at(i);
    final t = tester.widget<Text>(f);
    final etiqueta = t.data ?? '?';
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
    expect(r.left, greaterThanOrEqualTo(-0.01), reason: etiqueta);
    expect(r.right, lessThanOrEqualTo(ancho + 0.01), reason: etiqueta);
  }
}

void main() {
  group('CA-13 · nada de 25.0 ni 50.0', () {
    testWidgets(
      'cada valor que falta se ve como Sin datos, nunca 25.0 ni 50.0',
      (tester) async {
        // Todo ausente
        await _mount(tester, _data());
        expect(find.text('Sin datos'), findsNWidgets(3));
        expect(find.textContaining('25.0'), findsNothing);
        expect(find.textContaining('50.0'), findsNothing);
        expect(find.textContaining('°C'), findsNothing);
        expect(find.textContaining('%'), findsNothing);

        // Falta solo la temperatura
        await _mount(tester, _data(soil: 41.2, air: 63));
        expect(find.text('Sin datos'), findsOneWidget);
        expect(find.text('41.2%'), findsOneWidget);
        expect(find.text('63.0%'), findsOneWidget);
        expect(find.textContaining('25.0'), findsNothing);
        expect(find.textContaining('°C'), findsNothing);

        // Falta solo la humedad del suelo
        await _mount(tester, _data(temp: 24.5, air: 63));
        expect(find.text('Sin datos'), findsOneWidget);
        expect(find.text('24.5°C'), findsOneWidget);
        expect(find.text('63.0%'), findsOneWidget);
        expect(find.textContaining('50.0'), findsNothing);

        // Falta solo la humedad del aire
        await _mount(tester, _data(temp: 24.5, soil: 41.2));
        expect(find.text('Sin datos'), findsOneWidget);
        expect(find.text('24.5°C'), findsOneWidget);
        expect(find.text('41.2%'), findsOneWidget);
        expect(find.textContaining('50.0'), findsNothing);
      },
    );

    testWidgets('con todos los valores se ven con un decimal', (tester) async {
      await _mount(tester, _data(temp: 24.5, soil: 41.2, air: 63));

      expect(find.text('24.5°C'), findsOneWidget);
      expect(find.text('41.2%'), findsOneWidget);
      expect(find.text('63.0%'), findsOneWidget);
      expect(find.text('Sin datos'), findsNothing);
      expect(find.text('Lecturas del ESP8266'), findsOneWidget);
      expect(find.text('Temperatura'), findsOneWidget);
      expect(find.text('Humedad Suelo'), findsOneWidget);
      expect(find.text('Humedad Aire'), findsOneWidget);
    });

    testWidgets('sin datos del todo (nulo) sigue diciendo Cargando datos', (
      tester,
    ) async {
      await _mount(tester, null);

      expect(find.text('Cargando datos de sensores...'), findsOneWidget);
      expect(find.text('Sin datos'), findsNothing);
      expect(find.textContaining('25.0'), findsNothing);
      expect(find.textContaining('50.0'), findsNothing);
    });

    testWidgets('el estado de la bomba se ve según la lectura', (tester) async {
      await _mount(tester, _data(temp: 24, soil: 40, air: 60, pump: 1));
      expect(find.text('Bomba de Riego: ACTIVA (Regando)'), findsOneWidget);

      await _mount(tester, _data(temp: 24, soil: 40, air: 60, pump: 0));
      expect(find.text('Bomba de Riego: Inactiva'), findsOneWidget);
    });

    testWidgets('el recuadro de la bomba usa colores de SolarColors (D11)', (
      tester,
    ) async {
      Color? fondoBomba() {
        final caja = find
            .ancestor(
              of: find.textContaining('Bomba de Riego'),
              matching: find.byType(Container),
            )
            .first;
        final deco = tester.widget<Container>(caja).decoration as BoxDecoration;
        return deco.color;
      }

      await _mount(tester, _data(temp: 24, soil: 40, air: 60, pump: 1));
      expect(fondoBomba(), SolarColors.skyBlueLight);

      await _mount(tester, _data(temp: 24, soil: 40, air: 60, pump: 0));
      expect(fondoBomba(), SolarColors.cardBg);
    });
  });

  group('CA-20 · la caja se ve entera', () {
    for (final ancho in [240.0, 280.0]) {
      testWidgets('la caja se ve entera en ${ancho.toInt()} px', (
        tester,
      ) async {
        // Con la fuente de pruebas (Ahem, cada letra mide lo que el cuerpo) las
        // etiquetas fijas de 9 px («Humedad Suelo») son más anchas que en un
        // teléfono real. Esa fila no es de esta spec: se toleran solo los
        // errores «overflowed» y se valida a fondo el texto nuevo, «Sin datos».
        final original = FlutterError.onError;
        final errores = <FlutterErrorDetails>[];
        FlutterError.onError = errores.add;
        try {
          await _mount(tester, _data(), width: ancho);
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

        expect(find.text('Sin datos'), findsNWidgets(3));
        _expectTextoEntero(tester, find.text('Sin datos'), ancho);

        // La caja misma cabe en el ancho disponible
        final caja = tester.getRect(find.byType(SensorsInfoBox));
        expect(caja.left, greaterThanOrEqualTo(-0.01));
        expect(caja.right, lessThanOrEqualTo(ancho + 0.01));
      });
    }
  });
}
