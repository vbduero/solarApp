// ============================================================
// Solar-Grow - Modelo de Planta
// ============================================================
import '../services/api_service.dart';

/// Modelo que representa una planta monitoreada
class PlantModel {
  final int id;
  final String commonName;
  final String? scientificName;
  final String? plantType;
  final String? imageUrl;
  final String? location;
  final String? careDifficulty;
  final String? wateringFrequency;
  final String? sunExposure;
  final String? soilType;
  final double? soilPhMin;
  final double? soilPhMax;
  final String? maxSize;
  final String? toxicity;
  final String? hardinessZones;
  final String? description;
  final double minHumidity;
  final double maxTemperature;
  final double minLight;
  final DateTime? lastFertilized;
  final DateTime? nextFertilizeDate;
  final bool isActive;
  final DateTime? createdAt;

  PlantModel({
    required this.id,
    required this.commonName,
    this.scientificName,
    this.plantType,
    this.imageUrl,
    this.location,
    this.careDifficulty,
    this.wateringFrequency,
    this.sunExposure,
    this.soilType,
    this.soilPhMin,
    this.soilPhMax,
    this.maxSize,
    this.toxicity,
    this.hardinessZones,
    this.description,
    this.minHumidity = 30.0,
    this.maxTemperature = 35.0,
    this.minLight = 20.0,
    this.lastFertilized,
    this.nextFertilizeDate,
    this.isActive = true,
    this.createdAt,
  });

  factory PlantModel.fromJson(Map<String, dynamic> json) {
    return PlantModel(
      id: json['id'],
      commonName: json['common_name'],
      scientificName: json['scientific_name'],
      plantType: json['plant_type'],
      imageUrl: json['image_url'] != null
          ? (json['image_url'].startsWith('http')
                ? json['image_url']
                : '${ApiService.baseUrl}${json['image_url']}')
          : null,
      location: json['location'],
      careDifficulty: json['care_difficulty'],
      wateringFrequency: json['watering_frequency'],
      sunExposure: json['sun_exposure'],
      soilType: json['soil_type'],
      soilPhMin: json['soil_ph_min']?.toDouble(),
      soilPhMax: json['soil_ph_max']?.toDouble(),
      maxSize: json['max_size'],
      toxicity: json['toxicity'],
      hardinessZones: json['hardiness_zones'],
      description: json['description'],
      minHumidity: (json['min_humidity'] ?? 30.0).toDouble(),
      maxTemperature: (json['max_temperature'] ?? 35.0).toDouble(),
      minLight: (json['min_light'] ?? 20.0).toDouble(),
      lastFertilized: json['last_fertilized'] != null
          ? DateTime.parse(json['last_fertilized'])
          : null,
      nextFertilizeDate: json['next_fertilize_date'] != null
          ? DateTime.parse(json['next_fertilize_date'])
          : null,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }
}
