// Solar-Grow - Pruebas del estado «según sensores» en SensorDataModel
// Spec 004 · CA-3, CA-4, CA-9 y CA-11 (decisión D5 del plan).
//
// Sin red: solo el modelo.
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_grow/models/sensor_data_model.dart';

const _cinco = [
  'Sana',
  'Necesita agua',
  'Exceso de calor',
  'Critica',
  'Sin datos',
];

Map<String, dynamic> _json({Object? status, Object? score}) {
  return {
    'plant_id': 7,
    'plant_name': 'Echeveria',
    'temperature': 28.0,
    'air_humidity': 50.0,
    'soil_humidity': 20.0,
    'light_level': 85.0,
    'solar_voltage': 12.4,
    'battery_level': 98.0,
    'pump_active': 0,
    'health_status': ?status,
    'health_score': ?score,
  };
}

SensorDataModel _con(String estado) => SensorDataModel(
  plantId: 7,
  plantName: 'Echeveria',
  healthStatus: estado,
);

void main() {
  group('fromJson', () {
    test('fromJson conserva los cinco estados en español', () {
      for (final estado in _cinco) {
        final model = SensorDataModel.fromJson(_json(status: estado, score: 77));
        expect(model.healthStatus, estado, reason: 'estado $estado');
        expect(model.healthScore, 77.0);
      }
    });

    test(
      'fromJson convierte estados en inglés o desconocidos en Sin datos',
      () {
        for (final raro in [
          'healthy',
          'needs_water',
          'needs_light',
          'stressed',
          'critical',
          'unknown',
          'sana', // otra capitalización no es uno de los cinco
          'Buena', // estado del diagnóstico IA: no es de sensores
          '',
        ]) {
          final model = SensorDataModel.fromJson(
            _json(status: raro, score: 90),
          );
          expect(model.healthStatus, 'Sin datos', reason: 'valor "$raro"');
          // Un estado en inglés no puede dejar «Regar» resaltado
          expect(model.needsWater, isFalse, reason: 'valor "$raro"');
        }
      },
    );

    test(
      'fromJson sin health_status ni health_score da Sin datos y puntaje null',
      () {
        final model = SensorDataModel.fromJson(_json());
        expect(model.healthStatus, 'Sin datos');
        expect(model.healthScore, isNull);
        expect(model.needsWater, isFalse);
      },
    );

    test('fromJson con health_status y health_score nulos explícitos', () {
      final json = _json()
        ..['health_status'] = null
        ..['health_score'] = null;
      final model = SensorDataModel.fromJson(json);
      expect(model.healthStatus, 'Sin datos');
      expect(model.healthScore, isNull);
    });

    test('fromJson acepta health_score entero y lo guarda como double', () {
      final model = SensorDataModel.fromJson(_json(status: 'Sana', score: 100));
      expect(model.healthScore, 100.0);
      expect(model.healthScore, isA<double>());
    });
  });

  group('parseHealthStatus', () {
    test('devuelve los cinco estados y Sin datos para todo lo demás', () {
      for (final estado in _cinco) {
        expect(SensorDataModel.parseHealthStatus(estado), estado);
      }
      expect(SensorDataModel.parseHealthStatus(null), 'Sin datos');
      expect(SensorDataModel.parseHealthStatus('healthy'), 'Sin datos');
      expect(SensorDataModel.parseHealthStatus('unknown'), 'Sin datos');
      expect(SensorDataModel.parseHealthStatus('needs_water'), 'Sin datos');
      expect(SensorDataModel.parseHealthStatus(42), 'Sin datos');
    });
  });

  group('constructor', () {
    test('sin estado explícito el modelo es Sin datos y sin puntaje', () {
      final model = SensorDataModel(plantId: 7, plantName: 'Echeveria');
      expect(model.healthStatus, 'Sin datos');
      expect(model.healthScore, isNull);
      expect(model.needsWater, isFalse);
    });
  });

  group('needsWater y healthLabel', () {
    test('needsWater solo es verdadero con Necesita agua y Critica', () {
      final esperado = {
        'Sana': false,
        'Necesita agua': true,
        'Exceso de calor': false,
        'Critica': true,
        'Sin datos': false,
      };
      esperado.forEach((estado, resaltado) {
        expect(_con(estado).needsWater, resaltado, reason: estado);
      });
    });

    test('needsWater no depende del puntaje', () {
      final sana = SensorDataModel(
        plantId: 7,
        plantName: 'Echeveria',
        healthStatus: 'Sana',
        healthScore: 10,
      );
      final seca = SensorDataModel(
        plantId: 7,
        plantName: 'Echeveria',
        healthStatus: 'Necesita agua',
        healthScore: 95,
      );
      expect(sana.needsWater, isFalse);
      expect(seca.needsWater, isTrue);
    });

    test(
      'healthLabel muestra Crítica con tilde y sin lecturas para Sin datos',
      () {
        expect(_con('Sana').healthLabel, 'Sana');
        expect(_con('Necesita agua').healthLabel, 'Necesita agua');
        expect(_con('Exceso de calor').healthLabel, 'Exceso de calor');
        expect(_con('Critica').healthLabel, 'Crítica');
        expect(_con('Sin datos').healthLabel, 'sin lecturas');
      },
    );
  });

  group('empty', () {
    test('empty trae Sin datos y puntaje null', () {
      final demo = SensorDataModel.empty(7, 'Echeveria');
      expect(demo.healthStatus, 'Sin datos');
      expect(demo.healthScore, isNull);
      expect(demo.needsWater, isFalse);
      expect(demo.healthLabel, 'sin lecturas');
    });
  });
}
