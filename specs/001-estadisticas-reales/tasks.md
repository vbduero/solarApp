# Tareas · Spec 001

Orden: primero las pruebas (deben fallar), luego el código, luego la revisión. Cada tarea cabe en un
commit; el mensaje sugerido va entre paréntesis.

- [x] T1 · `pruebas` · Backend: escribir `backend/tests/test_sensors_history.py` (CA-10, CA-11,
  CA-12, CA-13) y `backend/tests/test_sensor_service.py` (CA-12, `pick_evenly`) con los nombres de
  la tabla «Pruebas por criterio». Comprobar que las de CA-11 y CA-12 fallan porque falta la
  funcionalidad (no por importación) y anotar que las de CA-10 y CA-13 ya pasan porque fijan el
  comportamiento actual. (`test: agrega pruebas del historial de sensores`)
- [x] T2 · `pruebas` · Frontend: escribir `frontend/test/sensor_history_provider_test.dart` (CA-1,
  CA-3, CA-5, CA-8) y `frontend/test/stats_screen_test.dart` (CA-1 a CA-7 y CA-9) con un
  `PlantProvider` falso y sin HTTP real. Comprobar que fallan y anotar para `frontend-dev` lo que
  aún no existe (`SensorReadingModel`, `loadSensorHistory`, `sensorHistory`, `isHistoryLoading`,
  `historyError`). (`test: agrega pruebas de la pantalla de estadísticas`)
- [x] T3 · `backend-dev` · Crear `backend/app/services/sensor_service.py` con `pick_evenly` y
  `get_history` (D6, D7) hasta que pase `test_sensor_service.py`.
  (`feat: agrega el servicio de historial de sensores con muestreo parejo`)
- [x] T4 · `backend-dev` · En `get_sensor_history` de `backend/app/routers/sensors.py`: límites
  `hours` 1–720 y `limit` 1–500 (D5) y usar el servicio. Deben pasar todas las pruebas de
  `test_sensors_history.py` y el resto de la suite con cobertura.
  (`feat: valida hours y limit y reparte el historial por todo el periodo`)
- [x] T5 · `frontend-dev` · Crear `frontend/lib/models/sensor_reading_model.dart` y agregar a
  `PlantProvider` el estado y `loadSensorHistory` (D2, D3, D4, D8, D9) hasta que pase
  `sensor_history_provider_test.dart`. (`feat: carga el historial de sensores en PlantProvider`)
- [x] T6 · `frontend-dev` · Reescribir `frontend/lib/screens/stats/stats_screen.dart`: datos del
  provider, tres gráficas reales, selector de periodo que recarga, selector de planta, estados de
  carga, vacío, error con «Reintentar» y sin plantas; quitar la gráfica de luz y el bloque «Sistema
  Solar» (D1, D10–D13). Deben pasar `stats_screen_test.dart`, `flutter test` completo y
  `flutter analyze` sin avisos nuevos.
  (`feat: muestra estadísticas reales de la planta y quita los valores de relleno`)
- [x] T7 · `revisor` · Ejecutar las verificaciones, comparar `git diff --name-only main...HEAD` con
  la tabla «Archivos que se tocan» y escribir el informe en
  `specs/001-estadisticas-reales/revision.md`.
- [ ] T8 · Persona (Valentina Bermeo) · Comprobación manual con el backend levantado y lecturas en
  la base: abrir Estadísticas desde la barra inferior y desde el menú, cambiar entre 6h/24h/7d/30d,
  cambiar de planta, y apagar el backend para ver el error y «Reintentar». Anotar en el plan las
  «Diferencias con lo planeado», responder las observaciones del revisor y abrir el pull request.
