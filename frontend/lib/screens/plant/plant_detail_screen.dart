// ============================================================
// Solar-Grow - Pantalla de Detalle de Planta
// ============================================================
// Muestra la planta animada con su estado de salud,
// datos de sensores y controles de riego.
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/plant_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/sensor_data_model.dart';
import '../../widgets/animated_plant.dart';
import '../../widgets/weather_bar.dart';
import '../../widgets/sensor_card.dart';

class PlantDetailScreen extends StatefulWidget {
  const PlantDetailScreen({super.key});

  @override
  State<PlantDetailScreen> createState() => _PlantDetailScreenState();
}

class _PlantDetailScreenState extends State<PlantDetailScreen> {
  bool _isWatering = false;

  @override
  void initState() {
    super.initState();
    // Cargar datos del sensor si no están cargados y estamos autenticados
    final auth = context.read<AuthProvider>();
    final plantProvider = context.read<PlantProvider>();

    if (auth.isAuthenticated &&
        plantProvider.selectedPlant != null &&
        plantProvider.currentSensorData == null) {
      plantProvider.loadSensorData(plantProvider.selectedPlant!.id);
    }
  }

  Future<void> _handleWatering() async {
    setState(() => _isWatering = true);

    final plantProvider = context.read<PlantProvider>();
    final plant = plantProvider.selectedPlant;
    if (plant != null) {
      await plantProvider.activateWatering(plant.id);
    }

    // Simular duración del riego
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      setState(() => _isWatering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [Text('💧  '), Text('¡Riego completado exitosamente!')],
          ),
          backgroundColor: SolarColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        final plant = plantProvider.selectedPlant;
        final sensorData =
            plantProvider.currentSensorData ??
            SensorDataModel.demo(plant?.id ?? 1, plant?.commonName ?? 'Planta');

        if (plant == null) {
          return const Scaffold(
            body: Center(child: Text('Planta no encontrada')),
          );
        }

        return Scaffold(
          backgroundColor: SolarColors.background,
          body: SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(user),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: WeatherBar(
                    city: user?.city ?? 'Neiva',
                    weather: sensorData.isHealthy
                        ? 'Parcialmente nublado'
                        : 'Parcialmente soleado',
                    temperature: sensorData.temperature?.round() ?? 26,
                  ),
                ),
                // Tab bar (Mis Plantas | Tareas)
                Padding(
                  padding: const EdgeInsets.fromLTRB(25, 10, 20, 10),
                  child: Row(
                    children: [
                      const Text(
                        'Mis Plantas',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      Container(
                        width: 3,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const Text(
                        'Tareas',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // Contenido
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      children: [
                        // Tarjetas de sensores (Humedad y Luz solar)
                        _buildSensorCards(sensorData),
                        const SizedBox(height: 4),
                        // Fecha de fertilización
                        _buildFertilizeInfo(plant),
                        const SizedBox(height: 16),
                        // Planta animada
                        AnimatedPlantWidget(
                          plantName: plant.commonName,
                          healthScore: sensorData.healthScore,
                          healthStatus: sensorData.healthStatus,
                          isWatering: _isWatering,
                          size: 340,
                        ),
                        const SizedBox(height: 30),
                        // Botones Info y Regar
                        _buildActionButtons(plant, sensorData),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNav(),
        );
      },
    );
  }

  Widget _buildHeader(user) {
    final currentAvatar = user?.avatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.menu, color: Colors.black87, size: 34),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/edit-profile');
            },
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: currentAvatar != null
                    ? Image.network(
                        currentAvatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 28,
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCards(SensorDataModel data) {
    return Row(
      children: [
        // Humedad
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.thermostat,
                      color: SolarColors.primaryDark,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Humedad:',
                      style: TextStyle(
                        color: SolarColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.soilHumidity?.round() ?? 0} %',
                  style: const TextStyle(
                    color: SolarColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Luz solar
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.wb_sunny_outlined,
                      color: SolarColors.primaryDark,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Luz solar:',
                      style: TextStyle(
                        color: SolarColors.primaryDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${data.lightLevel?.round() ?? 0} %',
                  style: const TextStyle(
                    color: SolarColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFertilizeInfo(plant) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.science_outlined,
            color: SolarColors.primaryDark,
            size: 22,
          ),
          const SizedBox(width: 10),
          const Text(
            'Fertilizar: ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: SolarColors.primaryDark,
            ),
          ),
          Text(
            plant.nextFertilizeDate != null
                ? _formatDate(plant.nextFertilizeDate!)
                : 'Jun 26 de Marzo',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: SolarColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(plant, SensorDataModel data) {
    final needsWater = data.needsWater;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Botón Info
        _buildCircleButton(
          icon: Icons.search,
          label: 'Info',
          color: SolarColors.primaryDark,
          onTap: () => Navigator.pushNamed(context, '/plant-info'),
        ),
        // Botón Regar
        _buildCircleButton(
          icon: Icons.water_drop_outlined,
          label: 'Regar',
          color: needsWater ? SolarColors.error : SolarColors.primaryDark,
          isHighlighted: needsWater,
          onTap: _isWatering ? null : _handleWatering,
          isLoading: _isWatering,
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required Color color,
    bool isHighlighted = false,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 75,
            height: 75,
            decoration: BoxDecoration(
              color: Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
            ),
            child: isLoading
                ? Padding(
                    padding: const EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                      strokeWidth: 3.0,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: 3,
        onTap: (index) {
          Navigator.pop(context);
          // El home manejará la navegación
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Recomendaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            label: 'Notificaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            label: 'Estadísticas',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Mi Jardín'),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]}';
  }
}
