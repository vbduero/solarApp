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
import '../config/demo_messages.dart';

/// Provider que gestiona las plantas y datos de sensores
class PlantProvider extends ChangeNotifier {
  List<PlantModel> _plants = [];
  PlantModel? _selectedPlant;
  SensorDataModel? _currentSensorData;
  bool _isLoading = false;
  String? _error;
  int _plantsRequestId = 0;
  bool _sensorsUnavailable = false;

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

  /// Hay plantas de ejemplo en la lista (modo demo). Se calcula sobre `plants`.
  bool get showingDemoPlants => plants.any((p) => p.isDemo);

  /// Las lecturas fallaron (sin conexión, 401 o 500): se muestran vacías.
  bool get sensorsUnavailable => _sensorsUnavailable;

  /// Estado de la bomba según el ESP8266 en línea para esa planta.
  /// `null` significa que no hay dato en vivo (desconectado, otra planta, BDD o demo).
  bool? livePumpOn(int plantId) =>
      _livePumpPlantId == plantId ? _livePumpOn : null;

  /// Obtener todas las plantas del usuario
  Future<void> loadPlants() async {
    final requestId = ++_plantsRequestId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.get(ApiConstants.plants);
      // Respuesta de una sesión o carga anterior: no se aplica
      if (requestId != _plantsRequestId) return;
      _plants = (data as List).map((p) => PlantModel.fromJson(p)).toList();
      // Una planta de ejemplo elegida no sobrevive a la vuelta de la conexión
      if (_selectedPlant?.isDemo == true) {
        _selectedPlant = null;
        _currentSensorData = null;
        _sensorsUnavailable = false;
        _livePumpPlantId = null;
        _livePumpOn = null;
        _sensorRequestId++;
      }
    } catch (e) {
      if (requestId != _plantsRequestId) return;
      // Si falla la API, cargar plantas de ejemplo (marcadas isDemo)
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
    _sensorsUnavailable = false;
    notifyListeners();
    await loadSensorData(plant.id);
  }

  /// Nombre de la planta para una lectura, sin lanzar si la lista está vacía.
  String _plantNameFor(int plantId) {
    if (_selectedPlant?.id == plantId) return _selectedPlant!.commonName;
    for (final p in _plants) {
      if (p.id == plantId) return p.commonName;
    }
    return '';
  }

  /// Limpia todo el estado al cerrar sesión e invalida las peticiones en vuelo.
  void clearSession() {
    _plantsRequestId++;
    _sensorRequestId++;
    _historyRequestId++;
    _plants = [];
    _selectedPlant = null;
    _currentSensorData = null;
    _sensorsUnavailable = false;
    _livePumpPlantId = null;
    _livePumpOn = null;
    _error = null;
    _sensorHistory = [];
    _isHistoryLoading = false;
    _historyError = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Cargar datos de sensores de una planta
  Future<void> loadSensorData(int plantId) async {
    final requestId = ++_sensorRequestId;

    // Planta de ejemplo: no hay lecturas reales y no se hace ninguna petición
    if (_selectedPlant != null &&
        _selectedPlant!.id == plantId &&
        _selectedPlant!.isDemo) {
      _currentSensorData = SensorDataModel.empty(
        plantId,
        _selectedPlant!.commonName,
      );
      _sensorsUnavailable = false;
      _livePumpPlantId = null;
      _livePumpOn = null;
      notifyListeners();
      return;
    }

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
          final num temp = hardwareData['temperatura'] as num;
          final num? humAire =
              (hardwareData['humedad_aire'] ?? hardwareData['humedad']) as num?;
          bool ledOn = hardwareData['led_encendido'] ?? false;
          // La salud la calcula el backend; la app no la recalcula.

          // Luz, voltaje solar y batería no tienen sensor: quedan en null.
          _currentSensorData = SensorDataModel(
            plantId: plantId,
            plantName: _plantNameFor(plantId),
            temperature: temp.toDouble(),
            airHumidity: humAire?.toDouble(),
            soilHumidity: (hardwareData['humedad_suelo'] as num?)?.toDouble(),
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
          _sensorsUnavailable = false;
          notifyListeners();
          return; // Salimos temprano y exitosamente
        }
      } catch (e) {
        debugPrint('Hardware (ESP8266) no detectado, usando datos de BDD: $e');
      }

      // 2. CONEXIÓN NORMAL CON BASE DE DATOS
      final data = await ApiService.get(
        '${ApiConstants.sensorsLatest}/$plantId',
      );
      if (requestId != _sensorRequestId) return;
      _currentSensorData = SensorDataModel.fromJson(data);
      _sensorsUnavailable = false;
    } catch (e) {
      if (requestId != _sensorRequestId) return;
      // Sin datos inventados: lectura vacía y aviso de que no hay conexión
      _currentSensorData = SensorDataModel.empty(
        plantId,
        _plantNameFor(plantId),
      );
      _sensorsUnavailable = true;
    }
    // Lectura de base o vacía: no es dato en vivo
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

  /// La planta elegida es de ejemplo y es la que se quiere controlar.
  bool _isDemoSelected(int plantId) =>
      _selectedPlant != null &&
      _selectedPlant!.id == plantId &&
      _selectedPlant!.isDemo;

  /// Activar riego remoto
  Future<bool> activateWatering(int plantId, {int durationSeconds = 10}) async {
    if (_isDemoSelected(plantId)) {
      _error = DemoMessages.notAvailable;
      notifyListeners();
      return false;
    }
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
    if (_isDemoSelected(plantId)) {
      _error = DemoMessages.notAvailable;
      notifyListeners();
      return false;
    }
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

  /// Cargar plantas de ejemplo (sin backend), todas marcadas con isDemo
  void _loadDemoPlants() {
    _plants = [
      PlantModel(
        isDemo: true,
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
        isDemo: true,
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
        isDemo: true,
        id: 3,
        commonName: 'Nenúfares',
        scientificName: 'Nymphaea',
        plantType: 'Acuática',
        location: 'Jardin',
      ),
      PlantModel(
        isDemo: true,
        id: 4,
        commonName: 'Geranios',
        scientificName: 'Pelargonium',
        plantType: 'Floral',
        location: 'Balcon',
      ),
      PlantModel(
        isDemo: true,
        id: 5,
        commonName: 'Hoja aplastada',
        scientificName: 'Kalanchoe thyrsiflora',
        plantType: 'Suculento',
        location: 'Balcon',
      ),
    ];
  }
}
