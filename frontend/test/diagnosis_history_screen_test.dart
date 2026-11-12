// Solar-Grow - Pruebas de widget del historial de diagnósticos (sin HTTP real)
// Spec 002 · CA-9 (título y nombre), CA-10 a CA-15
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:solar_grow/models/diagnosis_model.dart';
import 'package:solar_grow/providers/diagnosis_provider.dart';
import 'package:solar_grow/screens/plant/diagnosis_history_screen.dart';

const emptyText = 'Esta planta aún no tiene diagnósticos.';
const errorText = 'No se pudieron cargar los diagnósticos.';
const noPhotoText = 'Sin foto';
const noDescriptionText = 'Sin descripción';

typedef DiagnosisLoader = Future<List<DiagnosisModel>> Function(int plantId);

/// DiagnosisProvider falso: no hace red; registra cada plantId pedido y
/// reproduce el contrato de D5 (vacía la lista y el error al empezar y al fallar).
class FakeDiagnosisProvider extends DiagnosisProvider {
  FakeDiagnosisProvider({required this.loader});

  DiagnosisLoader loader;
  final List<int> calls = [];

  List<DiagnosisModel> _diagnoses = [];
  bool _loading = false;
  String? _error;

  @override
  List<DiagnosisModel> get diagnoses => _diagnoses;

  @override
  bool get isLoading => _loading;

  @override
  String? get error => _error;

  /// Host falso: ninguna prueba hace una petición real de imagen
  @override
  String? imageUrlFor(DiagnosisModel d) =>
      d.imageUrl == null ? null : 'http://fake.test${d.imageUrl}';

  @override
  Future<bool> loadDiagnoses(int plantId) async {
    calls.add(plantId);
    _diagnoses = [];
    _error = null;
    _loading = true;
    notifyListeners();
    try {
      _diagnoses = await loader(plantId);
      _loading = false;
      notifyListeners();
      return true;
    } catch (_) {
      _diagnoses = [];
      _error = errorText;
      _loading = false;
      notifyListeners();
      return false;
    }
  }
}

/// Diagnóstico construido solo con fromJson (no depende del constructor)
DiagnosisModel diag(
  int id, {
  required String createdAt,
  String healthStatus = 'Buena',
  String? text = 'ESTADO GENERAL: Saludable\nRiega cada tres dias.',
  bool withImage = true,
}) {
  return DiagnosisModel.fromJson({
    'id': id,
    'plant_id': 7,
    'health_status': healthStatus,
    'diagnosis': text,
    'image_url': withImage ? '/static/diagnosticos/diag_7_$id.jpg' : null,
    'confidence': 87.5,
    'detected_issues': null,
    'suggested_actions': null,
    'created_at': createdAt,
  });
}

/// Fecha esperada en pantalla: mismo formato y hora local del dispositivo
String shown(DiagnosisModel d) =>
    DateFormat('dd/MM/yyyy HH:mm').format(d.createdAt.toLocal());

DiagnosisLoader always(List<DiagnosisModel> list) =>
    (_) async => list;

Widget buildScreen(FakeDiagnosisProvider provider) {
  return ChangeNotifierProvider<DiagnosisProvider>.value(
    value: provider,
    child: const MaterialApp(
      home: DiagnosisHistoryScreen(plantId: 7, plantName: 'Echeveria'),
    ),
  );
}

