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

  /// Abre el diálogo de Diagnóstico IA en Vivo completo
  void _abrirDiagnosticoIA(BuildContext parentContext) {
    // Estado mutable del diálogo
    bool isAnalyzing = true;
    String diagnosticoTexto = '';
    String? errorTexto;
    String? urlImagenAnalizada;
    // Timestamp para cache-busting
    int imageTimestamp = DateTime.now().millisecondsSinceEpoch;
    // Guard para evitar que StatefulBuilder lance el Future múltiples veces
    bool analysisStarted = false;

    // URL base: usa ApiService.baseUrl (funciona en web y en desktop)
    final baseUrl = ApiService.baseUrl;

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Determinar si es pantalla ancha para diseño side-by-side
            final double screenWidth = MediaQuery.of(dialogContext).size.width;
            final bool isWide = screenWidth > 750;

            // Lanzar análisis IA solo la primera vez
            if (!analysisStarted) {
              analysisStarted = true;
              ApiService.get('/api/hardware/diagnostico-ia').then((data) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    diagnosticoTexto =
                        (data != null && data['diagnostico'] != null)
                            ? data['diagnostico']
                            : 'Sin respuesta del modelo de IA.';
                    urlImagenAnalizada =
                        (data != null && data['url_imagen'] != null)
                            ? data['url_imagen']
                            : '/static/ultimo_diagnostico.jpg';
                    isAnalyzing = false;
                    imageTimestamp = DateTime.now().millisecondsSinceEpoch;
                  });
                }
              }).catchError((error) {
                if (dialogContext.mounted) {
                  setDialogState(() {
                    errorTexto = error.toString();
                    isAnalyzing = false;
                  });
                }
              });
            }

            final imageUrl = urlImagenAnalizada != null
                ? '$baseUrl$urlImagenAnalizada?t=$imageTimestamp'
                : null;

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              title: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: SolarColors.primary, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Diagnóstico IA en Vivo',
                      style: TextStyle(
                        color: SolarColors.primaryDark,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isAnalyzing)
                    IconButton(
                      icon: const Icon(Icons.close, color: SolarColors.textLight),
                      onPressed: () => Navigator.pop(dialogContext),
                    )
                ],
              ),
              content: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: isWide ? 850 : 380,
                child: isAnalyzing
                    ? _buildLoader()
                    : (errorTexto != null
                        ? _buildError(errorTexto!)
                        : _buildResults(ctx, isWide, imageUrl, diagnosticoTexto)),
              ),
              actions: [
                // Botón: Nueva captura + reanálisis
                if (!isAnalyzing)
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Nueva Captura'),
                    onPressed: () {
                      setDialogState(() {
                        isAnalyzing = true;
                        diagnosticoTexto = '';
                        errorTexto = null;
                        analysisStarted = false;
                        imageTimestamp = DateTime.now().millisecondsSinceEpoch;
                      });
                    },
                  ),
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
  }

  /// Construye el cargador de carga premium con pasos visuales
  Widget _buildLoader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 90,
                height: 90,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(SolarColors.primary),
                  backgroundColor: SolarColors.primaryLight.withOpacity(0.15),
                ),
              ),
              const Icon(
                Icons.photo_camera_outlined,
                color: SolarColors.primary,
                size: 36,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Conectando con la cámara del computador...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: SolarColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Capturando imagen en tiempo real y consultando el diagnóstico fitosanitario con Google Gemini AI.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: SolarColors.textLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStepIndicator(true, 'Cámara'),
              _buildStepLine(),
              _buildStepIndicator(true, 'Sensores'),
              _buildStepLine(),
              _buildStepIndicator(true, 'Gemini AI', isPulse: true),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(bool active, String label, {bool isPulse = false}) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: active ? SolarColors.primary : Colors.grey.shade300,
            shape: BoxShape.circle,
            boxShadow: isPulse && active
                ? [
                    BoxShadow(
                      color: SolarColors.primary.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    )
                  ]
                : [],
          ),
          child: const Center(
            child: Icon(
              Icons.check,
              color: Colors.white,
              size: 12,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: active ? SolarColors.primary : Colors.grey,
          ),
        )
      ],
    );
  }

  Widget _buildStepLine() {
    return Container(
      width: 35,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: SolarColors.primary.withOpacity(0.3),
    );
  }

  /// Construye la tarjeta de error
  Widget _buildError(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text(
                'Error de Diagnóstico',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            error,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.red.shade900,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la vista de resultados estructurada
  Widget _buildResults(BuildContext context, bool isWide, String? imageUrl, String diagnosticoTexto) {
    final Map<String, String> parsed = _parseDiagnostico(diagnosticoTexto);

    final Widget imageWidget = imageUrl != null
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    height: isWide ? 260 : 190,
                    width: double.infinity,
                    headers: const {'Cache-Control': 'no-cache'},
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        height: isWide ? 260 : 190,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (ctx, error, stack) => Container(
                      height: isWide ? 260 : 190,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Cámara sin señal',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'CAPTURADO EN VIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Icon(Icons.circle, color: Colors.red, size: 6),
                      ],
                    ),
                  )
                ],
              ),
            ),
          )
        : const SizedBox();

    final Widget diagnosticDetails = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ESTADO GENERAL
        if (parsed.containsKey('ESTADO GENERAL') && parsed['ESTADO GENERAL']!.isNotEmpty) ...[
          _buildDetailCard(
            title: 'Estado General del Cultivo',
            content: parsed['ESTADO GENERAL']!,
            icon: Icons.monitor_heart,
            color: SolarColors.primary,
            bgColor: SolarColors.cardBgLight,
          ),
          const SizedBox(height: 10),
        ],

        // PLAGAS & ENFERMEDADES
        if ((parsed.containsKey('PLAGAS DETECTADAS') && parsed['PLAGAS DETECTADAS']!.isNotEmpty) ||
            (parsed.containsKey('ENFERMEDADES') && parsed['ENFERMEDADES']!.isNotEmpty)) ...[
          _buildDetailCard(
            title: 'Amenazas (Plagas y Enfermedades)',
            content: '• Plagas: ${parsed['PLAGAS DETECTADAS'] ?? 'Ninguna detectada'}\n'
                '• Enfermedades: ${parsed['ENFERMEDADES'] ?? 'Ninguna detectada'}',
            icon: Icons.bug_report,
            color: SolarColors.error,
            bgColor: Colors.red.shade50,
          ),
          const SizedBox(height: 10),
        ],

        // HOJAS Y RIEGO
        if ((parsed.containsKey('SALUD FOLIAR') && parsed['SALUD FOLIAR']!.isNotEmpty) ||
            (parsed.containsKey('ESTRÉS HÍDRICO') && parsed['ESTRÉS HÍDRICO']!.isNotEmpty)) ...[
          _buildDetailCard(
            title: 'Hojas y Riego',
            content: '• Salud Foliar: ${parsed['SALUD FOLIAR'] ?? 'N/A'}\n'
                '• Estrés Hídrico: ${parsed['ESTRÉS HÍDRICO'] ?? 'N/A'}',
            icon: Icons.opacity,
            color: SolarColors.humidity,
            bgColor: Colors.blue.shade50,
          ),
          const SizedBox(height: 10),
        ],

        // RECOMENDACIONES
        if (parsed.containsKey('RECOMENDACIONES') && parsed['RECOMENDACIONES']!.isNotEmpty) ...[
          _buildDetailCard(
            title: 'Recomendaciones de Gemini AI',
            content: parsed['RECOMENDACIONES']!,
            icon: Icons.tips_and_updates,
            color: SolarColors.secondaryDark,
            bgColor: SolarColors.secondaryLight.withOpacity(0.15),
          ),
          const SizedBox(height: 10),
        ],

        // Fallback
        if (parsed.isEmpty || (parsed.containsKey('OTROS') && parsed['OTROS']!.isNotEmpty && parsed.length == 1)) ...[
          _buildDetailCard(
            title: 'Análisis Completo',
            content: diagnosticoTexto,
            icon: Icons.smart_toy,
            color: SolarColors.primary,
            bgColor: SolarColors.cardBgLight,
          ),
        ]
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Lado Izquierdo: Imagen + Sensores
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  imageWidget,
                  const SizedBox(height: 12),
                  _buildSensorsInfoBox(context),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Lado Derecho: Recomendación IA
          Expanded(
            flex: 6,
            child: SizedBox(
              height: 420,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: diagnosticDetails,
              ),
            ),
          )
        ],
      );
    } else {
      return SizedBox(
        height: 500,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              imageWidget,
              const SizedBox(height: 12),
              _buildSensorsInfoBox(context),
              const SizedBox(height: 12),
              diagnosticDetails,
            ],
          ),
        ),
      );
    }
  }

  /// Construye tarjetas individuales con estilo
  Widget _buildDetailCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: SolarColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  /// Caja de información de sensores IoT del ESP8266
  Widget _buildSensorsInfoBox(BuildContext context) {
    final plantProvider = Provider.of<PlantProvider>(context, listen: false);
    final sensorData = plantProvider.currentSensorData;

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
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SolarColors.cardBgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SolarColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors, color: SolarColors.primary, size: 16),
              SizedBox(width: 6),
              Text(
                'Lecturas del ESP8266',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: SolarColors.primaryDark,
                ),
              ),
            ],
          ),
          const Divider(height: 12, thickness: 0.5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSensorItem(
                icon: Icons.thermostat,
                label: 'Temperatura',
                value: '${sensorData.temperature?.toStringAsFixed(1) ?? "25.0"}°C',
                color: SolarColors.temperature,
              ),
              _buildSensorItem(
                icon: Icons.water_drop,
                label: 'Humedad Suelo',
                value: '${sensorData.soilHumidity?.toStringAsFixed(1) ?? "50.0"}%',
                color: SolarColors.humidity,
              ),
              _buildSensorItem(
                icon: Icons.air,
                label: 'Humedad Aire',
                value: '${sensorData.airHumidity?.toStringAsFixed(1) ?? "50.0"}%',
                color: SolarColors.skyBlue,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: sensorData.pumpActive == 1
                  ? Colors.blue.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.water_damage,
                  size: 13,
                  color: sensorData.pumpActive == 1 ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  'Bomba de Riego: ${sensorData.pumpActive == 1 ? "ACTIVA (Regando)" : "Inactiva"}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: sensorData.pumpActive == 1
                        ? Colors.blue.shade700
                        : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSensorItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: SolarColors.textLight),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: SolarColors.textPrimary,
          ),
        ),
      ],
    );
  }

  /// Parsea la respuesta estructurada de Gemini
  Map<String, String> _parseDiagnostico(String text) {
    final Map<String, String> sections = {};
    final List<String> lines = text.split('\n');
    String currentSection = 'OTROS';
    StringBuffer currentContent = StringBuffer();

    for (var line in lines) {
      final lineTrimmed = line.trim();
      if (lineTrimmed.startsWith('ESTADO GENERAL:')) {
        sections[currentSection] = currentContent.toString().trim();
        currentSection = 'ESTADO GENERAL';
        currentContent = StringBuffer(lineTrimmed.replaceFirst('ESTADO GENERAL:', '').trim());
      } else if (lineTrimmed.startsWith('PLAGAS DETECTADAS:')) {
        sections[currentSection] = currentContent.toString().trim();
        currentSection = 'PLAGAS DETECTADAS';
        currentContent = StringBuffer(lineTrimmed.replaceFirst('PLAGAS DETECTADAS:', '').trim());
      } else if (lineTrimmed.startsWith('ENFERMEDADES:')) {
        sections[currentSection] = currentContent.toString().trim();
        currentSection = 'ENFERMEDADES';
        currentContent = StringBuffer(lineTrimmed.replaceFirst('ENFERMEDADES:', '').trim());
      } else if (lineTrimmed.startsWith('SALUD FOLIAR:')) {
        sections[currentSection] = currentContent.toString().trim();
        currentSection = 'SALUD FOLIAR';
        currentContent = StringBuffer(lineTrimmed.replaceFirst('SALUD FOLIAR:', '').trim());
      } else if (lineTrimmed.startsWith('ESTRÉS HÍDRICO:')) {
        sections[currentSection] = currentContent.toString().trim();
        currentSection = 'ESTRÉS HÍDRICO';
        currentContent = StringBuffer(lineTrimmed.replaceFirst('ESTRÉS HÍDRICO:', '').trim());
      } else if (lineTrimmed.startsWith('RECOMENDACIONES:')) {
        sections[currentSection] = currentContent.toString().trim();
        currentSection = 'RECOMENDACIONES';
        currentContent = StringBuffer(lineTrimmed.replaceFirst('RECOMENDACIONES:', '').trim());
      } else {
        currentContent.writeln(line);
      }
    }
    sections[currentSection] = currentContent.toString().trim();
    return sections;
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
                _abrirDiagnosticoIA(context);
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
