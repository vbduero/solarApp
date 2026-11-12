// ============================================================
// Solar-Grow - Pantalla de Notificaciones
// ============================================================
import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// Pantalla de notificaciones. Todavía no existen, así que muestra un
/// estado vacío honesto.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SolarColors.background,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_none,
                size: 56,
                color: SolarColors.textLight,
              ),
              SizedBox(height: 16),
              Text(
                'Todavía no hay notificaciones.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: SolarColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
