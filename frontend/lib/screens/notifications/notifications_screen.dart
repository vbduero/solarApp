// ============================================================
// Solar-Grow - Pantalla de Notificaciones
// ============================================================
import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Pantalla de notificaciones del sistema
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Datos de demo
    final notifications = [
      _NotifItem(
        icon: '💧',
        title: 'Riego necesario',
        message:
            'Tu Echeveria necesita agua. La humedad del suelo está al 27%.',
        time: 'Hace 30 min',
        priority: 'alta',
      ),
      _NotifItem(
        icon: '🌡️',
        title: 'Temperatura elevada',
        message: 'La temperatura ha alcanzado 32°C. Considera mover la planta.',
        time: 'Hace 1 hora',
        priority: 'media',
      ),
      _NotifItem(
        icon: '⚡',
        title: 'Batería cargada',
        message: 'La batería del sistema solar está al 100%.',
        time: 'Hace 2 horas',
        priority: 'baja',
      ),
      _NotifItem(
        icon: '📸',
        title: 'Diagnóstico completado',
        message:
            'La IA analizó tu Áloe de arena. Estado: Bueno (87% confianza).',
        time: 'Hace 3 horas',
        priority: 'baja',
      ),
      _NotifItem(
        icon: '🧪',
        title: 'Recordatorio de fertilización',
        message:
            'Es hora de fertilizar tu Echeveria. Última vez: hace 2 semanas.',
        time: 'Ayer',
        priority: 'media',
      ),
      _NotifItem(
        icon: '☀️',
        title: 'Tracking solar optimizado',
        message: 'El panel solar ajustó su posición para máxima captación.',
        time: 'Ayer',
        priority: 'baja',
      ),
    ];

    return Scaffold(
      backgroundColor: SolarColors.background,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Marcar todas',
              style: TextStyle(color: SolarColors.primary, fontSize: 13),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final notif = notifications[index];
          return _buildNotificationCard(notif);
        },
      ),
    );
  }

  Widget _buildNotificationCard(_NotifItem notif) {
    Color priorityColor;
    switch (notif.priority) {
      case 'alta':
        priorityColor = SolarColors.error;
        break;
      case 'media':
        priorityColor = SolarColors.warning;
        break;
      default:
        priorityColor = SolarColors.primary;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: priorityColor, width: 3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(notif.icon, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: SolarColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      notif.time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: SolarColors.textLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notif.message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: SolarColors.textSecondary,
                    height: 1.4,
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

class _NotifItem {
  final String icon;
  final String title;
  final String message;
  final String time;
  final String priority;

  _NotifItem({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.priority,
  });
}