/// Monta la pantalla en una vista grande y deja pasar el primer frame, donde
/// se lanza la carga inicial (D8).
Future<void> pumpScreen(
  WidgetTester tester,
  FakeDiagnosisProvider provider, {
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(900, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(buildScreen(provider));
  await tester.pump();
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// En flutter_test toda petición de imagen termina en error, pero de forma
/// asíncrona real: se cede un poco de tiempo real y se repinta.
Future<void> letImagesFail(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

Finder networkImage(String url) => find.byWidgetPredicate(
  (w) => w is Image && w.image is NetworkImage && (w.image as NetworkImage).url == url,
);

Finder anyNetworkImage() =>
    find.byWidgetPredicate((w) => w is Image && w.image is NetworkImage);

void main() {
  final newest = diag(3, createdAt: '2026-11-11T17:30:00Z', healthStatus: 'Excelente');
  final middle = diag(2, createdAt: '2026-11-10T09:05:00Z', healthStatus: 'Critica');
  final oldest = diag(1, createdAt: '2026-11-08T22:45:00Z', healthStatus: 'Regular');
  // Del más reciente al más antiguo, como los entrega el provider
  List<DiagnosisModel> three() => [newest, middle, oldest];

  group('DiagnosisHistoryScreen', () {
    testWidgets('muestra el título Diagnósticos y el nombre de la planta', (
      tester,
    ) async {
      final provider = FakeDiagnosisProvider(loader: always(three()));
      await pumpScreen(tester, provider);

      expect(find.text('Diagnósticos'), findsOneWidget);
      expect(find.text('Echeveria'), findsWidgets);
    });

    testWidgets('pide los diagnósticos de la planta recibida, una sola vez', (
      tester,
    ) async {
      final provider = FakeDiagnosisProvider(loader: always(three()));
      await pumpScreen(tester, provider);

      expect(provider.calls, [7]);
    });

    testWidgets(
      'con diagnósticos muestra uno por elemento del más reciente al más antiguo con fecha y estado',
      (tester) async {
        final provider = FakeDiagnosisProvider(loader: always(three()));
        await pumpScreen(tester, provider);

        // Una fecha por diagnóstico, en hora local y formato dd/MM/yyyy HH:mm
        for (final d in three()) {
          expect(find.text(shown(d)), findsOneWidget);
        }

        // Orden vertical: el más reciente arriba
        final tops = three()
            .map((d) => tester.getTopLeft(find.text(shown(d))).dy)
            .toList();
        expect(tops[0], lessThan(tops[1]));
        expect(tops[1], lessThan(tops[2]));

        // Estado en español; «Crítica» con tilde y nunca «Critica»
        expect(find.text('Excelente'), findsOneWidget);
        expect(find.text('Crítica'), findsOneWidget);
        expect(find.text('Regular'), findsOneWidget);
        expect(find.text('Critica'), findsNothing);

        // Cada estado queda junto a la fecha de su propio diagnóstico
        double centerY(Finder f) => tester.getCenter(f).dy;
        final labels = ['Excelente', 'Crítica', 'Regular'];
        final dates = three().map(shown).toList();
        for (var i = 0; i < 3; i++) {
          final own = (centerY(find.text(labels[i])) - centerY(find.text(dates[i]))).abs();
          for (var j = 0; j < 3; j++) {
            if (j == i) continue;
            final foreign =
                (centerY(find.text(labels[i])) - centerY(find.text(dates[j]))).abs();
            expect(own, lessThan(foreign), reason: '${labels[i]} vs fecha $j');
          }
        }

        expect(find.text(emptyText), findsNothing);
        expect(find.text(errorText), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('cada miniatura usa la URL de su propio diagnóstico', (
      tester,
    ) async {
      final provider = FakeDiagnosisProvider(loader: always(three()));
      await pumpScreen(tester, provider);

      for (final d in three()) {
        expect(
          networkImage(provider.imageUrlFor(d)!),
          findsOneWidget,
          reason: 'miniatura del diagnóstico ${d.id}',
        );
      }
      expect(anyNetworkImage(), findsNWidgets(3));
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is NetworkImage &&
              (w.image as NetworkImage).url.contains('ultimo_diagnostico'),
        ),
        findsNothing,
      );
    });

    testWidgets('no muestra ningún porcentaje de confianza', (tester) async {
      // El JSON de prueba trae confidence: 87.5 y el modelo debe ignorarlo
      final provider = FakeDiagnosisProvider(loader: always(three()));
      await pumpScreen(tester, provider);

      expect(find.textContaining('%'), findsNothing);
      expect(find.textContaining('onfianza'), findsNothing);
      expect(find.textContaining('87'), findsNothing);
    });

    testWidgets(
      'al tocar un diagnóstico muestra su texto completo, fecha, estado y foto grande',
      (tester) async {
        final d = diag(
          9,
          createdAt: '2026-11-11T17:30:00Z',
          healthStatus: 'Mala',
          text: 'ESTADO GENERAL: Con manchas\nQuitar hojas secas y regar menos.',
        );
        final provider = FakeDiagnosisProvider(loader: always([d]));
        await pumpScreen(tester, provider);

        // Antes de tocar no hay hoja de detalle
        expect(find.text('Cerrar'), findsNothing);
        expect(anyNetworkImage(), findsOneWidget);

        await tester.tap(find.text(shown(d)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Cerrar'), findsOneWidget);
        // Texto completo, sin partirlo en secciones
        expect(
          find.text(
            'ESTADO GENERAL: Con manchas\nQuitar hojas secas y regar menos.',
          ),
          findsWidgets,
        );
        // Fecha y estado: en la tarjeta y en la hoja
        expect(find.textContaining(shown(d)), findsNWidgets(2));
        expect(find.textContaining('Mala'), findsNWidgets(2));
        // Foto grande: la misma URL, ahora dos veces (miniatura y detalle)
        expect(networkImage(provider.imageUrlFor(d)!), findsNWidgets(2));
        expect(find.text(noDescriptionText), findsNothing);

        // Cerrar vuelve al historial
        await tester.tap(find.text('Cerrar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Cerrar'), findsNothing);
        expect(find.text(shown(d)), findsOneWidget);
      },
    );

    testWidgets('un diagnóstico sin texto muestra Sin descripción', (
      tester,
    ) async {
      final sinTexto = diag(
        8,
        createdAt: '2026-11-11T17:30:00Z',
        text: null,
      );
      final vacio = diag(
        7,
        createdAt: '2026-11-10T09:05:00Z',
        text: '',
      );
      final provider = FakeDiagnosisProvider(loader: always([sinTexto, vacio]));
      await pumpScreen(tester, provider);

      // La lista no inventa descripciones
      expect(find.text(noDescriptionText), findsNothing);

      await tester.tap(find.text(shown(sinTexto)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Cerrar'), findsOneWidget);
      expect(find.text(noDescriptionText), findsOneWidget);

      await tester.tap(find.text('Cerrar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(noDescriptionText), findsNothing);

      // Texto vacío (cadena vacía) se trata igual que nulo
      await tester.tap(find.text(shown(vacio)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(noDescriptionText), findsOneWidget);
    });

    testWidgets(
      'un diagnóstico sin image_url muestra Sin foto y ninguna imagen',
      (tester) async {
        final d = diag(4, createdAt: '2026-11-11T17:30:00Z', withImage: false);
        final provider = FakeDiagnosisProvider(loader: always([d]));
        await pumpScreen(tester, provider);

        // En la lista
        expect(find.text(noPhotoText), findsOneWidget);
        expect(find.byType(Image), findsNothing);

        // En el detalle
        await tester.tap(find.text(shown(d)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Cerrar'), findsOneWidget);
        expect(find.text(noPhotoText), findsNWidgets(2));
        expect(find.byType(Image), findsNothing);
      },
    );

    testWidgets('si la imagen no carga muestra Sin foto', (tester) async {
      final d = diag(5, createdAt: '2026-11-11T17:30:00Z');
      final other = diag(6, createdAt: '2026-11-10T17:30:00Z', withImage: false);
      final provider = FakeDiagnosisProvider(loader: always([d, other]));
      await pumpScreen(tester, provider);

      // flutter_test responde con error a toda petición de imagen
      await letImagesFail(tester);

      // Una «Sin foto» por la imagen caída y otra por el diagnóstico sin foto
      expect(find.text(noPhotoText), findsNWidgets(2));

      // Y en el detalle de la que no cargó
      await tester.tap(find.text(shown(d)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await letImagesFail(tester);
      expect(find.text('Cerrar'), findsOneWidget);
      expect(find.text(noPhotoText), findsNWidgets(3));

      // Nunca la imagen de otro diagnóstico ni ultimo_diagnostico.jpg
      final urls = tester
          .widgetList<Image>(anyNetworkImage())
          .map((w) => (w.image as NetworkImage).url)
          .toSet();
      expect(urls, {provider.imageUrlFor(d)});
    });

    testWidgets('sin diagnósticos muestra el estado vacío y ninguna tarjeta', (
      tester,
    ) async {
      final provider = FakeDiagnosisProvider(loader: always([]));
      await pumpScreen(tester, provider);

      expect(find.text(emptyText), findsOneWidget);
      expect(find.text(errorText), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(Image), findsNothing);
      expect(find.text(noPhotoText), findsNothing);
      for (final label in ['Excelente', 'Buena', 'Regular', 'Mala', 'Crítica']) {
        expect(find.text(label), findsNothing);
      }
      // Sigue el título y el nombre de la planta
      expect(find.text('Diagnósticos'), findsOneWidget);
      expect(find.text('Echeveria'), findsWidgets);
    });

    testWidgets(
      'si el API falla muestra el error con Reintentar y ningún diagnóstico',
      (tester) async {
        final provider = FakeDiagnosisProvider(
          loader: (_) async => throw Exception('servidor caído'),
        );
        await pumpScreen(tester, provider);

        expect(find.text(errorText), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.text(emptyText), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byType(Image), findsNothing);
        for (final label in ['Excelente', 'Buena', 'Regular', 'Mala', 'Crítica']) {
          expect(find.text(label), findsNothing);
        }
      },
    );

    testWidgets(
      'Reintentar vuelve a pedir la misma planta y muestra la lista',
      (tester) async {
        final provider = FakeDiagnosisProvider(
          loader: (_) async => throw Exception('sin conexión'),
        );
        await pumpScreen(tester, provider);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(provider.calls, [7]);

        provider.loader = always(three());
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(provider.calls, [7, 7]);
        expect(find.text(errorText), findsNothing);
        expect(find.text('Reintentar'), findsNothing);
        for (final d in three()) {
          expect(find.text(shown(d)), findsOneWidget);
        }
      },
    );

    testWidgets('mientras carga muestra el indicador y ningún diagnóstico', (
      tester,
    ) async {
      var pending = Completer<List<DiagnosisModel>>();
      final provider = FakeDiagnosisProvider(loader: (_) => pending.future);

      await pumpScreen(tester, provider, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      for (final d in three()) {
        expect(find.text(shown(d)), findsNothing);
      }
      expect(find.byType(Image), findsNothing);
      expect(find.text(emptyText), findsNothing);
      expect(find.text(errorText), findsNothing);
      // El título y la planta ya se ven mientras carga
      expect(find.text('Diagnósticos'), findsOneWidget);

      pending.complete(three());
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(shown(newest)), findsOneWidget);

      // Un reintento tras un error vuelve a mostrar solo el indicador
      provider.loader = (_) async => throw Exception('500');
      provider.calls.clear();
      await provider.loadDiagnoses(7);
      await tester.pump();
      expect(find.text('Reintentar'), findsOneWidget);

      pending = Completer<List<DiagnosisModel>>();
      provider.loader = (_) => pending.future;
      await tester.tap(find.text('Reintentar'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(errorText), findsNothing);
      expect(find.text(shown(newest)), findsNothing);

      pending.complete([newest]);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(shown(newest)), findsOneWidget);
    });
  });
}
