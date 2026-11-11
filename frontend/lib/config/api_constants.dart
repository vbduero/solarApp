// ============================================================
// Solar-Grow - Constantes de la API
// ============================================================

/// Constantes para la configuración de la API del backend
class ApiConstants {
  // URL base del servidor (cambiar en producción)
  static const String baseUrl = 'http://10.0.2.2:8000'; // Emulador Android
  static const String webBaseUrl = 'http://localhost:8000'; // Web

  // Endpoints de autenticación
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String me = '/api/auth/me';

  // Endpoints de plantas
  static const String plants = '/api/plants/';
  static const String plantLocations = '/api/plants/locations';

  // Endpoints de sensores
  static const String sensorsLatest = '/api/sensors/latest';
  static const String sensorsHistory = '/api/sensors/history';
  static const String sensorsCreate = '/api/sensors/';

  // Endpoints de tareas
  static const String tasks = '/api/tasks/';

  // Endpoints de control
  static const String controlWater = '/api/controls/water';
  static const String controlStopWater = '/api/controls/stop-water';
  static const String controlStatus = '/api/controls/status';

  // Endpoints de IA
  static const String aiRecommendations = '/api/ai/recommendations';
  static const String aiDiagnosis = '/api/ai/diagnosis';
  static const String aiRequestDiagnosis = '/api/ai/request-diagnosis';
}
