// ============================================================
// Solar-Grow - Widget de Tarjeta de Tarea
// ============================================================
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/task_model.dart';

/// Tarjeta que muestra una tarea de cuidado de planta
class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onComplete;
  final VoidCallback? onTap;

  const TaskCard({super.key, required this.task, this.onComplete, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: task.isOverdue
              ? Border.all(
                  color: SolarColors.error.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Imagen/ícono de la planta
            Container(
              width: double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: SolarColors.cardBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  task.taskIcon,
                  style: const TextStyle(fontSize: 30),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Nombre de la planta
            Text(
              task.plantName ?? 'Planta',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SolarColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // Etiqueta de atrasada
            if (task.isOverdue)
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: SolarColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Atrasado: ${task.daysOverdue} día${task.daysOverdue > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: SolarColors.error,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 4),
            // Ubicación y checkbox
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.plantLocation ?? '',
                    style: const TextStyle(
                      fontSize: 10,
                      color: SolarColors.textLight,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onComplete,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: task.isCompleted
                          ? SolarColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: task.isCompleted
                            ? SolarColors.primary
                            : SolarColors.textLight,
                        width: 1.5,
                      ),
                    ),
                    child: task.isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
