# Tareas · Spec 002

Orden: primero las pruebas (deben fallar las que piden comportamiento nuevo), luego el código, luego
la revisión. Cada tarea cabe en un commit; el mensaje sugerido va entre paréntesis. Agregar los
archivos uno por uno (`git add <archivo>`): `frontend/lib/config/api_constants.dart` tiene un cambio
local de la responsable y no entra en ningún commit.

- [x] T1 · `pruebas` · Backend: escribir `backend/tests/test_ai_diagnoses.py` (CA-1 a CA-5) y
  `backend/tests/test_diagnostico_ia.py` (CA-6 a CA-8), y agregar a
  `backend/tests/test_hardware_service.py` las de `get_device_plant_for_user` (CA-8), con los
  nombres de la tabla «Pruebas por criterio» y sin webcam, Gemini, ESP8266 ni red (ver las notas del
  plan).
  - Comprobar que fallan las del desempate de CA-1, CA-5 y CA-8, y que fallan porque falta la
    funcionalidad.
  - Anotar que las de CA-1 (sin desempate), CA-2, CA-3, CA-4, CA-6 y CA-7 ya pasan porque fijan el
    comportamiento actual.
  - Si la de CA-2 falla, avisarlo.

  (`test: agrega pruebas del historial de diagnósticos en el backend`)
- [x] T2 · `pruebas` · Frontend: escribir `frontend/test/diagnosis_provider_test.dart` (modelo y
  provider: CA-10, CA-12, CA-14, CA-15), `frontend/test/diagnosis_history_screen_test.dart` (CA-9 a
  CA-15) y `frontend/test/plant_detail_diagnoses_button_test.dart` (CA-9), con un
  `DiagnosisProvider` falso y sin HTTP real.
  - Comprobar que fallan.
  - Anotar para `frontend-dev` lo que aún no existe (`DiagnosisModel`, `DiagnosisProvider`,
    `DiagnosisHistoryScreen`, la ruta `'/plant-diagnoses'` y el botón).

  (`test: agrega pruebas de la pantalla de historial de diagnósticos`)
- [x] T3 · `backend-dev` · En `get_diagnoses` de `backend/app/routers/ai.py`: filtrar
  `Plant.is_active == True` y ordenar por `created_at` e `id` descendentes (D1). Si la prueba de
  CA-2 falló, corregir el schema según D3 y anotarlo en el plan. Deben pasar
  `test_ai_diagnoses.py` y el resto de la suite con cobertura.
  (`fix: oculta los diagnósticos de plantas borradas y ordena el historial de forma estable`)
- [x] T4 · `backend-dev` · Agregar `get_device_plant_for_user` a
  `backend/app/services/hardware_service.py` y usarla en `diagnostico_ia` de
  `backend/app/routers/hardware.py` con `current_user.id` (D2). Deben pasar
  `test_diagnostico_ia.py`, `test_hardware_service.py` y toda la suite con
  `python -m pytest -q --cov --cov-config=.coveragerc`.
  (`fix: no guarda el diagnóstico en la planta de otro usuario`)
- [x] T5 · `frontend-dev` · Crear `frontend/lib/models/diagnosis_model.dart` (D4) y
  `frontend/lib/providers/diagnosis_provider.dart` (D5) hasta que pase
  `diagnosis_provider_test.dart`. (`feat: carga el historial de diagnósticos de una planta`)
- [x] T6 · `frontend-dev` · Crear `frontend/lib/screens/plant/diagnosis_history_screen.dart` con la
  hoja de detalle (D8, D9, D10), registrar la ruta `'/plant-diagnoses'` con su provider local en
  `frontend/lib/main.dart` (D6, D7) y agregar el botón «Diagnósticos» en `plant_detail_screen.dart`
  (D7). Deben pasar `diagnosis_history_screen_test.dart`,
  `plant_detail_diagnoses_button_test.dart`, `flutter test` completo y
  `flutter analyze --no-fatal-infos --no-fatal-warnings` sin avisos nuevos.
  (`feat: muestra el historial de diagnósticos desde el detalle de la planta`)
- [x] T7 · `revisor` · Ejecutar las verificaciones, comparar `git diff --name-only main...HEAD` con
  la tabla «Archivos que se tocan», comprobar que `api_constants.dart` no está en ningún commit y
  escribir el informe en `specs/002-historial-diagnosticos/revision.md`.
- [ ] T8 · Persona (Valentina Bermeo) · Comprobación manual con el backend levantado sobre
  PostgreSQL, la webcam y `GEMINI_API_KEY`:
  1. pedir un diagnóstico desde el menú lateral;
  2. abrir el detalle de la planta del ESP8266 y tocar «Diagnósticos»; el nuevo debe salir primero,
     con su foto y la hora local correcta;
  3. abrir uno y leer el texto completo;
  4. abrir una planta sin diagnósticos (estado vacío);
  5. apagar el backend (error y «Reintentar»);
  6. revisar las fotos en Chrome y en el emulador;
  7. si la prueba de CA-9 quedó como manual, comprobar el botón.

  Después: anotar en el plan las «Diferencias con lo planeado», responder las observaciones del
  revisor y abrir el pull request.
