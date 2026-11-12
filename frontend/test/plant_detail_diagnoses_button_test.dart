// Solar-Grow - Prueba del botón «Diagnósticos» en el detalle de la planta
// Spec 002 · CA-9 (acceso desde el detalle)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:solar_grow/models/plant_model.dart';
import 'package:solar_grow/providers/auth_provider.dart';
import 'package:solar_grow/providers/plant_provider.dart';
import 'package:solar_grow/screens/plant/plant_detail_screen.dart';

/// PlantProvider falso: planta seleccionada fija y sin red.
class FakePlantProvider extends PlantProvider {
  FakePlantProvider(this.fakeSelected);

  final PlantModel fakeSelected;
  final List<int> sensorLoads = [];

  @override
  PlantModel? get selectedPlant => fakeSelected;

  @override
  Future<void> loadSensorData(int plantId) async {
    sensorLoads.add(plantId);
  }
}

void main() {
  testWidgets(
    'el botón Diagnósticos del detalle abre /plant-diagnoses con la planta seleccionada',
    (tester) async {
      tester.view.physicalSize = const Size(900, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final plant = PlantModel(id: 7, commonName: 'Echeveria');
      final plantProvider = FakePlantProvider(plant);
      Object? receivedArguments;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            // Sin sesión: el detalle no arranca su temporizador de 3 s
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
            ChangeNotifierProvider<PlantProvider>.value(value: plantProvider),
          ],
          child: MaterialApp(
            home: const PlantDetailScreen(),
            routes: {
              '/plant-diagnoses': (context) {
                receivedArguments = ModalRoute.of(context)?.settings.arguments;
                return const Scaffold(body: Text('RUTA-DIAGNOSTICOS'));
              },
            },
          ),
        ),
      );
      await tester.pump();

      // Los tres botones circulares en la misma fila
      expect(find.text('Info'), findsOneWidget);
      expect(find.text('Regar'), findsOneWidget);
      expect(find.text('Diagnósticos'), findsOneWidget);
      final rowY = tester.getCenter(find.text('Info')).dy;
      expect(tester.getCenter(find.text('Regar')).dy, closeTo(rowY, 1));
      expect(tester.getCenter(find.text('Diagnósticos')).dy, closeTo(rowY, 1));
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(receivedArguments, isNull);

      await tester.tap(find.text('Diagnósticos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('RUTA-DIAGNOSTICOS'), findsOneWidget);
      expect(receivedArguments, isA<PlantModel>());
      expect(identical(receivedArguments, plant), isTrue);
      expect((receivedArguments as PlantModel).id, 7);

      // AnimatedPlantWidget deja un temporizador de parpadeo (2,5 a 5,5 s) que
      // solo termina cuando el widget ya no está montado: se desmonta y se deja
      // pasar el tiempo para que flutter_test no vea temporizadores pendientes.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 10));
    },
  );
}
