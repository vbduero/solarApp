// ============================================================
// Solar-Grow - Provider de Plantas
// ============================================================
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../models/sensor_data_model.dart';
import '../models/sensor_reading_model.dart';
import '../services/api_service.dart';
import '../config/api_constants.dart';

/// Provider que gestiona las plantas y datos de sensores
class PlantProvider extends ChangeNotifier {
  List<PlantModel> _plants = [];
  PlantModel? _selectedPlant;
  SensorDataModel? _currentSensorData;
  bool _isLoading = false;
  String? _error;
  bool _isDemoMode = false;

  List<SensorReadingModel> _sensorHistory = [];
  bool _isHistoryLoading = false;
  String? _historyError;
  int _historyRequestId = 0;

  // Estado en vivo de la bomba (solo cuando el ESP8266 está en línea en esa planta)
  int? _livePumpPlantId;
  bool? _livePumpOn;
  int _sensorRequestId = 0;

  /// Historial en orden cronológico ascendente
  List<SensorReadingModel> get sensorHistory => _sensorHistory;
  bool get isHistoryLoading => _isHistoryLoading;
  String? get historyError => _historyError;

  List<PlantModel> get plants => _plants;
  PlantModel? get selectedPlant => _selectedPlant;
  SensorDataModel? get currentSensorData => _currentSensorData;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Estado de la bomba según el ESP8266 en línea para esa planta.
  /// `null` significa que no hay dato en vivo (desconectado, otra planta, BDD o demo).
  bool? livePumpOn(int plantId) =>
      _livePumpPlantId == plantId ? _livePumpOn : null;

