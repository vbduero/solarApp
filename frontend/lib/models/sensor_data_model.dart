// ============================================================
// Solar-Grow - Modelo de Datos de Sensores
// ============================================================

/// Modelo de los datos más recientes de los sensores
class SensorDataModel {
  final int plantId;
  final String plantName;
  final double? temperature;
  final double? airHumidity;
  final double? soilHumidity;
  final double? lightLevel;
  final double? solarVoltage;
  final double? batteryLevel;
  final int pumpActive;
  final String healthStatus;
  final double? healthScore;
  final DateTime? recordedAt;

  SensorDataModel({
    required this.plantId,
    required this.plantName,
    this.temperature,
    this.airHumidity,
    this.soilHumidity,
    this.lightLevel,
    this.solarVoltage,
    this.batteryLevel,
    this.pumpActive = 0,
    this.healthStatus = 'Sin datos',
    this.healthScore,
    this.recordedAt,
  });

  /// Estados de salud válidos que manda el backend (cálculo único).
  static const List<String> _validHealthStatuses = [
    'Sana',
    'Necesita agua',
    'Exceso de calor',
    'Critica',
    'Sin datos',
  ];

  /// Devuelve el estado solo si es exactamente uno de los conocidos;
  /// cualquier otra cosa (nulo, número, inglés, otro formato) es 'Sin datos'.
  static String parseHealthStatus(Object? raw) {
    if (raw is String && _validHealthStatuses.contains(raw)) return raw;
    return 'Sin datos';
  }

  /// Indica si necesita agua
  bool get needsWater =>
      healthStatus == 'Necesita agua' || healthStatus == 'Critica';

  /// Texto del estado para mostrar al usuario
  String get healthLabel {
    switch (healthStatus) {
      case 'Critica':
        return 'Crítica';
      case 'Sin datos':
        return 'sin lecturas';
      default:
        return healthStatus;
    }
  }

  factory SensorDataModel.fromJson(Map<String, dynamic> json) {
    return SensorDataModel(
      plantId: json['plant_id'],
      plantName: json['plant_name'] ?? '',
      temperature: json['temperature']?.toDouble(),
      airHumidity: json['air_humidity']?.toDouble(),
      soilHumidity: json['soil_humidity']?.toDouble(),
      lightLevel: json['light_level']?.toDouble(),
      solarVoltage: json['solar_voltage']?.toDouble(),
      batteryLevel: json['battery_level']?.toDouble(),
      pumpActive: json['pump_active'] ?? 0,
      healthStatus: parseHealthStatus(json['health_status']),
      healthScore: (json['health_score'] as num?)?.toDouble(),
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'])
          : null,
    );
  }

  /// Lectura vacía: sin valores inventados (planta de ejemplo o sin conexión)
  factory SensorDataModel.empty(int plantId, String plantName) {
    return SensorDataModel(
      plantId: plantId,
      plantName: plantName,
      pumpActive: 0,
      healthStatus: 'Sin datos',
    );
  }
}
