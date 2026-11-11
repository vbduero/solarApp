// Solar-Grow - Pruebas de widget de la pantalla de Estadísticas (sin HTTP real)
// Spec 001 · CA-1 a CA-7 y CA-9
import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/models/sensor_reading_model.dart';
import 'package:solar_grow/providers/plant_provider.dart';
import 'package:solar_grow/screens/stats/stats_screen.dart';

const emptyText = 'Esta planta no tiene lecturas en este periodo.';
const errorText = 'No se pudieron cargar las estadísticas.';
const noPlantsText = 'Aún no tienes plantas registradas.';

typedef HistoryLoader =
    Future<List<SensorReadingModel>> Function(int plantId, int hours);

/// PlantProvider falso: no hace red; registra cada llamada a loadSensorHistory
/// y reproduce el contrato de D2/D4 (vacía la lista al empezar y al fallar).
class FakePlantProvider extends PlantProvider {
  FakePlantProvider({
    this.fakePlants = const [],
    this.fakeSelected,
    required this.loader,
  });

  List<PlantModel> fakePlants;
  PlantModel? fakeSelected;
  HistoryLoader loader;

  final List<({int plantId, int hours})> calls = [];
  int selectPlantCalls = 0;

  List<SensorReadingModel> _history = [];
  bool _loadingHistory = false;
  String? _historyError;

  bool fakeLoading = false;

  @override
  bool get isLoading => fakeLoading;

  /// Simula que el provider notifica una lista nueva (y/o fin de la carga)
  void update({List<PlantModel>? plants, bool? loading}) {
    if (plants != null) fakePlants = plants;
    if (loading != null) fakeLoading = loading;
    notifyListeners();
  }

  @override
  List<PlantModel> get plants => fakePlants;

  @override
  PlantModel? get selectedPlant => fakeSelected;

  @override
  List<SensorReadingModel> get sensorHistory => _history;

  @override
  bool get isHistoryLoading => _loadingHistory;

  @override
  String? get historyError => _historyError;

  @override
  Future<void> selectPlant(PlantModel plant) async {
    selectPlantCalls++;
  }

  @override
  Future<bool> loadSensorHistory(int plantId, {required int hours}) async {
    calls.add((plantId: plantId, hours: hours));
    _history = [];
    _historyError = null;
    _loadingHistory = true;
    notifyListeners();
    try {
      _history = await loader(plantId, hours);
      _loadingHistory = false;
      notifyListeners();
      return true;
    } catch (_) {
      _history = [];
      _historyError = errorText;
      _loadingHistory = false;
      notifyListeners();
      return false;
    }
  }
}

final base = DateTime.utc(2026, 11, 11, 12);

/// Lectura ascendente: [minutes] minutos antes de [base]
SensorReadingModel reading(
  int id,
  int minutesBefore, {
  double? temperature,
  double? airHumidity,
  double? soilHumidity,
}) {
  return SensorReadingModel(
    id: id,
    plantId: 7,
    temperature: temperature,
    airHumidity: airHumidity,
    soilHumidity: soilHumidity,
    recordedAt: base.subtract(Duration(minutes: minutesBefore)),
  );
}

/// Tres lecturas completas, de la más antigua a la más reciente
List<SensorReadingModel> fullReadings() => [
  reading(1, 120, temperature: 20, soilHumidity: 40, airHumidity: 60),
  reading(2, 60, temperature: 22, soilHumidity: 45, airHumidity: 65),
  reading(3, 0, temperature: 24, soilHumidity: 50, airHumidity: 70),
];

Future<List<SensorReadingModel>> Function(int, int) always(
  List<SensorReadingModel> readings,
) =>
    (_, _) async => readings;

final echeveria = PlantModel(id: 7, commonName: 'Echeveria');
final nenufares = PlantModel(id: 3, commonName: 'Nenúfares');

Widget buildScreen(FakePlantProvider provider) {
  return ChangeNotifierProvider<PlantProvider>.value(
    value: provider,
    child: const MaterialApp(home: StatsScreen()),
  );
}

