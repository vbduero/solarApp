// ============================================================
// Solar-Grow - Pantalla de Información de Planta
// ============================================================
// Muestra toda la información botánica detallada de la planta.
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/plant_provider.dart';

/// Pantalla con información botánica completa de la planta
class PlantInfoScreen extends StatelessWidget {
  const PlantInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final plant = context.watch<PlantProvider>().selectedPlant;

    if (plant == null) {
      return const Scaffold(body: Center(child: Text('Planta no encontrada')));
    }

    return Scaffold(
      backgroundColor: SolarColors.background,
      body: CustomScrollView(
        slivers: [
          // Header con imagen
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: SolarColors.textPrimary,
                  size: 20,
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      SolarColors.primary.withValues(alpha: 0.3),
                      SolarColors.cardBg,
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      if (plant.imageUrl != null)
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                            image: DecorationImage(
                              image: NetworkImage(plant.imageUrl!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      else
                        Text(
                          _getPlantEmoji(plant.plantType),
                          style: const TextStyle(fontSize: 100),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        plant.commonName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: SolarColors.textPrimary,
                        ),
                      ),
                      if (plant.scientificName != null)
                        Text(
                          plant.scientificName!,
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: SolarColors.textSecondary.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Contenido
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjetas de cuidado rápido
                  _buildCareCards(plant),
                  const SizedBox(height: 20),
                  // Tabla de información
                  _buildInfoTable(plant),
                  const SizedBox(height: 20),
                  // Descripción
                  if (plant.description != null) _buildDescription(plant),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCareCards(plant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildCareItem(
            icon: '🌿',
            label: 'Cuidado',
            value: plant.careDifficulty ?? 'Fácil',
          ),
          _buildCareDivider(),
          _buildCareItem(
            icon: '💧',
            label: 'Regar',
            value: plant.wateringFrequency ?? 'Regular',
          ),
          _buildCareDivider(),
          _buildCareItem(
            icon: '☀️',
            label: 'Sol',
            value: plant.sunExposure ?? 'Parcial',
          ),
        ],
      ),
    );
  }

  Widget _buildCareItem({
    required String icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: SolarColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 11, color: SolarColors.textLight),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCareDivider() {
    return Container(
      width: 1,
      height: 50,
      color: SolarColors.textLight.withValues(alpha: 0.15),
    );
  }

  Widget _buildInfoTable(plant) {
    final info = <MapEntry<String, String>>[
      MapEntry('Nombre Común', plant.commonName),
      if (plant.toxicity != null) MapEntry('Toxicidad', plant.toxicity!),
      if (plant.plantType != null) MapEntry('Tipo de planta', plant.plantType!),
      if (plant.sunExposure != null)
        MapEntry('Exposición al sol', plant.sunExposure!),
      if (plant.soilType != null) MapEntry('Tipo de suelo', plant.soilType!),
      if (plant.maxSize != null) MapEntry('Tamaño en madurez', plant.maxSize!),
      if (plant.soilPhMin != null && plant.soilPhMax != null)
        MapEntry('Ph del suelo', '${plant.soilPhMin} - ${plant.soilPhMax}'),
      if (plant.hardinessZones != null)
        MapEntry('Zonas de rusticidad', plant.hardinessZones!),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(info.length, (index) {
          final entry = info[index];
          final isEven = index % 2 == 0;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isEven ? SolarColors.cardBgLight : Colors.white,
              borderRadius: BorderRadius.vertical(
                top: index == 0 ? const Radius.circular(16) : Radius.zero,
                bottom: index == info.length - 1
                    ? const Radius.circular(16)
                    : Radius.zero,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: SolarColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 13,
                      color: SolarColors.textSecondary,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDescription(plant) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🌍', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'Descripción general de la planta',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: SolarColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            plant.description ?? '',
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

  String _getPlantEmoji(String? plantType) {
    switch (plantType) {
      case 'Suculento':
        return '🪴';
      case 'Floral':
        return '🌺';
      case 'Acuática':
        return '🪷';
      default:
        return '🌿';
    }
  }
}
