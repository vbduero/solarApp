// ============================================================
// Solar-Grow - Pantalla Principal (Home)
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plant_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/weather_bar.dart';
import 'my_plants_tab.dart';
import 'tasks_tab.dart';

/// Pantalla principal con tabs Mis Plantas / Tareas y bottom navigation
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentNavIndex = 3; // Mi Jardín por defecto

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _loadData();
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;

    Future.microtask(() {
      if (!mounted) return;
      context.read<PlantProvider>().loadPlants();
      context.read<TaskProvider>().loadTodayTasks();
      context.read<TaskProvider>().loadUpcomingTasks();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Llama al backend para obtener el diagnóstico real de Gemini AI
  Future<String> _realizarDiagnosticoIA() async {
    try {
      final data = await ApiService.get('/api/hardware/diagnostico-ia');
      if (data != null && data['diagnostico'] != null) {
        return data['diagnostico'];
      }
      return 'No se recibió respuesta del modelo de IA.';
    } catch (e) {
      throw Exception('Error al conectar con el servicio de IA: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final taskProvider = context.watch<TaskProvider>();

    return Scaffold(
      backgroundColor: SolarColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header con menú hamburguesa, clima y perfil
            _buildHeader(user),
            // Info del clima
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: WeatherBar(
                city: user?.city ?? 'Neiva',
                weather: 'Parcialmente nublado',
                temperature: 26,
              ),
            ),
            const SizedBox(height: 8),
            // Título Mis Plantas | Tareas
            _buildTabBar(taskProvider),
            // Contenido según tab
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [MyPlantsTab(), TasksTab()],
              ),
            ),
          ],
        ),
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNav(),
      // Botón flotante opcional
      floatingActionButton: _tabController.index == 0 && _currentNavIndex == 3
          ? FloatingActionButton(
              backgroundColor: SolarColors.primary,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(context).pushNamed('/add-plant');
              },
              child: const Icon(Icons.add),
            )
          : null,
      // Drawer menu
      drawer: _buildDrawer(user),
    );
  }

  Widget _buildHeader(user) {
    // Current avatar setup
    final currentAvatar = user?.avatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          // Menú hamburguesa
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(
                Icons.menu,
                color: SolarColors.textPrimary,
                size: 26,
              ),
            ),
          ),
          const Spacer(),
          // Avatar del usuario
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/edit-profile');
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black12,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12, width: 2),
              ),
              child: ClipOval(
                child: currentAvatar != null
                    ? Image.network(
                        currentAvatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: Colors.black54,
                          size: 26,
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.black54, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(TaskProvider taskProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Título principal
          const Text(
            'Mis Plantas',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: SolarColors.textPrimary,
            ),
          ),
          Container(
            width: 2,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: SolarColors.textLight.withValues(alpha: 0.3),
          ),
          GestureDetector(
            onTap: () => _tabController.animateTo(1),
            child: Row(
              children: [
                Text(
                  'Tareas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _tabController.index == 1
                        ? SolarColors.textPrimary
                        : SolarColors.textLight,
                  ),
                ),
                if (taskProvider.pendingCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: SolarColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${taskProvider.pendingCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
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
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() => _currentNavIndex = index);
          switch (index) {
            case 0:
              Navigator.of(context).pushNamed('/recommendations');
              break;
            case 1:
              Navigator.of(context).pushNamed('/notifications');
              break;
            case 2:
              Navigator.of(context).pushNamed('/stats');
              break;
            case 3:
              // Ya estamos en Mi Jardín
              _tabController.animateTo(0);
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Recomendaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Notificaciones',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Estadísticas',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Mi Jardín',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(user) {
    return Drawer(
      child: Container(
        color: SolarColors.background,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [SolarColors.primaryDark, SolarColors.primary],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white24,
                    backgroundImage: user?.avatarUrl != null
                        ? NetworkImage(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? const Text('🌱', style: TextStyle(fontSize: 30))
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    user?.fullName ?? 'Agricultor Solar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home, color: SolarColors.primary),
              title: const Text('Mi Jardín'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.analytics_outlined,
                color: SolarColors.skyBlue,
              ),
              title: const Text('Estadísticas'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/stats');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.solar_power,
                color: SolarColors.secondary,
              ),
              title: const Text('Panel Solar'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: SolarColors.primary,
              ),
              title: const Text('Diagnóstico IA / Cámara En Vivo'),
              onTap: () {
                Navigator.pop(context); // Cerrar menú

                // Estados del diálogo
                bool isAnalyzing = true;
                String diagnosticoTexto = '';
                String? errorTexto;

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (dialogContext) {
                    return StatefulBuilder(
                      builder: (context, setState) {
                        // Disparar el análisis solo una vez
                        if (isAnalyzing &&
                            diagnosticoTexto.isEmpty &&
                            errorTexto == null) {
                          _realizarDiagnosticoIA()
                              .then((resultado) {
                                if (context.mounted) {
                                  setState(() {
                                    diagnosticoTexto = resultado;
                                    isAnalyzing = false;
                                  });
                                }
                              })
                              .catchError((error) {
                                if (context.mounted) {
                                  setState(() {
                                    errorTexto = error.toString();
                                    isAnalyzing = false;
                                  });
                                }
                              });
                        }

                        return AlertDialog(
                          title: Row(
                            children: const [
                              Icon(
                                Icons.auto_awesome,
                                color: SolarColors.primaryDark,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Diagnóstico IA en Vivo',
                                  style: TextStyle(
                                    color: SolarColors.primaryDark,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          content: SizedBox(
                            width: 320,
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Imagen de la cámara
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      'http://localhost:8000/api/hardware/vista-cultivo',
                                      fit: BoxFit.cover,
                                      height: 180,
                                      width: 300,
                                      loadingBuilder:
                                          (context, child, progress) {
                                            if (progress == null) return child;
                                            return const SizedBox(
                                              height: 180,
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            );
                                          },
                                      errorBuilder:
                                          (
                                            context,
                                            error,
                                            stackTrace,
                                          ) => const SizedBox(
                                            height: 180,
                                            child: Center(
                                              child: Text(
                                                '📷 No se pudo conectar con la cámara.',
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Estado: Analizando
                                  if (isAnalyzing) ...[
                                    const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      '🧠 Google Gemini está analizando la imagen en busca de plagas, enfermedades y estrés hídrico...',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.blueGrey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ]
                                  // Estado: Error
                                  else if (errorTexto != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.red.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text(
                                            '❌ Error en el diagnóstico:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            errorTexto!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ]
                                  // Estado: Resultados reales de la IA
                                  else ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.green.shade200,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(
                                                Icons.smart_toy,
                                                color: Colors.green,
                                                size: 20,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Gemini AI - Diagnóstico:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            diagnosticoTexto,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cerrar'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.person_outline,
                color: SolarColors.textLight,
              ),
              title: const Text('Editar Perfil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/edit-profile');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: SolarColors.textLight,
              ),
              title: const Text('Configuración'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.help_outline,
                color: SolarColors.textLight,
              ),
              title: const Text('Ayuda'),
              onTap: () => Navigator.pop(context),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: SolarColors.error),
              title: const Text('Cerrar Sesión'),
              onTap: () {
                context.read<AuthProvider>().logout();
                Navigator.of(context).pushReplacementNamed('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}
