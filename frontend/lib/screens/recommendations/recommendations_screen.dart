// ============================================================
// Solar-Grow - Pantalla de Recomendaciones IA
// ============================================================
import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Pantalla de recomendaciones. Todavía no se generan de forma automática,
/// así que muestra un estado vacío honesto.
class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.menu_book_outlined,
                size: 56,
                color: SolarColors.textLight,
              ),
              SizedBox(height: 16),
              Text(
                'Todavía no hay recomendaciones automáticas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SolarColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Para revisar una planta, usa el Diagnóstico IA del menú o el historial de Diagnósticos de la planta.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: SolarColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
