// Solar-Grow - Recomendaciones y Notificaciones: estados vacíos honestos
// Spec 005 · CA-17, CA-18 y CA-20 (decisión D12 del plan).
//
// Las dos pantallas no usan providers: se montan en un MaterialApp plano.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_grow/screens/notifications/notifications_screen.dart';
import 'package:solar_grow/screens/recommendations/recommendations_screen.dart';

const _recTitulo = 'Todavía no hay recomendaciones automáticas.';
const _recAyuda =
    'Para revisar una planta, usa el Diagnóstico IA del menú o el historial de Diagnósticos de la planta.';
const _notifTitulo = 'Todavía no hay notificaciones.';

Future<void> _mount(
  WidgetTester tester,
  Widget pantalla, {
  double width = 400,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: pantalla));
  await tester.pump();
}

/// Todo el texto visible de la pantalla, en minúsculas.
String _todoElTexto(WidgetTester tester) {
  final partes = <String>[];
  for (final t in tester.widgetList<Text>(find.byType(Text))) {
    partes.add(t.data ?? t.textSpan?.toPlainText() ?? '');
  }
  return partes.join('\n').toLowerCase();
}

void _expectSinInventos(WidgetTester tester) {
  final texto = _todoElTexto(tester);
  for (final prohibido in [
    '87%',
    'confianza',
    'estado general',
    'panel solar',
    'batería',
    'tracking',
    'raspberry',
    'hace 30 min',
    'hace 1 hora',
    'marcar todas',
    'riego necesario',
    'temperatura elevada',
    '27%',
    '32°c',
    'echeveria',
  ]) {
    expect(texto.contains(prohibido), isFalse, reason: 'aparece "$prohibido"');
  }
  expect(find.textContaining('Marcar todas'), findsNothing);
  expect(find.byType(TextButton), findsNothing);
  expect(find.byType(Card), findsNothing);
  expect(find.byType(ListTile), findsNothing);
}

/// El texto se ve entero: sin tope de líneas, sin ajuste desactivado, sin
/// recorte en el párrafo maquetado y dentro del ancho de la pantalla.
void _expectTextoEntero(WidgetTester tester, Finder texto, double ancho) {
  expect(texto, findsOneWidget);
  final t = tester.widget<Text>(texto);
  final etiqueta = t.data ?? '?';
  expect(t.maxLines, isNull, reason: 'maxLines de "$etiqueta"');
  expect(t.softWrap, isNot(false), reason: 'softWrap de "$etiqueta"');
  expect(
    t.overflow,
    isNot(anyOf(TextOverflow.ellipsis, TextOverflow.fade)),
    reason: 'overflow de "$etiqueta"',
  );
  final p = tester.renderObject<RenderParagraph>(texto);
  expect(p.didExceedMaxLines, isFalse, reason: '"$etiqueta" se recorta');
  expect(
    p.getMinIntrinsicWidth(double.infinity),
    lessThanOrEqualTo(p.size.width + 0.5),
    reason: 'la palabra más ancha de "$etiqueta" no cabe',
  );
  final r = tester.getRect(texto);
  expect(r.left, greaterThanOrEqualTo(-0.01), reason: etiqueta);
  expect(r.right, lessThanOrEqualTo(ancho + 0.01), reason: etiqueta);
}

void main() {
  group('CA-17 · Recomendaciones', () {
    testWidgets('Recomendaciones muestra el estado vacío y nada inventado', (
      tester,
    ) async {
      await _mount(tester, const RecommendationsScreen());

      expect(find.text(_recTitulo), findsOneWidget);
      expect(find.text(_recAyuda), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_outlined), findsWidgets);
      _expectSinInventos(tester);
      // Ninguna de las seis tarjetas fijas
      expect(find.textContaining('Aumentar frecuencia'), findsNothing);
      expect(find.textContaining('Exposición solar'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('CA-18 · Notificaciones', () {
    testWidgets('Notificaciones muestra el estado vacío sin Marcar todas', (
      tester,
    ) async {
      await _mount(tester, const NotificationsScreen());

      expect(find.text(_notifTitulo), findsOneWidget);
      expect(find.byIcon(Icons.notifications_none), findsWidgets);
      _expectSinInventos(tester);
      expect(find.textContaining('Hace '), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('CA-20 · nada se desborda ni se corta', () {
    for (final ancho in [320.0, 360.0]) {
      testWidgets('los estados vacíos se ven enteros a ${ancho.toInt()} px', (
        tester,
      ) async {
        await _mount(tester, const RecommendationsScreen(), width: ancho);
        expect(tester.takeException(), isNull);
        _expectTextoEntero(tester, find.text(_recTitulo), ancho);
        _expectTextoEntero(tester, find.text(_recAyuda), ancho);

        await _mount(tester, const NotificationsScreen(), width: ancho);
        expect(tester.takeException(), isNull);
        _expectTextoEntero(tester, find.text(_notifTitulo), ancho);
      });
    }
  });
}
