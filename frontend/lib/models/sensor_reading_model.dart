// ============================================================
// Solar-Grow - Modelo de una lectura del historial de sensores
// ============================================================

/// Una lectura guardada de los sensores (historial).
/// Ignora a propósito luz, voltaje solar y batería: son valores de relleno.
class SensorReadingModel {
  final int id;
  final int plantId;
  final double? temperature;
  final double? airHumidity;
  final double? soilHumidity;
  final DateTime recordedAt;

  SensorReadingModel({
    required this.id,
    required this.plantId,
    this.temperature,
    this.airHumidity,
    this.soilHumidity,
    required this.recordedAt,
  });

  factory SensorReadingModel.fromJson(Map<String, dynamic> json) {
    return SensorReadingModel(
      id: json['id'] as int,
      plantId: json['plant_id'] as int,
      temperature: (json['temperature'] as num?)?.toDouble(),
      airHumidity: (json['air_humidity'] as num?)?.toDouble(),
      soilHumidity: (json['soil_humidity'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
}
