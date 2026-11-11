// ============================================================
// Solar-Grow - Pantalla de Recomendaciones IA
// ============================================================
import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Pantalla de recomendaciones generadas por la IA
class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Datos de demo de recomendaciones de IA
    final recommendations = [
      _RecItem(
        icon: '💧',
        category: 'Riego',
        title: 'Aumentar frecuencia de riego',
        message:
            'La humedad del suelo de tu Echeveria ha estado por debajo del 30% '
            'en las últimas 48 horas. Recomendamos regar con 200ml de agua cada '
            '3 días hasta que la humedad se estabilice.',
        priority: 'alta',
        plantName: 'Echeveria',
      ),
      _RecItem(
        icon: '☀️',
        category: 'Luz',
        title: 'Exposición solar óptima',
        message:
            'Tu Áloe de arena está recibiendo la cantidad ideal de luz solar. '
            'El tracking solar ha mantenido un promedio de 67% de exposición. '
            'Mantén la ubicación actual.',
        priority: 'baja',
        plantName: 'Áloe de arena',
      ),
      _RecItem(
        icon: '🌡️',
        category: 'Temperatura',
        title: 'Proteger del calor',
        message:
            'Las temperaturas superaron los 32°C ayer. Las suculentas pueden '
            'sufrir estrés térmico. Considera proporcionar sombra parcial '
            'durante las horas pico (12-3 PM).',
        priority: 'media',
        plantName: 'Echeveria',
      ),
      _RecItem(
        icon: '🧪',
        category: 'Fertilización',
        title: 'Próxima fertilización programada',
        message:
            'Es momento de fertilizar tu Echeveria. Usa un fertilizante '
            'para suculentas diluido al 50%. La última fertilización fue '
            'hace 3 semanas.',
        priority: 'media',
        plantName: 'Echeveria',
      ),
      _RecItem(
        icon: '📸',
        category: 'Diagnóstico IA',
        title: 'Análisis visual completado',
        message:
            'La cámara de tu computador analizó tu Áloe de arena. '
            'Estado general: Bueno (87% confianza). No se detectaron '
            'plagas ni enfermedades. Las hojas presentan color saludable.',
        priority: 'baja',
        plantName: 'Áloe de arena',
      ),
      _RecItem(
        icon: '🔋',
        category: 'Sistema',
        title: 'Rendimiento del panel solar',
        message:
            'El panel solar de 20W ha generado un promedio de 12.8W en las '
            'últimas 24 horas. El tracking solar está funcionando correctamente. '
            'Batería al 85%. Recomendación: limpiar el panel cada 2 semanas.',
        priority: 'baja',
        plantName: 'Sistema',
      ),
    ];

    return Scaffold(
      backgroundColor: SolarColors.background,
      appBar: AppBar(
        title: const Text('Recomendaciones IA'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: SolarColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: SolarColors.primary, size: 16),
                SizedBox(width: 4),
                Text(
                  'IA',
                  style: TextStyle(
                    color: SolarColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: recommendations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final rec = recommendations[index];
          return _buildRecommendationCard(rec);
        },
      ),
    );
  }

  Widget _buildRecommendationCard(_RecItem rec) {
    Color categoryColor;
    switch (rec.priority) {
      case 'alta':
        categoryColor = SolarColors.error;
        break;
      case 'media':
        categoryColor = SolarColors.warning;
        break;
      default:
        categoryColor = SolarColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(rec.icon, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rec.category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: categoryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SolarColors.cardBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            rec.plantName,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: SolarColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rec.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: SolarColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mensaje
          Text(
            rec.message,
            style: const TextStyle(
              fontSize: 13,
              color: SolarColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecItem {
  final String icon;
  final String category;
  final String title;
  final String message;
  final String priority;
  final String plantName;

  _RecItem({
    required this.icon,
    required this.category,
    required this.title,
    required this.message,
    required this.priority,
    required this.plantName,
  });
}
