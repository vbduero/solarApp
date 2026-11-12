# Tareas · Spec 005

Orden: primero las pruebas (deben fallar las que piden comportamiento nuevo), luego el código y al
final la revisión. No hay tareas de `backend-dev`: esta spec no toca `backend/`. Cada tarea cabe en
un commit; el mensaje sugerido va entre paréntesis.

**Reglas para todas las tareas:**
- Los archivos se agregan uno por uno (`git add <archivo>`).
  `frontend/lib/config/api_constants.dart` tiene la IP local de la responsable y no entra en ningún
  commit.
- No se tocan `backend/`, `esp8266_maceta_inteligente/`, `backend/seed_data.py`, `database/`,
  `pubspec.yaml` ni `frontend/CLAUDE.md`.
- Solo cambian dos pruebas existentes, las de D14 del plan.

**Si el tiempo aprieta**, se recortan en este orden:
1. **T8 (CA-13).**
2. **CA-16** dentro de T6.

Ninguno de los dos deja la app a medias: la caja del diálogo y «Fertilizar» se quedan como hoy. Si
se recorta algo:
- se pasa el criterio a «Fuera de alcance» de la spec;
- se borran sus pruebas nuevas (`frontend/test/sensors_info_box_test.dart`, o las dos variantes de
  «Fertilizar» de `plant_detail_demo_test.dart`);
- se anota en «Diferencias con lo planeado».

- [x] T1 · `pruebas` · Providers y modelos. Escribir `frontend/test/demo_mode_provider_test.dart`
  (CA-1 a CA-7, CA-9, CA-11, CA-12 y CA-14) con los nombres de la tabla «Pruebas por criterio» y
  las notas del plan.
  - `MockClient` que cuenta las peticiones y `Completer` para las respuestas tardías.
  - Cambiar `frontend/test/sensor_health_model_test.dart` 163-170 exactamente como dice D14 (de
    `demo` a `empty`, mismas aserciones).
  - Comprobar que fallan o no compilan por falta de `isDemo`, `showingDemoPlants`,
    `showingDemoTasks`, `clearSession`, `sensorsUnavailable` y `SensorDataModel.empty`.
  - Anotar las que ya pasan, porque fijan el comportamiento actual: CA-3/CA-4 y `la planta real de
    id 1 sí hace la petición`.

  (`test: agrega pruebas del modo demo en los providers`)
- [x] T2 · `pruebas` · Inicio y login. Escribir `frontend/test/home_demo_mode_test.dart` (CA-1 a
  CA-5, CA-7 a CA-9, CA-15, CA-19 y CA-20) y `frontend/test/login_demo_mode_test.dart` (CA-10).
  - Fakes que extienden los providers reales sin sobreescribir `showingDemoPlants` ni
    `showingDemoTasks`.
  - `AuthProvider` falso autenticado y ruta `/login` de prueba.
  - Helper `_expectTextoEntero` de CA-20.
  - CA-10 con `SolarGrowApp` dentro de `http.runWithClient`.
  - Comprobar que fallan.

  (`test: agrega pruebas del aviso de modo demo en Inicio`)
- [x] T3 · `pruebas` · Detalle, caja de lecturas y pantallas vacías. Escribir:
  - `frontend/test/plant_detail_demo_test.dart` (CA-6, CA-7, CA-11, CA-12, CA-15, CA-16 y CA-20);
  - `frontend/test/sensors_info_box_test.dart` (CA-13 y CA-20);
  - `frontend/test/empty_screens_test.dart` (CA-17, CA-18 y CA-20).

  Además:
  - Cambiar `frontend/test/plant_detail_health_test.dart` 484-494 exactamente como dice D14.
  - En el detalle, tolerar solo los «overflowed» previos, con el patrón de
    `plant_detail_overflow_test.dart`. Terminar cada prueba con `pumpWidget(SizedBox())` y
    `pump(15 s)`, sin `pumpAndSettle`.
  - Comprobar que fallan.
  - Anotar para `frontend-dev` lo que aún no existe: `DataNoticeBanner`, `SensorsInfoBox`,
    `sensorsUnavailable` y las claves `aviso-planta-ejemplo` y `aviso-sin-conexion`.

  (`test: agrega pruebas del detalle sin datos inventados y de las pantallas vacías`)
- [x] T4 · `frontend-dev` · Modelos y providers (D1 a D5 y la parte de `PlantProvider` de D8).
  - `isDemo` en `plant_model.dart` y `task_model.dart`.
  - `SensorDataModel.empty` en lugar de `demo` en `sensor_data_model.dart`.
  - En `plant_provider.dart`:
    - ejemplos marcados, `showingDemoPlants` sobre `plants`; se borra `_isDemoMode`;
    - guardas de `activateWatering` y `stopWatering` por `_selectedPlant`;
    - planta de ejemplo sin peticiones en `loadSensorData`;
    - lectura vacía y `sensorsUnavailable`; nombre sin `_plants.first`;
    - rama en vivo sin luz, voltaje, batería ni `?? 50.0`;
    - `clearSession` y `_plantsRequestId`;
    - `loadPlants` con éxito suelta la planta de ejemplo elegida.
  - En `task_provider.dart`: ejemplos marcados, `showingDemoTasks` sobre `todayTasks`, `clearSession`
    y contadores de petición.
  - Crear aquí `frontend/lib/config/demo_messages.dart` (D6), porque los providers ya usan
    `DemoMessages.notAvailable`.
  - No cambiar las firmas de `activateWatering`, `stopWatering`, `deletePlant`, `createTask` ni
    `completeTask`.
  - **Deben pasar:** `demo_mode_provider_test.dart`, `sensor_health_model_test.dart`,
    `plant_provider_health_test.dart`, `plant_provider_stop_watering_test.dart`,
    `task_provider_test.dart` y `sensor_history_provider_test.dart`.

  (`feat: marca los datos de ejemplo y deja de inventar lecturas en los providers`)
