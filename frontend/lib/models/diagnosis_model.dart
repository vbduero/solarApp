// ============================================================
// Solar-Grow - Modelo de Diagnóstico IA
// ============================================================

/// Diagnóstico guardado de una planta (GET /api/ai/diagnosis/{plant_id}).
/// Ignora confidence, detected_issues y suggested_actions: no se muestran.
class DiagnosisModel {
  final int id;
  final int plantId;
  final String healthStatus;
  final String? diagnosis;
  final String? imageUrl;
  final DateTime createdAt;

  const DiagnosisModel({
    required this.id,
    required this.plantId,
    required this.healthStatus,
    required this.createdAt,
    this.diagnosis,
    this.imageUrl,
  });

  factory DiagnosisModel.fromJson(Map<String, dynamic> json) {
    return DiagnosisModel(
      id: json['id'] as int,
      plantId: json['plant_id'] as int,
      healthStatus: json['health_status'] as String,
      diagnosis: json['diagnosis'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: _parseUtc(json['created_at'] as String),
    );
  }

  /// Una fecha sin zona (SQLite) se interpreta como UTC; con Z u offset se
  /// conserva ese instante.
  static DateTime _parseUtc(String raw) {
    final parsed = DateTime.parse(raw);
    if (parsed.isUtc) return parsed;
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  /// Estado de salud para mostrar al usuario («Critica» lleva tilde).
  String get healthLabel => healthStatus == 'Critica' ? 'Crítica' : healthStatus;
}
