// ============================================================
// Solar-Grow - Tab de Mis Plantas
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/plant_model.dart';
import '../../providers/plant_provider.dart';

/// Tab que muestra las plantas del usuario organizadas por ubicación
class MyPlantsTab extends StatefulWidget {
  const MyPlantsTab({super.key});

  @override
  State<MyPlantsTab> createState() => _MyPlantsTabState();
}

class _MyPlantsTabState extends State<MyPlantsTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        if (plantProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: SolarColors.primary),
          );
        }

        final plants = _searchQuery.isEmpty
            ? plantProvider.plants
            : plantProvider.searchPlants(_searchQuery);

        final byLocation = <String, List<PlantModel>>{};
        for (final plant in plants) {
          final loc = plant.location ?? 'Otro';
          byLocation.putIfAbsent(loc, () => []);
          byLocation[loc]!.add(plant);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra de búsqueda
              _buildSearchBar(),
              const SizedBox(height: 16),
              // Grid de plantas por ubicación
              if (byLocation.isNotEmpty) _buildPlantGrid(plants, byLocation),
              const SizedBox(height: 20),
              // Lista completa de plantas
              _buildPlantList(plants),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Buscar mis plantas',
          prefixIcon: const Icon(Icons.search, color: SolarColors.textLight),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: SolarColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPlantGrid(
    List<PlantModel> allPlants,
    Map<String, List<PlantModel>> byLocation,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: byLocation.entries.map((entry) {
          return _buildLocationCard(entry);
        }).toList(),
      ),
    );
  }

  Widget _buildLocationCard(MapEntry<String, List<PlantModel>> entry) {
    final locationName = entry.key;
    final locationPlants = entry.value;
    final displayPlants = locationPlants.take(4).toList();

    return Container(
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 140,
            height: 140,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildMiniGrid(displayPlants),
          ),
          const SizedBox(height: 12),
          Text(
            locationName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: SolarColors.primaryDark,
            ),
          ),
          Text(
            '${locationPlants.length} planta${locationPlants.length != 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 13, color: SolarColors.textLight),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniGrid(List<PlantModel> plants) {
    if (plants.isEmpty) return const SizedBox();

    if (plants.length == 1) {
      return _buildMiniGridImage(plants.first);
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: plants.length,
      itemBuilder: (context, index) {
        return _buildMiniGridImage(plants[index]);
      },
    );
  }

  Widget _buildMiniGridImage(PlantModel plant) {
    return Container(
      decoration: BoxDecoration(
        color: SolarColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: plant.imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                plant.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    _getPlantEmoji(plant.plantType),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                _getPlantEmoji(plant.plantType),
                style: const TextStyle(fontSize: 20),
              ),
            ),
    );
  }

  Widget _buildPlantList(List<PlantModel> plants) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Separador con línea punteada
        Row(
          children: List.generate(
            30,
            (index) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: 1,
                color: index % 2 == 0
                    ? SolarColors.textLight.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Todas las plantas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: SolarColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        // Lista de plantas
        ...plants.map((plant) => _buildPlantListItem(plant)),
      ],
    );
  }

  Widget _buildPlantListItem(PlantModel plant) {
    return Dismissible(
      key: Key('plant_${plant.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: SolarColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar Planta'),
            content: Text(
              '¿Estás seguro que deseas eliminar "${plant.commonName}"?\nSe borrará de tu base de datos permanentemente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text(
                  'Eliminar',
                  style: TextStyle(color: SolarColors.error),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        final provider = context.read<PlantProvider>();
        await provider.deletePlant(plant.id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${plant.commonName} eliminada')),
        );
      },
      child: GestureDetector(
        onTap: () => _navigateToPlant(plant),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Ícono de la planta
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: SolarColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: plant.imageUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          plant.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              _getPlantEmoji(plant.plantType),
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _getPlantEmoji(plant.plantType),
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              // Info de la planta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.commonName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: SolarColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plant.scientificName ?? plant.plantType ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SolarColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              // Flecha
              const Icon(Icons.chevron_right, color: SolarColors.textLight),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPlant(PlantModel plant) {
    context.read<PlantProvider>().selectPlant(plant);
    Navigator.of(context).pushNamed('/plant-detail');
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
