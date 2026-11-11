// ============================================================
// Solar-Grow - Pantalla de Estadísticas
// ============================================================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/plant_model.dart';
import '../../models/sensor_reading_model.dart';
import '../../providers/plant_provider.dart';

/// Pantalla con gráficos del historial real de sensores de una planta
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// Periodos disponibles y las horas que piden al API
  static const Map<String, int> _periods = {
    '6h': 6,
    '24h': 24,
    '7d': 168,
    '30d': 720,
  };

  String _selectedPeriod = '24h';

  /// Planta elegida en esta pantalla (no cambia la planta del detalle)
  int? _plantId;

  /// Se pone en true al lanzar la primera carga
  bool _started = false;
  bool _startScheduled = false;
  bool _fallbackScheduled = false;

  int get _hours => _periods[_selectedPeriod]!;

  /// Planta inicial: la seleccionada o, si no hay, la primera de la lista
  PlantModel? _currentPlant(PlantProvider provider) {
    final plants = provider.plants;
    if (plants.isEmpty) return null;
    // Solo se acepta una planta que esté en la lista del usuario
    final chosen = _plantId ?? provider.selectedPlant?.id;
    if (chosen != null) {
      for (final p in plants) {
        if (p.id == chosen) return p;
      }
    }
    return plants.first;
  }

  /// Si la planta que se mostraba ya no está en la lista, pasa a la primera
  /// y vuelve a pedir el historial (después del frame, nunca dentro de build)
  void _scheduleFallbackReload(PlantProvider provider) {
    final plants = provider.plants;
    if (!_started || _fallbackScheduled || _plantId == null) return;
    if (plants.isEmpty || plants.any((p) => p.id == _plantId)) return;
    _fallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fallbackScheduled = false;
      if (!mounted) return;
      final current = provider.plants;
      if (current.isEmpty || current.any((p) => p.id == _plantId)) return;
      _plantId = current.first.id;
      provider.loadSensorHistory(current.first.id, hours: _hours);
    });
  }

  /// Lanza la carga inicial después del primer frame, nunca dentro de build
  void _scheduleInitialLoad(PlantProvider provider) {
    if (_started || _startScheduled || provider.plants.isEmpty) return;
    _startScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScheduled = false;
      if (!mounted || _started) return;
      final plant = _currentPlant(provider);
      if (plant == null) return;
      _started = true;
      _plantId = plant.id;
      provider.loadSensorHistory(plant.id, hours: _hours);
    });
  }

  void _reload() {
    final provider = context.read<PlantProvider>();
    final plant = _currentPlant(provider);
    if (plant == null) return;
    _started = true;
    provider.loadSensorHistory(plant.id, hours: _hours);
  }

  void _selectPeriod(String period) {
    setState(() => _selectedPeriod = period);
    _reload();
  }

  void _selectPlant(int id) {
    setState(() => _plantId = id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlantProvider>();
    _scheduleInitialLoad(provider);
    _scheduleFallbackReload(provider);

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
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(PlantProvider provider) {
    final plant = _currentPlant(provider);

    if (plant == null) {
      if (provider.isLoading) return _buildLoading();
      return _buildMessage(
        icon: Icons.eco_outlined,
        text: 'Aún no tienes plantas registradas.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlantSelector(provider, plant),
        const SizedBox(height: 16),
        _buildPeriodSelector(),
        const SizedBox(height: 20),
        _buildContent(provider),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildContent(PlantProvider provider) {
    if (!_started || provider.isHistoryLoading) return _buildLoading();

    if (provider.historyError != null) {
      return Column(
        children: [
          _buildMessage(
            icon: Icons.error_outline,
            text: provider.historyError!,
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _reload,
              child: const Text('Reintentar'),
            ),
          ),
        ],
      );
    }

    final history = provider.sensorHistory;
    if (history.isEmpty) {
      return _buildMessage(
        icon: Icons.show_chart,
        text: 'Esta planta no tiene lecturas en este periodo.',
      );
    }

    // Eje X: minutos reales desde la primera lectura del periodo
    final origin = history.first.recordedAt;
    List<_Point> pointsOf(double? Function(SensorReadingModel) pick) {
      final points = <_Point>[];
      for (final r in history) {
        final value = pick(r);
        if (value == null) continue; // sin valor: no se dibuja como cero
        final minutes = r.recordedAt.difference(origin).inSeconds / 60.0;
        points.add(_Point(FlSpot(minutes, value), r.recordedAt));
      }
      return points;
    }

    return Column(
      children: [
        _buildChartCard(
          title: 'Temperatura',
          icon: Icons.thermostat,
          color: SolarColors.temperature,
          unit: '°C',
          points: pointsOf((r) => r.temperature),
        ),
        const SizedBox(height: 16),
        _buildChartCard(
          title: 'Humedad del Suelo',
          icon: Icons.water_drop,
          color: SolarColors.humidity,
          unit: '%',
          points: pointsOf((r) => r.soilHumidity),
        ),
        const SizedBox(height: 16),
        _buildChartCard(
          title: 'Humedad del Aire',
          icon: Icons.cloud_outlined,
          color: SolarColors.skyBlueLight,
          unit: '%',
          points: pointsOf((r) => r.airHumidity),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildMessage({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: SolarColors.textLight),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: SolarColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlantSelector(PlantProvider provider, PlantModel current) {
    final plants = provider.plants;
    return Row(
      children: [
        const Icon(Icons.eco, color: SolarColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: plants.length > 1
              ? DropdownButton<int>(
                  value: current.id,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: plants
                      .map(
                        (p) => DropdownMenuItem<int>(
                          value: p.id,
                          child: Text(p.commonName),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id != null) _selectPlant(id);
                  },
                )
              : Text(
                  current.commonName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: SolarColors.textPrimary,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SolarColors.cardBgLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: _periods.keys.map((period) {
          final isSelected = period == _selectedPeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () => _selectPeriod(period),
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
    required List<_Point> points,
  }) {
    final spots = points.map((p) => p.spot).toList();

    // Rangos con margen para que la rejilla no falle con valores iguales
    double minX = 0, maxX = 1, minY = 0, maxY = 1;
    if (spots.isNotEmpty) {
      minX = spots.map((s) => s.x).reduce(math.min);
      maxX = spots.map((s) => s.x).reduce(math.max);
      if (maxX == minX) {
        minX -= 1;
        maxX += 1;
      }
      final lo = spots.map((s) => s.y).reduce(math.min);
      final hi = spots.map((s) => s.y).reduce(math.max);
      final pad = math.max(1.0, (hi - lo) * 0.1);
      minY = lo - pad;
      maxY = hi + pad;
    }
    final timeFormat = DateFormat('d/MM HH:mm');

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
              if (spots.isNotEmpty)
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
          if (spots.isEmpty)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'Sin datos',
                  style: TextStyle(color: SolarColors.textLight),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 150,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: (maxY - minY) / 4,
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
                      preventCurveOverShooting: true,
                      color: color,
                      barWidth: 3,
                      // Con un solo punto la línea no se vería
                      dotData: FlDotData(show: spots.length == 1),
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
                          final at = points
                              .firstWhere((p) => p.spot.x == spot.x)
                              .time
                              .toLocal();
                          return LineTooltipItem(
                            '${spot.y.round()}$unit\n${timeFormat.format(at)}',
                            TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeFormat.format(points.first.time.toLocal()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: SolarColors.textLight,
                  ),
                ),
                Text(
                  timeFormat.format(points.last.time.toLocal()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: SolarColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Punto de una gráfica junto con la hora real de su lectura
class _Point {
  final FlSpot spot;
  final DateTime time;
  const _Point(this.spot, this.time);
}
