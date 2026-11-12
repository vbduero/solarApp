# Tareas · Spec 003

Orden: primero las pruebas (deben fallar las que piden comportamiento nuevo), luego el código y al
final la revisión. Cada tarea cabe en un commit; el mensaje sugerido va entre paréntesis.

Los archivos se agregan uno por uno (`git add <archivo>`), porque
`frontend/lib/config/api_constants.dart` tiene un cambio local de la responsable y no entra en ningún
commit. No se toca `esp8266_maceta_inteligente/`.

- [x] T1 · `pruebas` · Backend:
  - escribir `backend/tests/test_controles_riego.py` (CA-1 a CA-6);
  - agregar a `backend/tests/test_hardware_service.py` las pruebas de `find_active_user_plant` e
    `is_device_plant`;
  - agregar a `backend/tests/test_seguridad_hardware.py` **solo** el fixture `autouse` de D8, sin
    cambiar ninguna aserción.

  Usar los nombres de la tabla «Pruebas por criterio» y fijar `ESP8266_PLANT_ID` en cada prueba. Sin
  ESP8266, serial ni red.
  - Anotar que las de CA-1, CA-2, CA-3, las de CA-4 de planta ajena, inexistente y 401, y las de CA-6
    de 404 por planta ajena o inexistente, «envía water» y 503 ya pasan, porque fijan el
    comportamiento actual.
  - Comprobar que fallan, por falta de la funcionalidad, las de planta borrada (CA-4, CA-6), las de
    409 (CA-5, CA-6) y las de servicio (por importación).

  (`test: agrega pruebas para detener el riego en el backend`)
- [x] T2 · `pruebas` · Frontend: escribir `frontend/test/plant_provider_stop_watering_test.dart`
  (provider: CA-8, CA-11) y `frontend/test/plant_detail_stop_watering_test.dart` (pantalla: CA-7 a
  CA-13, incluido el desborde a 320 y 360 px).
  - Usar un `PlantProvider` falso, `AuthProvider` sin sesión y tiempo falso de `flutter_test`. Cada
    prueba de widget termina con `pumpWidget(SizedBox())` y `pump(15 s)` (ver las notas del plan).
  - Comprobar que fallan.
  - Anotar para `frontend-dev` lo que aún no existe: `livePumpOn`, `stopWatering`, el contador de
    petición y «Detener riego».
  - No modificar `plant_detail_overflow_test.dart` ni `plant_detail_diagnoses_button_test.dart`.

  (`test: agrega pruebas para detener el riego desde la app`)
- [x] T3 · `backend-dev` · Agregar `find_active_user_plant` e `is_device_plant` a
  `backend/app/services/hardware_service.py` (D1). En `backend/app/routers/controls.py`, crear
  `_get_controllable_plant` con el orden de D2 y usarlo en `stop_watering` (D3).
  - Deben pasar las pruebas de `stop-water` y de servicio de T1.

  (`fix: solo detiene el riego en la planta del ESP8266 del usuario`)
- [x] T4 · `backend-dev` · Usar `_get_controllable_plant` también en `activate_watering` (D2). Deben
  pasar `test_controles_riego.py`, `test_seguridad_hardware.py` y toda la suite con
  `python -m pytest -q --cov --cov-config=.coveragerc`, sin bajar el umbral de cobertura.
  (`fix: solo inicia el riego en la planta del ESP8266 del usuario`)
- [x] T5 · `frontend-dev` · En `frontend/lib/providers/plant_provider.dart`:
  - `bool? livePumpOn(int plantId)`, el contador de petición en `loadSensorData` y la limpieza en
    `selectPlant` (D4);
  - `Future<bool> stopWatering(int plantId)` (D5).

  Debe pasar `plant_provider_stop_watering_test.dart`.

  (`feat: agrega al provider el estado en vivo de la bomba y la orden de detener el riego`)
- [x] T6 · `frontend-dev` · En `frontend/lib/screens/plant/plant_detail_screen.dart`: el estado y los
  flujos de D6 (`_waterAccepted`, `_isStopping`, `_waterRun`, `_handleStopWatering`) y el botón de D7,
  con los textos de D9.
  - Deben pasar `plant_detail_stop_watering_test.dart` y `flutter test` completo (incluidas las
    pruebas de desborde y del botón «Diagnósticos»).
  - `flutter analyze --no-fatal-infos --no-fatal-warnings` no debe dar avisos nuevos.

  (`feat: permite detener el riego desde el detalle de la planta`)
- [x] T7 · `revisor` · Ejecutar las verificaciones de `CLAUDE.md`.
  - Comparar `git diff --name-only main...HEAD` con la tabla «Archivos que se tocan».
  - Comprobar que `api_constants.dart` y `esp8266_maceta_inteligente/` no están en ningún commit y que
    en `test_seguridad_hardware.py` solo se agregó el fixture de D8.
  - Escribir el informe en `specs/003-detener-riego/revision.md`.
- [ ] T8 · Persona (Valentina Bermeo) · Comprobación manual con la placa (CA-14), con el backend
  levantado sobre PostgreSQL y el ESP8266 en `SERIAL_PORT`:
  1. Abrir el detalle de la planta del ESP8266, tocar «Regar» y, antes de 5 s, «Detener riego». La
     bomba debe apagarse físicamente en 3 s o menos, la consola del backend debe mostrar «BOMBA
     APAGADO» y la app «Riego detenido. El riego automático…»; no debe aparecer «¡Riego completado
     exitosamente!».
  2. Desconectar el cable USB, esperar a que la consola diga que no hay conexión y tocar «Regar» (o
     «Detener riego», si aún se ve). Debe salir el mensaje de 503 en un SnackBar.
  3. Abrir otra planta del mismo usuario y tocar «Regar». Debe salir «Esta planta no tiene el ESP8266
     conectado.» y la bomba no debe encenderse.
  4. Si se puede provocar un riego automático (tierra seca), comprobar que aparece «Detener riego» y
     que funciona.
  5. Revisar en Chrome y en el emulador que la fila de botones no se corta.

  Después: anotar en el plan las «Diferencias con lo planeado», responder las observaciones del
  revisor y abrir el pull request.