/// Monta la pantalla en una vista grande (las tres tarjetas caben sin scroll)
/// y deja pasar el primer frame, donde se lanza la carga inicial (D12).
Future<void> pumpScreen(
  WidgetTester tester,
  FakePlantProvider provider, {
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

List<FlSpot> spotsOf(WidgetTester tester, int chartIndex) {
  final chart = tester.widget<LineChart>(find.byType(LineChart).at(chartIndex));
  return chart.data.lineBarsData.first.spots;
}

void expectNoFillerValues() {
  expect(find.text('Luz Solar'), findsNothing);
  expect(find.text('Sistema Solar'), findsNothing);
  expect(find.text('Panel Solar'), findsNothing);
  expect(find.text('Batería'), findsNothing);
  expect(find.text('Potencia'), findsNothing);
  expect(find.text('Tracker'), findsNothing);
}

void main() {
  group('StatsScreen', () {
    testWidgets(
      'con lecturas muestra las tres gráficas en orden cronológico y el último valor',
      (tester) async {
        final provider = FakePlantProvider(
          fakePlants: [echeveria],
          loader: always(fullReadings()),
        );
        await pumpScreen(tester, provider);

        expect(find.text('Temperatura'), findsOneWidget);
        expect(find.text('Humedad del Suelo'), findsOneWidget);
        expect(find.text('Humedad del Aire'), findsOneWidget);
        expect(find.byType(LineChart), findsNWidgets(3));

        // Orden de las tarjetas: Temperatura, Suelo, Aire
        final expectedY = [
          [20.0, 22.0, 24.0],
          [40.0, 45.0, 50.0],
          [60.0, 65.0, 70.0],
        ];
        for (var i = 0; i < 3; i++) {
          final spots = spotsOf(tester, i);
          expect(spots.map((s) => s.y), expectedY[i]);
          // La lectura más antigua queda a la izquierda
          for (var j = 1; j < spots.length; j++) {
            expect(spots[j].x, greaterThan(spots[j - 1].x));
          }
        }

        // Valor destacado = lectura más reciente (entero + unidad, sin espacio)
        expect(find.text('24°C'), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);
        expect(find.text('70%'), findsOneWidget);
      },
    );

    testWidgets('no muestra Luz Solar ni Sistema Solar en ningún estado', (
      tester,
    ) async {
      final states = <String, HistoryLoader>{
        'con datos': always(fullReadings()),
        'vacía': always([]),
        'con error': (_, _) async => throw Exception('servidor caído'),
        'cargando': (_, _) => Completer<List<SensorReadingModel>>().future,
      };

      for (final entry in states.entries) {
        final provider = FakePlantProvider(
          fakePlants: [echeveria],
          loader: entry.value,
        );
        await pumpScreen(tester, provider, settle: entry.key != 'cargando');
        expect(
          find.byType(Scaffold),
          findsWidgets,
          reason: 'la pantalla se montó (${entry.key})',
        );
        expectNoFillerValues();
        // Se desmonta para que el siguiente estado empiece desde cero
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('abre en 24h y cada periodo pide 6, 24, 168 o 720 horas', (
      tester,
    ) async {
      final provider = FakePlantProvider(
        fakePlants: [echeveria],
        loader: always(fullReadings()),
      );
      await pumpScreen(tester, provider);

      // Abre en 24h con la planta de la lista
      expect(provider.calls, hasLength(1));
      expect(provider.calls.single.plantId, 7);
      expect(provider.calls.single.hours, 24);

      for (final period in ['6h', '7d', '30d', '24h']) {
        await tester.tap(find.text(period));
        await tester.pumpAndSettle();
      }

      expect(provider.calls.map((c) => c.hours), [24, 6, 168, 720, 24]);
      expect(provider.calls.map((c) => c.plantId).toSet(), {7});
      // Tras cargar, las gráficas muestran las lecturas del periodo
      expect(find.byType(LineChart), findsNWidgets(3));
    });

    testWidgets('mientras carga muestra el indicador de progreso', (
      tester,
    ) async {
      var pending = Completer<List<SensorReadingModel>>();
      final provider = FakePlantProvider(
        fakePlants: [echeveria],
        loader: (_, _) => pending.future,
      );

      // Carga inicial pendiente
      await pumpScreen(tester, provider, settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);

      pending.complete(fullReadings());
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LineChart), findsNWidgets(3));

      // Cambio de periodo: vuelve el indicador y no quedan las gráficas viejas
      pending = Completer<List<SensorReadingModel>>();
      await tester.tap(find.text('6h'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);

      pending.complete([
        reading(9, 0, temperature: 30, soilHumidity: 31, airHumidity: 32),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LineChart), findsNWidgets(3));
      expect(find.text('30°C'), findsOneWidget);
    });

    testWidgets('sin lecturas muestra el estado vacío y ninguna gráfica', (
      tester,
    ) async {
      final provider = FakePlantProvider(
        fakePlants: [echeveria],
        loader: always([]),
      );
      await pumpScreen(tester, provider);

      expect(find.text(emptyText), findsOneWidget);
      expect(find.byType(LineChart), findsNothing);
      expect(find.text(errorText), findsNothing);

      // El selector de periodo sigue disponible
      for (final period in ['6h', '24h', '7d', '30d']) {
        expect(find.text(period), findsOneWidget);
      }
      await tester.tap(find.text('7d'));
      await tester.pumpAndSettle();
      expect(provider.calls.last.hours, 168);
    });

    testWidgets(
      'si el API falla muestra el error con Reintentar y ninguna gráfica',
      (tester) async {
        final provider = FakePlantProvider(
          fakePlants: [echeveria],
          loader: always(fullReadings()),
        );
        await pumpScreen(tester, provider);
        expect(find.byType(LineChart), findsNWidgets(3));

        // El periodo siguiente falla: no deben quedar a la vista las lecturas previas
        provider.loader = (_, _) async => throw Exception('500');
        await tester.tap(find.text('6h'));
        await tester.pumpAndSettle();

        expect(find.text(errorText), findsOneWidget);
        expect(find.text('Reintentar'), findsOneWidget);
        expect(find.byType(LineChart), findsNothing);
        expect(find.text(emptyText), findsNothing);
        expect(find.text('24°C'), findsNothing);
      },
    );

    testWidgets(
      'Reintentar vuelve a pedir la misma planta y periodo y muestra las gráficas',
      (tester) async {
        final provider = FakePlantProvider(
          fakePlants: [echeveria],
          loader: always(fullReadings()),
        );
        await pumpScreen(tester, provider);

        provider.loader = (_, _) async => throw Exception('sin conexión');
        await tester.tap(find.text('7d'));
        await tester.pumpAndSettle();
        expect(find.text('Reintentar'), findsOneWidget);
        final callsBefore = provider.calls.length;

        provider.loader = always(fullReadings());
        await tester.tap(find.text('Reintentar'));
        await tester.pumpAndSettle();

        expect(provider.calls, hasLength(callsBefore + 1));
        expect(provider.calls.last.plantId, 7);
        expect(provider.calls.last.hours, 168);
        expect(find.text(errorText), findsNothing);
        expect(find.text('Reintentar'), findsNothing);
        expect(find.byType(LineChart), findsNWidgets(3));
      },
    );

    testWidgets(
      'usa la planta seleccionada y, si no hay, la primera de la lista',
      (tester) async {
        // Sin planta seleccionada: la primera de la lista (id 3)
        final withoutSelection = FakePlantProvider(
          fakePlants: [nenufares, echeveria],
          loader: always(fullReadings()),
        );
        await pumpScreen(tester, withoutSelection);
        expect(withoutSelection.calls.single.plantId, 3);
        expect(find.text('Nenúfares'), findsWidgets);
        await tester.pumpWidget(const SizedBox());

        // Con planta seleccionada (id 7), aunque no sea la primera
        final withSelection = FakePlantProvider(
          fakePlants: [nenufares, echeveria],
          fakeSelected: echeveria,
          loader: always(fullReadings()),
        );
        await pumpScreen(tester, withSelection);
        expect(withSelection.calls.single.plantId, 7);
        expect(find.text('Echeveria'), findsWidgets);
      },
    );

    testWidgets(
      'CA-6 con selectedPlant que no está en la lista (2 plantas) usa la primera sin lanzar excepción',
      (tester) async {
        final foreign = PlantModel(id: 99, commonName: 'DeOtroUsuario');
        final provider = FakePlantProvider(
          fakePlants: [nenufares, echeveria],
          fakeSelected: foreign,
          loader: always(fullReadings()),
        );
        await pumpScreen(tester, provider);

        expect(tester.takeException(), isNull);
        expect(provider.calls, hasLength(1));
        expect(provider.calls.single.plantId, 3);
        expect(provider.calls.single.hours, 24);
        expect(find.text('Nenúfares'), findsWidgets);
        expect(find.text('DeOtroUsuario'), findsNothing);
        expect(find.byType(LineChart), findsNWidgets(3));
      },
    );

    testWidgets(
      'CA-6 con selectedPlant que no está en la lista (1 planta) usa la primera y no muestra la ajena',
      (tester) async {
        final foreign = PlantModel(id: 99, commonName: 'DeOtroUsuario');
        final provider = FakePlantProvider(
          fakePlants: [echeveria],
          fakeSelected: foreign,
          loader: always(fullReadings()),
        );
        await pumpScreen(tester, provider);

        expect(tester.takeException(), isNull);
        expect(provider.calls, hasLength(1));
        expect(provider.calls.single.plantId, 7);
        expect(find.text('Echeveria'), findsWidgets);
        expect(find.text('DeOtroUsuario'), findsNothing);
      },
    );

    testWidgets(
      'si la planta mostrada desaparece de la lista pasa a la primera y recarga con el periodo actual',
      (tester) async {
        final otra = PlantModel(id: 11, commonName: 'Helecho');
        final provider = FakePlantProvider(
          fakePlants: [nenufares, echeveria, otra],
          loader: always(fullReadings()),
        );
        await pumpScreen(tester, provider);

        await tester.tap(find.text('7d'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Echeveria').last);
        await tester.pumpAndSettle();
        expect(provider.calls.last.plantId, 7);
        expect(provider.calls.last.hours, 168);
        final callsBefore = provider.calls.length;

        // El provider notifica una lista sin la planta 7
        provider.update(plants: [nenufares, otra]);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(provider.calls.length, greaterThan(callsBefore));
        expect(provider.calls.last.plantId, 3);
        expect(provider.calls.last.hours, 168);
        expect(find.text('Nenúfares'), findsWidgets);
        expect(find.text('Echeveria'), findsNothing);
      },
    );

    testWidgets(
      'D12 con plantas vacías e isLoading muestra la carga, no pide historial y al llegar la lista lo pide con 24h',
      (tester) async {
        final provider = FakePlantProvider(
          fakePlants: [],
          loader: always(fullReadings()),
        )..fakeLoading = true;
        await pumpScreen(tester, provider, settle: false);

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(noPlantsText), findsNothing);
        expect(provider.calls, isEmpty);

        provider.update(plants: [nenufares, echeveria], loading: false);
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text(noPlantsText), findsNothing);
        expect(provider.calls, hasLength(1));
        expect(provider.calls.single.plantId, 3);
        expect(provider.calls.single.hours, 24);
        expect(find.byType(LineChart), findsNWidgets(3));
      },
    );

    testWidgets('al elegir otra planta recarga con el periodo actual', (
      tester,
    ) async {
      final provider = FakePlantProvider(
        fakePlants: [nenufares, echeveria],
        loader: always(fullReadings()),
      );
      await pumpScreen(tester, provider);
      expect(provider.calls.single.plantId, 3);

      await tester.tap(find.text('30d'));
      await tester.pumpAndSettle();
      expect(provider.calls.last.plantId, 3);
      expect(provider.calls.last.hours, 720);

      // Selector desplegable de planta: DropdownButton<int> (valor = id)
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Echeveria').last);
      await tester.pumpAndSettle();

      expect(provider.calls.last.plantId, 7);
      expect(provider.calls.last.hours, 720);
      expect(find.text('Echeveria'), findsWidgets);
      expect(find.byType(LineChart), findsNWidgets(3));
      // La elección es local a la pantalla: no cambia la planta del detalle (D1)
      expect(provider.selectPlantCalls, 0);
    });

    testWidgets('sin plantas muestra el aviso y no pide historial', (
      tester,
    ) async {
      final provider = FakePlantProvider(
        fakePlants: [],
        loader: always(fullReadings()),
      );
      await pumpScreen(tester, provider);

      expect(find.text(noPlantsText), findsOneWidget);
      expect(provider.calls, isEmpty);
      expect(find.byType(LineChart), findsNothing);
      expectNoFillerValues();
    });

    testWidgets(
      'una lectura sin valor no se dibuja como cero y una variable sin valores muestra Sin datos',
      (tester) async {
        // Humedad del suelo nunca viene; temperatura y aire tienen huecos
        final provider = FakePlantProvider(
          fakePlants: [echeveria],
          loader: always([
            reading(1, 120, temperature: 20, airHumidity: 60),
            reading(2, 60, airHumidity: 62),
            reading(3, 0, temperature: 24),
          ]),
        );
        await pumpScreen(tester, provider);

        // Solo dos tarjetas dibujan línea: Temperatura y Humedad del Aire
        expect(find.byType(LineChart), findsNWidgets(2));
        expect(find.text('Sin datos'), findsOneWidget);
        expect(find.text('Humedad del Suelo'), findsOneWidget);

        final temperature = spotsOf(tester, 0);
        expect(temperature.map((s) => s.y), [20.0, 24.0]);
        final air = spotsOf(tester, 1);
        expect(air.map((s) => s.y), [60.0, 62.0]);
        expect(
          [...temperature, ...air].where((s) => s.y == 0),
          isEmpty,
          reason: 'ninguna lectura ausente se dibuja como 0',
        );

        // El valor destacado es el último punto de cada variable
        expect(find.text('24°C'), findsOneWidget);
        expect(find.text('62%'), findsOneWidget);
      },
    );
  });
}
