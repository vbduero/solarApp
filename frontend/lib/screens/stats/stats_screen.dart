// ============================================================
// Solar-Grow - Pantalla de Estadísticas
// ============================================================
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../config/theme.dart';

/// Pantalla con gráficos de sensores e historial de la planta
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _selectedPeriod = '24h';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SolarColors.background,
      appBar: AppBar(
        title: const Text('Estadísticas'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Selector de período
            _buildPeriodSelector(),
            const SizedBox(height: 20),
            // Gráfico de Temperatura
            _buildChartCard(
              title: 'Temperatura',
              icon: Icons.thermostat,
              color: SolarColors.temperature,
              unit: '°C',
              spots: _generateDemoSpots(22, 32, 12),
            ),
            const SizedBox(height: 16),
            // Gráfico de Humedad del suelo
            _buildChartCard(
              title: 'Humedad del Suelo',
              icon: Icons.water_drop,
              color: SolarColors.humidity,
              unit: '%',
              spots: _generateDemoSpots(25, 70, 12),
            ),
            const SizedBox(height: 16),
            // Gráfico de Luz solar
            _buildChartCard(
              title: 'Luz Solar',
              icon: Icons.wb_sunny,
              color: SolarColors.light,
              unit: '%',
              spots: _generateDemoSpots(10, 90, 12),
            ),
            const SizedBox(height: 16),
            // Panel solar y batería
            _buildSystemStats(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['6h', '24h', '7d', '30d'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SolarColors.cardBgLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = period == _selectedPeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = period),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    period,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? SolarColors.primary
                          : SolarColors.textLight,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Color color,
    required String unit,
    required List<FlSpot> spots,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: SolarColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${spots.last.y.round()}$unit',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 10,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: SolarColors.textLight.withValues(alpha: 0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: color,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withValues(alpha: 0.25),
                          color.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        return LineTooltipItem(
                          '${spot.y.round()}$unit',
                          TextStyle(color: color, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              Text('⚡', style: TextStyle(fontSize: 20)),
              SizedBox(width: 8),
              Text(
                'Sistema Solar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: SolarColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Panel Solar',
                  value: '15.2V',
                  icon: Icons.solar_power,
                  color: SolarColors.secondary,
                  progress: 0.76,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  label: 'Batería',
                  value: '85%',
                  icon: Icons.battery_charging_full,
                  color: SolarColors.battery,
                  progress: 0.85,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  label: 'Potencia',
                  value: '12.8W',
                  icon: Icons.flash_on,
                  color: SolarColors.light,
                  progress: 0.64,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatItem(
                  label: 'Tracker',
                  value: 'Activo',
                  icon: Icons.gps_fixed,
                  color: SolarColors.primary,
                  progress: 1.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required double progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, color: SolarColors.textLight),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateDemoSpots(double min, double max, int count) {
    final spots = <FlSpot>[];
    for (int i = 0; i < count; i++) {
      final value = min + (max - min) * (0.3 + 0.7 * (i % 4) / 4);
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }
}