- [x] T5 · `frontend-dev` · Inicio (D2, D4, D7 a D9).
  - Crear `frontend/lib/widgets/data_notice_banner.dart`.
  - En `home_screen.dart`:
    - quitar `WeatherBar` y su import;
    - aviso con «Reintentar» desactivado mientras carga;
    - quitar «Panel Solar»;
    - guarda de «Diagnóstico IA / Cámara En Vivo»;
    - «Cerrar Sesión» con `clearSession` de los dos providers antes de `logout`.
  - En `my_plants_tab.dart`: eliminar dentro de `confirmDismiss`, con la guarda, devolviendo siempre
    `false` y sin `onDismissed`.
  - En `tasks_tab.dart`: `_handleComplete` recibe la tarea y aplica la guarda.
  - **Deben pasar:** `home_demo_mode_test.dart` y `login_demo_mode_test.dart`.

  (`feat: avisa del modo demo en Inicio y bloquea las acciones sobre ejemplos`)
- [x] T6 · `frontend-dev` · Detalle (D2, D5, D10) en `plant_detail_screen.dart`:
  - quitar `WeatherBar` y los imports de `weather_bar.dart` y `sensor_card.dart`;
  - avisos `aviso-planta-ejemplo` y `aviso-sin-conexion`;
  - tarjetas con «Sin datos» (tamaño 20);
  - «Fertilizar: Sin fecha» (CA-16, recortable 2);
  - guardas de «Regar», «Detener riego», «Programar tarea» y «Diagnósticos»;
  - respaldo `SensorDataModel.empty`.

  No tocar la lógica de la spec 003 ni la etiqueta de la spec 004.
  - **Deben pasar:** `plant_detail_demo_test.dart`, `plant_detail_health_test.dart`,
    `plant_detail_stop_watering_test.dart`, `plant_detail_overflow_test.dart` y
    `plant_detail_diagnoses_button_test.dart`.

  (`feat: el detalle de la planta muestra Sin datos en lugar de lecturas inventadas`)
- [x] T7 · `frontend-dev` · Recomendaciones y Notificaciones (D12): estados vacíos honestos y sin
  «Marcar todas».
  - **Deben pasar:** `empty_screens_test.dart`.

  (`feat: quita las recomendaciones y notificaciones inventadas`)
- [x] T8 · `frontend-dev` · **Recortable 1.** Caja de lecturas (D11).
  - Crear `frontend/lib/widgets/sensors_info_box.dart` con los valores que falten como «Sin datos» y
    colores de `SolarColors`.
  - Usarla desde el diálogo de `home_screen.dart` y borrar `_buildSensorsInfoBox` y
    `_buildSensorItem`.
  - **Deben pasar:** `sensors_info_box_test.dart` y `flutter test` completo.
  - `flutter analyze --no-fatal-infos --no-fatal-warnings` sin avisos nuevos: deben desaparecer el
    de `_isDemoMode` y el del import de `sensor_card.dart`.

  (`fix: la caja de lecturas del diagnóstico IA no rellena valores`)
- [x] T9 · `revisor` · Ejecutar las verificaciones de `CLAUDE.md`.
  - Comparar `git diff --name-only main...HEAD` con la tabla «Archivos que se tocan».
  - Comprobar que:
    - no hay nada de `backend/`, `api_constants.dart`, `seed_data.py`, `esp8266_maceta_inteligente/`
      ni `pubspec.yaml`;
    - solo cambiaron las dos pruebas existentes de D14, y solo como dice el plan.
  - Buscar en `frontend/lib/` y confirmar que no quedan:
    - `SensorDataModel.demo`, `_isDemoMode`;
    - `Parcialmente`, `26 de Junio`, `"25.0"`, `"50.0"`, `?? 0} %`, `?? 0} °C`;
    - `87%`, `Panel Solar`;
    - `lightLevel: 85` y `batteryLevel: 98`.
  - Comprobar que los bloqueos van por `isDemo` y no por id.
  - Probar mutantes de CA-20 (`maxLines: 1`, `softWrap: false`) en el aviso y en «Sin datos».
  - Escribir el informe en `specs/005-aviso-modo-demo/revision.md`.
- [ ] T10 · Persona (Valentina Bermeo) · Comprobación manual de CA-22 en Chrome y en el emulador,
  con el backend sobre PostgreSQL. No hace falta la placa, aunque si está conectada mejor:
  1. Iniciar sesión con `demo@solargrow.com` y comprobar que no hay aviso.
  2. Abrir la Echeveria, apagar `uvicorn` y comprobar que en 3-6 s aparecen «Sin datos» y «Sin
     conexión…».
  3. Volver a Inicio, cerrar sesión y entrar con «Modo Demo (sin servidor)»: debe verse el aviso con
     «Reintentar». «Regar» sobre la Echeveria de ejemplo debe decir «No disponible en modo demo.».
  4. Encender `uvicorn`, tocar «Reintentar» (no funciona sin sesión y el aviso sigue), cerrar sesión
     e iniciar sesión de nuevo: no hay aviso y se ven los datos reales.
  5. Comprobar en el registro de `uvicorn` que no hubo ningún `POST /api/controls/water`.
  6. Revisar a 320 y 360 px (herramientas de Chrome) el aviso, «Sin datos», Recomendaciones y
     Notificaciones.

  Después: anotar en el plan las «Diferencias con lo planeado», responder las observaciones del
  revisor y abrir el pull request.
