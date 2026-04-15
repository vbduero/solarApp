// ============================================================
// Solar-Grow - Widget de Barra de Clima
// ============================================================
import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Barra superior que muestra información del clima
class WeatherBar extends StatelessWidget {
  final String city;
  final String weather;
  final int temperature;

  const WeatherBar({
    super.key,
    this.city = 'Neiva',
    this.weather = 'Parcialmente nublado',
    this.temperature = 26,
  });

  IconData get _weatherIcon {
    if (weather.contains('sol')) return Icons.wb_sunny;
    if (weather.contains('nublado')) return Icons.cloud;
    if (weather.contains('lluvia')) return Icons.water_drop;
    return Icons.cloud;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(_weatherIcon, color: SolarColors.textLight, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$city, $weather $temperature°C',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: SolarColors.textLight,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
