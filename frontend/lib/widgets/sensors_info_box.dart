// Solar-Grow - Caja «Lecturas del ESP8266» del diálogo de Diagnóstico IA
// Spec 005 · CA-13 y CA-20 (decisión D11 del plan).
import 'package:flutter/material.dart';
import '../config/demo_messages.dart';
import '../config/theme.dart';
import '../models/sensor_data_model.dart';

/// Muestra las lecturas reales del ESP8266. Un valor ausente se ve como
/// «Sin datos»; nunca se rellena con un número inventado.
class SensorsInfoBox extends StatelessWidget {
  final SensorDataModel? data;

  const SensorsInfoBox({super.key, required this.data});

  static String _format(double? value, String unit) =>
      value == null ? DemoMessages.noData : '${value.toStringAsFixed(1)}$unit';

  @override
  Widget build(BuildContext context) {
    final sensorData = data;

    if (sensorData == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SolarColors.cardBgLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Cargando datos de sensores...',
            style: TextStyle(fontSize: 11, color: SolarColors.textLight),
          ),
        ),
      );
    }

    final pumpOn = sensorData.pumpActive == 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SolarColors.cardBgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SolarColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors, color: SolarColors.primary, size: 16),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Lecturas del ESP8266',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: SolarColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 12, thickness: 0.5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SensorItem(
                  icon: Icons.thermostat,
                  label: 'Temperatura',
                  value: _format(sensorData.temperature, '°C'),
                  color: SolarColors.temperature,
                ),
              ),
              Expanded(
                child: _SensorItem(
                  icon: Icons.water_drop,
                  label: 'Humedad Suelo',
                  value: _format(sensorData.soilHumidity, '%'),
                  color: SolarColors.humidity,
                ),
              ),
              Expanded(
                child: _SensorItem(
                  icon: Icons.air,
                  label: 'Humedad Aire',
                  value: _format(sensorData.airHumidity, '%'),
                  color: SolarColors.skyBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: pumpOn ? SolarColors.skyBlueLight : SolarColors.cardBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.water_damage,
                  size: 13,
                  color: pumpOn ? SolarColors.skyBlue : SolarColors.textLight,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Bomba de Riego: ${pumpOn ? "ACTIVA (Regando)" : "Inactiva"}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: pumpOn
                          ? SolarColors.primaryDark
                          : SolarColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SensorItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SensorItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 9, color: SolarColors.textLight),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: SolarColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
