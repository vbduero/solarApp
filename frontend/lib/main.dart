// ============================================================
// Solar-Grow - Punto de Entrada Principal de la Aplicación
// ============================================================
// Estación ambiental inteligente con energía solar e IA
// Frontend: Flutter | Backend: Python FastAPI | DB: PostgreSQL
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

// Configuración
import 'config/theme.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/plant_provider.dart';
import 'providers/task_provider.dart';
import 'services/api_service.dart';

// Pantallas
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/plant/plant_detail_screen.dart';
import 'screens/plant/plant_info_screen.dart';
import 'screens/plant/add_plant_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/recommendations/recommendations_screen.dart';
import 'screens/profile/edit_profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar token inmediatamente para evitar 401 en reinicio rápido (hot restart)
  try {
    await ApiService.loadToken();
  } catch (e) {
    debugPrint('Error al pre-cargar token: $e');
  }

  // Configurar orientación vertical (solo afecta en móvil)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const SolarGrowApp());
}

/// Aplicación principal Solar-Grow
class SolarGrowApp extends StatelessWidget {
  const SolarGrowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlantProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: MaterialApp(
        title: 'Solar-Grow',
        debugShowCheckedModeBanner: false,
        theme: SolarTheme.lightTheme,

        // Pantalla inicial
        initialRoute: '/',

        // Rutas de la aplicación
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/plant-detail': (context) => const PlantDetailScreen(),
          '/plant-info': (context) => const PlantInfoScreen(),
          '/add-plant': (context) => const AddPlantScreen(),
          '/stats': (context) => const StatsScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/recommendations': (context) => const RecommendationsScreen(),
          '/edit-profile': (context) => const EditProfileScreen(),
        },
      ),
    );
  }
}
