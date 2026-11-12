// ============================================================
// Solar-Grow - Textos del modo demo y de los datos que faltan
// ============================================================

/// Textos de UI para avisar de datos de ejemplo o sin conexión.
class DemoMessages {
  DemoMessages._();

  static const String homeBanner =
      'Modo demo: no se pudo conectar con el servidor. Las plantas y tareas que ves son de ejemplo.';
  static const String retry = 'Reintentar';
  static const String plantBanner =
      'Modo demo: esta planta es de ejemplo y no tiene lecturas reales.';
  static const String sensorsUnavailable =
      'Sin conexión con el servidor: no se pueden mostrar las lecturas.';
  static const String notAvailable = 'No disponible en modo demo.';
  static const String noData = 'Sin datos';
  static const String noDate = 'Sin fecha';
  static const String deleteFailed =
      'No se pudo eliminar la planta. Intenta de nuevo.';
}
