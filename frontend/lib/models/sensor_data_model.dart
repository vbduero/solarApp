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
  final double healthScore;
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
    this.healthStatus = 'healthy',
    this.healthScore = 100.0,
    this.recordedAt,
  });

  /// Indica si la planta está sana (para la animación feliz/triste)
  bool get isHealthy => healthScore >= 60;

  /// Indica si necesita agua
  bool get needsWater =>
      healthStatus == 'needs_water' || healthStatus == 'critical';

  /// Indica si necesita luz
  bool get needsLight => healthStatus == 'needs_light';

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
      healthStatus: json['health_status'] ?? 'unknown',
      healthScore: (json['health_score'] ?? 50.0).toDouble(),
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'])
          : null,
    );
  }

  /// Datos por defecto para modo demo / sin conexión
  factory SensorDataModel.demo(int plantId, String plantName) {
    return SensorDataModel(
      plantId: plantId,
      plantName: plantName,
      temperature: 26.0,
      airHumidity: 65.0,
      soilHumidity: 50.0,
      lightLevel: 67.0,
      solarVoltage: 15.5,
      batteryLevel: 85.0,
      pumpActive: 0,
      healthStatus: 'healthy',
      healthScore: 85.0,
      recordedAt: DateTime.now(),
    );
  }
}
