// ============================================================
// Solar-Grow - Tab de Tareas
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/task_provider.dart';
import '../../widgets/task_card.dart';

/// Tab que muestra las tareas de cuidado organizadas por tipo
class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  bool _showToday = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<TaskProvider>(
      builder: (context, taskProvider, child) {
        if (taskProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: SolarColors.primary),
          );
        }

        final tasks = _showToday
            ? taskProvider.todayTasks
            : taskProvider.upcomingTasks;

        final tasksByType = <String, List<dynamic>>{};
        for (final task in tasks) {
          tasksByType.putIfAbsent(task.taskType, () => []);
          tasksByType[task.taskType]!.add(task);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tabs Hoy / Próximamente
              _buildSubTabs(),
              const SizedBox(height: 16),
              // Tareas por tipo
              if (tasksByType.isEmpty)
                _buildEmptyState()
              else
                ...tasksByType.entries.map(
                  (entry) =>
                      _buildTaskSection(entry.key, entry.value, taskProvider),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SolarColors.cardBgLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showToday = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _showToday ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: _showToday
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Hoy',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _showToday
                          ? SolarColors.textPrimary
                          : SolarColors.textLight,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showToday = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_showToday ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: !_showToday
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    'Próximamente',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: !_showToday
                          ? SolarColors.textPrimary
                          : SolarColors.textLight,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSection(
    String taskType,
    List<dynamic> tasks,
    TaskProvider provider,
  ) {
    final icon = _getTaskIcon(taskType);
    final count = tasks.where((t) => !t.isCompleted).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de sección
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                taskType,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: SolarColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: SolarColors.error,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Separador punteado
          Row(
            children: List.generate(
              40,
              (index) => Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 0.5),
                  height: 1,
                  color: index % 2 == 0
                      ? SolarColors.textLight.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Lista horizontal de tareas
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskCard(
                  task: task,
                  onComplete: () => provider.completeTask(task.id),
                  onTap: () {
                    // Navegar a la planta asociada
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 16),
            Text(
              _showToday
                  ? '¡No tienes tareas pendientes hoy!'
                  : 'No hay tareas programadas próximamente',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: SolarColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTaskIcon(String taskType) {
    switch (taskType) {
      case 'Regar':
        return '💧';
      case 'Fertilizar':
        return '🧪';
      case 'Trasplantar':
        return '🌱';
      case 'Podar':
        return '✂️';
      default:
        return '🔍';
    }
  }
}