  /// Obtener todas las plantas del usuario
  Future<void> loadPlants() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.get(ApiConstants.plants);
      _plants = (data as List).map((p) => PlantModel.fromJson(p)).toList();
      _isDemoMode = false;
    } catch (e) {
      // Si falla la API, cargar datos de demo
      _loadDemoPlants();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Agregar una planta
  Future<bool> createPlant(Map<String, dynamic> plantData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.post(ApiConstants.plants, body: plantData);
      _plants.insert(0, PlantModel.fromJson(data));
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al agregar la planta';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Eliminar una planta
  Future<bool> deletePlant(int plantId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await ApiService.delete('${ApiConstants.plants}$plantId');
      _plants.removeWhere((p) => p.id == plantId);
      if (_selectedPlant?.id == plantId) _selectedPlant = null;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al eliminar la planta';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Subir imagen de la planta
  Future<String?> uploadImage(Uint8List imageBytes, String filename) async {
    try {
      final data = await ApiService.uploadImage(
        '/api/plants/upload-image',
        imageBytes,
        filename,
      );
      if (data != null && data['image_url'] != null) {
        return data['image_url'];
      }
      return null;
    } catch (e) {
      debugPrint('Error al subir: $e');
      return null;
    }
  }

  /// Seleccionar una planta y cargar sus sensores
  Future<void> selectPlant(PlantModel plant) async {
    _selectedPlant = plant;
    _livePumpPlantId = null;
    _livePumpOn = null;
    notifyListeners();
    await loadSensorData(plant.id);
  }

  /// Cargar datos de sensores de una planta
  Future<void> loadSensorData(int plantId) async {
    final requestId = ++_sensorRequestId;
    try {
      // 1. INTENTO DE CONEXIÓN CON HARDWARE REAL (ESP8266 Serial)
      try {
        final hardwareData = await ApiService.get('/api/hardware/clima-actual');
        // Ya se lanzó otra carga: esta respuesta es vieja
        if (requestId != _sensorRequestId) return;
        // Solo usar el hardware si el ESP8266 está realmente conectado (el
        // backend devuelve valores por defecto cuando no lo está) y si está
        // instalado en esta planta; las demás usan sus lecturas guardadas.
        if (hardwareData != null &&
            hardwareData['estado_conexion'] == 'En línea' &&
            hardwareData['plant_id'] == plantId &&
            hardwareData['temperatura'] != null) {
          final plant = _plants.firstWhere(
            (p) => p.id == plantId,
            orElse: () => _plants.first,
          );
          num temp = hardwareData['temperatura'] ?? 26.0;
          num humAire =
              hardwareData['humedad_aire'] ?? hardwareData['humedad'] ?? 50.0;
          bool ledOn = hardwareData['led_encendido'] ?? false;
          // La salud la calcula el backend; la app no la recalcula.

          _currentSensorData = SensorDataModel(
            plantId: plantId,
            plantName: plant.commonName,
            temperature: temp.toDouble(),
            airHumidity: humAire.toDouble(),
            soilHumidity: (hardwareData['humedad_suelo'] as num?)?.toDouble(),
            lightLevel: 85.0, // Valor preestablecido para el UI
            solarVoltage: 12.4,
            batteryLevel: 98.0,
            pumpActive: ledOn
                ? 1
                : 0, // 1 si el LED del circuito está prendido (tierra seca)
            healthStatus: SensorDataModel.parseHealthStatus(
              hardwareData['health_status'],
            ),
            healthScore: (hardwareData['health_score'] as num?)?.toDouble(),
            recordedAt: DateTime.now(),
          );
          _livePumpPlantId = plantId;
          _livePumpOn = ledOn;
          notifyListeners();
          return; // Salimos temprano y exitosamente
        }
      } catch (e) {
        debugPrint('Hardware (ESP8266) no detectado, usando datos de BDD: $e');
      }

      // 2. CONEXIÓN NORMAL CON BASE DE DATOS (Si la Raspberry Falla)
      final data = await ApiService.get(
        '${ApiConstants.sensorsLatest}/$plantId',
      );
      if (requestId != _sensorRequestId) return;
      _currentSensorData = SensorDataModel.fromJson(data);
    } catch (e) {
      if (requestId != _sensorRequestId) return;
      // Datos demo si falla la API
      final plant = _plants.firstWhere(
        (p) => p.id == plantId,
        orElse: () => _plants.first,
      );
      _currentSensorData = SensorDataModel.demo(plantId, plant.commonName);
    }
    // Lectura de base o demo: no es dato en vivo
    _livePumpPlantId = null;
    _livePumpOn = null;
    notifyListeners();
  }

  /// Cargar el historial de lecturas de una planta (para Estadísticas).
  /// Sin datos demo: si falla, deja la lista vacía y un mensaje de error.
  Future<bool> loadSensorHistory(int plantId, {required int hours}) async {
    final requestId = ++_historyRequestId;
    _sensorHistory = [];
    _historyError = null;
    _isHistoryLoading = true;
    notifyListeners();

    try {
      final data = await ApiService.get(
        '${ApiConstants.sensorsHistory}/$plantId',
        queryParams: {'hours': '$hours', 'limit': '200'},
      );
      final readings =
          (data as List)
              .map(
                (r) => SensorReadingModel.fromJson(r as Map<String, dynamic>),
              )
              .toList()
            ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      // Ya se lanzó otra carga: esta respuesta es vieja
      if (requestId != _historyRequestId) return true;
      _sensorHistory = readings;
      _isHistoryLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error al cargar el historial: $e');
      if (requestId != _historyRequestId) return false;
      _sensorHistory = [];
      _historyError = 'No se pudieron cargar las estadísticas.';
      _isHistoryLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Activar riego remoto
  Future<bool> activateWatering(int plantId, {int durationSeconds = 10}) async {
    _error = null;
    try {
      await ApiService.post(
        ApiConstants.controlWater,
        body: {'plant_id': plantId, 'duration_seconds': durationSeconds},
      );
      // Recargar datos de sensores después de regar
      await loadSensorData(plantId);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'No se pudo conectar con el servidor para activar el riego';
      notifyListeners();
      return false;
    }
  }

  /// Detener el riego remoto. No recarga sensores: la pantalla espera la
  /// confirmación del ESP8266.
  Future<bool> stopWatering(int plantId) async {
    _error = null;
    try {
      await ApiService.post(
        ApiConstants.controlStopWater,
        body: {'plant_id': plantId},
      );
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'No se pudo conectar con el servidor para detener el riego.';
      notifyListeners();
      return false;
    }
  }

  /// Agrupar plantas por ubicación
  Map<String, List<PlantModel>> get plantsByLocation {
    final map = <String, List<PlantModel>>{};
    for (final plant in _plants) {
      final loc = plant.location ?? 'Otro';
      map.putIfAbsent(loc, () => []);
      map[loc]!.add(plant);
    }
    return map;
  }

  /// Buscar plantas por nombre
  List<PlantModel> searchPlants(String query) {
    if (query.isEmpty) return _plants;
    return _plants
        .where((p) => p.commonName.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  /// Cargar datos de demostración (sin backend)
  void _loadDemoPlants() {
    _isDemoMode = true;
    _plants = [
      PlantModel(
        id: 1,
        commonName: 'Echeveria',
        scientificName: 'Echeveria elegans',
        plantType: 'Suculento',
        location: 'Balcon',
        careDifficulty: 'Fácil',
        wateringFrequency: 'Cada 2 semanas',
        sunExposure: 'Parcial',
        soilType: 'Franco arenoso',
        soilPhMin: 5.5,
        soilPhMax: 6.5,
        maxSize: 'Hasta 20 in',
        toxicity: 'No Tóxica',
        hardinessZones: '9 - 11',
        description:
            'La Echeveria es una suculenta originaria de México. Perfecta para principiantes.',
        minHumidity: 25.0,
        maxTemperature: 35.0,
        minLight: 30.0,
      ),
      PlantModel(
        id: 2,
        commonName: 'Áloe de arena',
        scientificName: 'Aloe vera',
        plantType: 'Suculento',
        location: 'Dormitorio',
        careDifficulty: 'Fácil',
        wateringFrequency: 'Cada 2 semanas',
        sunExposure: 'Parcial',
        soilType: 'Franco arenoso',
        soilPhMin: 5.5,
        soilPhMax: 6.5,
        maxSize: 'Hasta 20 in',
        toxicity: 'No Tóxica',
        hardinessZones: '9 - 11',
        description: 'Áloe vera conocida por propiedades medicinales.',
      ),
      PlantModel(
        id: 3,
        commonName: 'Nenúfares',
        scientificName: 'Nymphaea',
        plantType: 'Acuática',
        location: 'Jardin',
      ),
      PlantModel(
        id: 4,
        commonName: 'Geranios',
        scientificName: 'Pelargonium',
        plantType: 'Floral',
        location: 'Balcon',
      ),
      PlantModel(
        id: 5,
        commonName: 'Hoja aplastada',
        scientificName: 'Kalanchoe thyrsiflora',
        plantType: 'Suculento',
        location: 'Balcon',
      ),
    ];
  }
}
