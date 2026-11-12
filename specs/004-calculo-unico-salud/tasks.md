# Tareas · Spec 004

Orden: primero las pruebas (deben fallar las que piden comportamiento nuevo), luego el código y al
final la revisión. Cada tarea cabe en un commit; el mensaje sugerido va entre paréntesis.

Los archivos se agregan uno por uno (`git add <archivo>`), porque
`frontend/lib/config/api_constants.dart` tiene un cambio local de la responsable y no entra en ningún
commit. No se tocan `esp8266_maceta_inteligente/`, `backend/seed_data.py` ni ninguna prueba
existente (D10 del plan).

- [x] T1 · `pruebas` · Backend: escribir `backend/tests/test_health_service.py` (regla pura) y
  `backend/tests/test_salud_sensores.py` (`latest` y `clima-actual`, CA-1 a CA-8).
  - Usar los nombres de la tabla «Pruebas por criterio» y las notas del plan. Sin ESP8266, serial,
    webcam ni red; `ESP8266_PLANT_ID` fijado en cada prueba.
  - Anotar que las de CA-6 (404 y 401) ya pasan, porque fijan el comportamiento actual.
  - Comprobar que las demás fallan por falta de la funcionalidad. `test_health_service.py` falla al
    importar el servicio, que aún no existe.

  (`test: agrega pruebas del cálculo único de salud en el backend`)
- [x] T2 · `pruebas` · Frontend: escribir `frontend/test/sensor_health_model_test.dart`,
  `frontend/test/plant_provider_health_test.dart` y `frontend/test/plant_detail_health_test.dart`
  (CA-3 a CA-5 y CA-8 a CA-12).
  - `PlantProvider` falso o `MockClient`, `AuthProvider` sin sesión y claves `boca-feliz`,
    `boca-triste` y `boca-critica`.
  - Cada prueba de widget termina con `pumpWidget(SizedBox())` y `pump(10 s)`, sin `pumpAndSettle`.
  - Comprobar que fallan.
  - Anotar para `frontend-dev` lo que aún no existe: `healthLabel`, `parseHealthStatus`,
    `healthScore` opcional, las claves de la boca y la etiqueta.

  (`test: agrega pruebas del estado según sensores en la app`)
- [x] T3 · `backend-dev` · Crear `backend/app/services/health_service.py` (D1). En
  `backend/app/routers/sensors.py`, borrar `calculate_health` y usar el servicio con y sin lecturas
  (D2). Ajustar `SensorLatestResponse` (D3).
  - Deben pasar `test_health_service.py` y las pruebas de `latest` de `test_salud_sensores.py`.

  (`fix: calcula la salud según sensores con una sola regla en el backend`)
- [x] T4 · `backend-dev` · En `backend/app/routers/hardware.py`, añadir `health_status` y
  `health_score` a `clima-actual` con `calculate_live_health` y `get_device_plant_for_user` (D4).
  - Deben pasar `test_salud_sensores.py`, `test_seguridad_hardware.py` y toda la suite con
    `python -m pytest -q --cov --cov-config=.coveragerc`, sin bajar el umbral de cobertura.

  (`feat: devuelve el estado según sensores en clima-actual`)
- [x] T5 · `frontend-dev` · En `frontend/lib/models/sensor_data_model.dart` (D5) y en la rama en vivo
  de `frontend/lib/providers/plant_provider.dart` (D6): quitar el cálculo propio y la sustitución
  del suelo por el aire, y leer el estado del backend. No tocar `livePumpOn` ni el contador de
  petición.
  - Deben pasar `sensor_health_model_test.dart`, `plant_provider_health_test.dart` y
    `plant_provider_stop_watering_test.dart`.

  (`fix: la app usa el estado de salud que calcula el backend`)
- [x] T6 · `frontend-dev` · En `frontend/lib/widgets/animated_plant.dart`, hacer que la cara
  dependa del estado, quitar `healthScore` y añadir las claves de la boca (D7). En
  `frontend/lib/screens/plant/plant_detail_screen.dart`, añadir la etiqueta «Según sensores: …»,
  quitar el puntaje de la llamada y poner el clima fijo (D8).
  - Deben pasar `plant_detail_health_test.dart` y `flutter test` completo, incluidas, sin
    cambios, las pruebas de la spec 002 y la 003.
  - `flutter analyze --no-fatal-infos --no-fatal-warnings` no debe dar avisos nuevos.

  (`feat: muestra el estado según sensores en el detalle de la planta`)
- [x] T7 · `revisor` · Ejecutar las verificaciones de `CLAUDE.md`.
  - Comparar `git diff --name-only main...HEAD` con la tabla «Archivos que se tocan».
  - Comprobar que:
    - no se modificó ninguna prueba existente;
    - `api_constants.dart`, `seed_data.py` y `esp8266_maceta_inteligente/` no están en ningún commit;
    - no queda ninguna regla de salud en `sensors.py` ni en la app (buscar `needs_water`, `healthy`,
      `isHealthy` y `>= 60`).
  - Escribir el informe en `specs/004-calculo-unico-salud/revision.md`.
- [ ] T8 · Persona (Valentina Bermeo) · Comprobación manual con la placa (CA-13), con el backend sobre
  PostgreSQL y el ESP8266 en `SERIAL_PORT`:
  1. Abrir el detalle de la planta del ESP8266 con el sensor de humedad al aire. Debe verse «Según
     sensores: Necesita agua», la cara triste y «Regar» en rojo.
  2. Desconectar el USB y, antes de que pase un minuto, comprobar que el detalle muestra lo mismo.
  3. Meter el sensor en tierra húmeda y comprobar que pasa a «Según sensores: Sana» con la cara
     feliz.
  4. Abrir una planta sin lecturas y comprobar «Según sensores: sin lecturas», sin cara triste.
  5. Revisar en Chrome y en el emulador que la etiqueta y la fila de botones no se cortan.

  Después: anotar en el plan las «Diferencias con lo planeado», responder las observaciones del
  revisor y abrir el pull request.
