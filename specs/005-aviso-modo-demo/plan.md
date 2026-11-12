# Plan · Spec 005

Este cambio toca solo la app (decisión 7 de la spec). No cambia ningún archivo de `backend/`, de
`esp8266_maceta_inteligente/`, ni `backend/seed_data.py`, `database/init.sql` o
`frontend/lib/config/api_constants.dart`. No se añaden paquetes.

## Lo que se comprobó en el código antes de planear

- **`frontend/lib/providers/plant_provider.dart`.**
  - `_isDemoMode` (19, 56, 310) no tiene getter y nadie lo lee.
  - `loadPlants` (48-64) captura cualquier excepción y llama a `_loadDemoPlants` (309-372), que crea
    `PlantModel` con ids 1-5. No tiene contador de petición, así que una respuesta tardía siempre se
    aplica.
  - `selectPlant` (126-132) limpia el estado en vivo de la bomba y llama a `loadSensorData`.
  - `loadSensorData` (135-206):
    - rama en vivo, 146-182, con luz, voltaje y batería fijas en 166-168, `?? 26.0` en 154 y
      `?? 50.0` en 155-156;
    - rama de base, 188-192;
    - rama de fallo, 193-201, que usa `_plants.first` como respaldo y `SensorDataModel.demo`;
    - el contador `_sensorRequestId` descarta respuestas viejas.
  - `activateWatering` (247-266) y `stopWatering` (270-287) reciben solo el id. Varias pruebas
    existentes los sobreescriben con esa firma (`plant_detail_stop_watering_test.dart` 76-94): **la
    firma no se puede cambiar**.
  - `deletePlant` (87-105) pone `_isLoading = true` mientras borra. `MyPlantsTab` muestra entonces el
    indicador de carga en lugar de la lista (`my_plants_tab.dart` 32-36).
- **`frontend/lib/providers/task_provider.dart`.**
  - `loadTodayTasks` (33-49) carga `_loadDemoTasks` (133-197) ante cualquier excepción.
  - `loadUpcomingTasks` (52-65) conserva la lista anterior si falla.
  - Ningún método tiene contador de petición.
- **Modelos.**
  - `PlantModel` (`frontend/lib/models/plant_model.dart` 7-56) y `TaskModel`
    (`frontend/lib/models/task_model.dart` 6-44) no tienen ninguna marca de ejemplo. Todos sus
    campos nuevos con valor por defecto son compatibles con las pruebas existentes, que construyen
    `PlantModel(id: 7, commonName: 'Echeveria')`.
  - `SensorDataModel.demo` (`sensor_data_model.dart` 86-102) solo se usa en `plant_provider.dart`
    200, `plant_detail_screen.dart` 216 y dos pruebas.
- **`frontend/lib/providers/auth_provider.dart`.** `logout` (116-121) solo se llama desde el menú de
  Inicio (`home_screen.dart` 1093-1100). `enterDemoMode` (168-180) se llama desde
  `login_screen.dart` 291 y `register_screen.dart` 405.
- **`frontend/lib/screens/home/home_screen.dart`.**
  - `_loadData` (38-48) solo carga si `isAuthenticated`.
  - Caja de lecturas en 589-717, con los rellenos de 640, 646 y 652. Usa `Colors.blue`/`Colors.grey`.
  - `WeatherBar` en 773-780 y su import en 11.
  - «Panel Solar» en 1045-1052.
  - «Diagnóstico IA / Cámara En Vivo» en 1053-1063.
  - «Cerrar Sesión» en 1093-1100.
- **`frontend/lib/screens/home/my_plants_tab.dart`.** `confirmDismiss` (265-288) solo pregunta.
  `onDismissed` (289-296) borra sin mirar el resultado y siempre dice «eliminada».
- **`frontend/lib/screens/home/tasks_tab.dart`.** `TaskCard(onComplete: () => _handleComplete(provider, task.id))`
  (217-219). `_handleComplete` (232-244) ya muestra un error si falla.
- **`frontend/lib/screens/plant/plant_detail_screen.dart`.**
  - Acciones: `_handleWatering` (62-118), `_handleStopWatering` (131-191) y `_handleCreateTask`
    (193-205). «Diagnósticos» (559-569) navega a `/plant-diagnoses`.
  - Respaldo `demo()` en 214-216.
  - `WeatherBar` en 231-238, con sus imports `weather_bar.dart` (16) y `sensor_card.dart` (17). Este
    último ya no se usa.
  - Tarjetas en 413-420 y 463-470. «Fertilizar» en 511-514.
- **`frontend/lib/widgets/weather_bar.dart` y `sensor_card.dart`.** Después de esta spec ningún
  archivo de `lib/` los usa. `frontend/CLAUDE.md` 28 los cita como componentes de `widgets/`.
- **Pruebas de widget existentes del detalle.** Usan un `PlantProvider` falso que sobreescribe
  `selectedPlant`, `currentSensorData`, `loadSensorData` y, en la spec 003, `activateWatering`,
  `stopWatering`, `error` y `livePumpOn`. Montan `AuthProvider()` sin sesión, así que el refresco de
  3 s no arranca.
  - `plant_detail_overflow_test.dart` (40-74) tolera los errores «overflowed» de filas que ya se
    desbordan en `main`.
- **`frontend/test/diagnosis_route_test.dart` 49-61.** Ya monta `SolarGrowApp` dentro de
  `http.runWithClient` con un `MockClient`. Ese patrón sirve para la prueba de CA-10.

## Decisiones técnicas

- **D1 · Qué es «modo demo» en el código: una marca en cada planta y en cada tarea.**
  - `PlantModel` y `TaskModel` reciben `final bool isDemo`. En el constructor vale `false` por
    defecto y `fromJson` **no** la lee: lo que llega del servidor nunca es de ejemplo.
  - `_loadDemoPlants` y `_loadDemoTasks` crean sus elementos con `isDemo: true`.
  - **Este es el único origen de verdad.** De él salen:
    - `PlantProvider.showingDemoPlants => plants.any((p) => p.isDemo)`;
    - `TaskProvider.showingDemoTasks => todayTasks.any((t) => t.isDemo)`.

    Se leen los **getters públicos** (`plants`, `todayTasks`) y no los campos privados. Así los
    fakes de las pruebas de pantalla, que sobreescriben esos getters, ejercitan el cálculo real.
  - Se borra `_isDemoMode`.
  - **Cuándo se enciende:** como hoy, ante cualquier excepción de `loadPlants` o de `loadTodayTasks`
    (sin red, 401, 500 o JSON inválido; decisión 3).
  - **Cuándo se apaga:**
    - cuando una carga sale bien y reemplaza la lista (con 200 y lista vacía queda en `false`, CA-4);
    - con `clearSession` (D4).
  - **Inicio** calcula `modoDemo = plantProvider.showingDemoPlants || taskProvider.showingDemoTasks`
    con `context.watch` (CA-1, CA-2).
  - *Motivo:* la marca viaja con el objeto. Por eso una planta de ejemplo y una real con el mismo id
    (la Echeveria 1) se distinguen siempre. Las acciones se bloquean mirando `plant.isDemo` o
    `task.isDemo`, nunca el id (CA-7).

- **D2 · Bloqueo de acciones sobre ejemplos.** Hay dos líneas de defensa.
  - **En la pantalla, con el objeto (la principal).** Si la planta o la tarea es de ejemplo, se
    muestra el SnackBar `DemoMessages.notAvailable` y se sale **sin llamar al provider**:
    - `plant_detail_screen.dart`:
      - al principio de `_handleWatering`, de `_handleStopWatering` y de `_handleCreateTask` (no se
        abre el formulario);
      - en el `onTap` de «Diagnósticos» (no se navega);
    - `my_plants_tab.dart`: en `confirmDismiss`, después de que la persona confirma (D9);
    - `tasks_tab.dart`: `_handleComplete` pasa a recibir el `TaskModel` (`onComplete: () => _handleComplete(provider, task)`)
      y mira `task.isDemo` antes de `completeTask(task.id)`;
    - `home_screen.dart`: «Diagnóstico IA / Cámara En Vivo» con `modoDemo` cierra el menú, muestra
      el SnackBar y no abre el diálogo.
  - **En el provider, solo para la bomba (respaldo).**
    - `activateWatering(plantId)` y `stopWatering(plantId)` comprueban primero:
      `_selectedPlant != null && _selectedPlant!.id == plantId && _selectedPlant!.isDemo`.
    - Si se cumple, ponen `_error = DemoMessages.notAvailable`, llaman a `notifyListeners()`,
      devuelven `false` y **no hacen ninguna petición**.
    - Miran el objeto elegido, no buscan por id en `_plants`. La firma no cambia (lo exigen los fakes
      existentes).
  - `deletePlant`, `createTask` y `completeTask` no llevan respaldo en el provider. Solo reciben el
    id, y buscarlo en las listas sería volver a decidir por id. Las pantallas que los llaman tienen
    el objeto y lo comprueban.

- **D3 · Lecturas de una planta de ejemplo.**
  - Al principio de `loadSensorData(plantId)`, si `_selectedPlant` tiene ese id y `isDemo`:
    - `_currentSensorData = SensorDataModel.empty(plantId, nombre)`;
    - `_sensorsUnavailable = false`, `_livePumpPlantId = null`, `_livePumpOn = null`;
    - `notifyListeners()` y `return`, **sin ninguna petición** (CA-6).
  - El refresco de 3 s del detalle sigue corriendo, pero no sale nada a la red. No se toca el
    `initState` del detalle.

- **D4 · Cerrar sesión.**
  - Nuevos `PlantProvider.clearSession()` y `TaskProvider.clearSession()`. Vacían **todo** el estado:
    - plantas, planta elegida, lectura, `_sensorsUnavailable`, estado en vivo de la bomba, error,
      historial y su error;
    - tareas de hoy y próximas;
    - `isLoading` vuelve a `false`.
  - **Incrementan los contadores de petición.** Para eso se añaden `_plantsRequestId` en
    `loadPlants` y `_todayRequestId` y `_upcomingRequestId` en `TaskProvider`. Los de lecturas e
    historial ya existen. Así una respuesta en vuelo de la sesión anterior no se aplica después
    (CA-9).
  - Los contadores nuevos siguen el patrón de `_sensorRequestId`: `final id = ++_x;` al empezar, y
    después del `await`, `if (id != _x) return;`, tanto en éxito como en fallo.
  - **Quién los llama:** el `onTap` de «Cerrar Sesión» de Inicio (`home_screen.dart` 1093-1100), en
    este orden:
    1. `context.read<PlantProvider>().clearSession()`;
    2. `context.read<TaskProvider>().clearSession()`;
    3. `context.read<AuthProvider>().logout()`;
    4. navegación a `/login`.
  - *Motivo:* es el único sitio desde el que se cierra sesión. Así ningún provider conoce a otro: no
    hace falta `ChangeNotifierProxyProvider` ni pasarle providers a `AuthProvider`.
  - `AuthProvider` no cambia. `enterDemoMode` tampoco: tras él, Inicio carga, las peticiones salen
    sin token, fallan con 401 o sin red y aparecen los ejemplos con el aviso (CA-10). Como para
    llegar al login hay que haber cerrado sesión (o no haberla abierto), los providers ya están
    vacíos.

- **D5 · Lecturas: nunca inventadas.**
  - `SensorDataModel.demo` **se borra** y lo sustituye `factory SensorDataModel.empty(int plantId, String plantName)`:
    - todas las lecturas en `null` y `pumpActive: 0`;
    - `healthStatus: 'Sin datos'` y `healthScore: null`;
    - `recordedAt: null`.
  - **Rama de fallo de `loadSensorData`:**
    - `_currentSensorData = SensorDataModel.empty(plantId, nombre)` y `_sensorsUnavailable = true`.
      Así `currentSensorData` sigue sin ser nulo, y por eso las pruebas de las specs 003 y 004 sobre
      el fallo no cambian.
    - `nombre` sale de `_selectedPlant` si tiene ese id. Si no, de `_plants` con ese id, y si no hay
      ninguna, `''`. Se acaba el `orElse: () => _plants.first`, que lanzaba con la lista vacía (obs.
      3 de la revisión de la spec 003).
  - **Ramas en vivo y de base:** ponen `_sensorsUnavailable = false`.
  - **`selectPlant`:** también lo pone en `false`.
  - **Getter nuevo:** `bool get sensorsUnavailable`.
  - **Rama en vivo (CA-14):**
    - se quitan `lightLevel`, `solarVoltage` y `batteryLevel` (quedan en `null`);
    - temperatura: `(hardwareData['temperatura'] as num).toDouble()`, porque la condición de entrada
      ya exige que no sea nula;
    - humedad del aire: `((hardwareData['humedad_aire'] ?? hardwareData['humedad']) as num?)?.toDouble()`,
      sin `?? 50.0`;
    - salud, `livePumpOn` y la condición de entrada no cambian (specs 003 y 004).
  - **Respaldo del detalle** (`plant_detail_screen.dart` 214-216): pasa a
    `currentSensorData ?? SensorDataModel.empty(plant?.id ?? 0, plant?.commonName ?? '')`.

- **D6 · Textos en un solo sitio.** Archivo nuevo `frontend/lib/config/demo_messages.dart` con
  `class DemoMessages` y estas constantes:

  | Constante | Texto exacto |
  |---|---|
  | `homeBanner` | `Modo demo: no se pudo conectar con el servidor. Las plantas y tareas que ves son de ejemplo.` |
  | `retry` | `Reintentar` |
  | `plantBanner` | `Modo demo: esta planta es de ejemplo y no tiene lecturas reales.` |
  | `sensorsUnavailable` | `Sin conexión con el servidor: no se pueden mostrar las lecturas.` |
  | `notAvailable` | `No disponible en modo demo.` |
  | `noData` | `Sin datos` |
  | `noDate` | `Sin fecha` |
  | `deleteFailed` | `No se pudo eliminar la planta. Intenta de nuevo.` |

  Las pruebas usan los textos literales, no las constantes, para que fallen si alguien cambia un
  texto.

- **D7 · Widget del aviso.** Archivo nuevo `frontend/lib/widgets/data_notice_banner.dart`:
  `DataNoticeBanner({super.key, required String message, VoidCallback? onRetry})`.
  - Un `Container` de ancho completo, con fondo `SolarColors.warning` al 15 % de opacidad, borde
    `SolarColors.warning` y esquinas de 12.
  - Dentro, una `Column`:
    - una fila con `Icons.info_outline` (`SolarColors.secondaryDark`, 18) y `Expanded(Text(message))`.
      El texto es de 12,5, `SolarColors.textPrimary`, **sin `maxLines`, sin `overflow` y con
      `softWrap` por defecto**;
    - si `onRetry` no es nulo, debajo y alineado a la derecha, un `TextButton` con el texto
      «Reintentar». Si `onRetry` es nulo, el botón no aparece.
  - *Motivo:* con el botón debajo del texto, nada compite por el ancho a 320 px (CA-20).
  - **Claves para las pruebas:**
    - `ValueKey('aviso-modo-demo')` en Inicio;
    - `ValueKey('aviso-planta-ejemplo')` y `ValueKey('aviso-sin-conexion')` en el detalle.

- **D8 · Inicio** (`home_screen.dart`).
  - Se quitan `WeatherBar` (773-780) y su import (11).
  - En su lugar, si `modoDemo` (D1): `Padding(horizontal: 20)` con
    `DataNoticeBanner(key: ValueKey('aviso-modo-demo'), message: DemoMessages.homeBanner, onRetry: ...)`.
    Queda encima de la fila «Mis Plantas | Tareas», visible en las dos pestañas (CA-1).
  - **«Reintentar»:**
    - llama a `_loadData()`, que lanza `loadPlants`, `loadTodayTasks` y `loadUpcomingTasks`;
    - `onRetry` es `null` (botón desactivado) mientras `plantProvider.isLoading || taskProvider.isLoading`,
      para que no haya peticiones dobles;
    - el aviso desaparece solo cuando las dos listas dejan de tener ejemplos (D1).
  - **`loadPlants` con éxito y una planta de ejemplo elegida.** En `PlantProvider`: si
    `_selectedPlant?.isDemo == true`, se limpia la planta elegida, la lectura, `_sensorsUnavailable`
    y el estado en vivo de la bomba, y se incrementa `_sensorRequestId`.
    - Así ninguna lectura, salud o `livePumpOn` de una planta de ejemplo sobrevive a la vuelta de la
      conexión.
    - La siguiente planta que se abra pasa por `selectPlant`, que carga todo de nuevo (specs 003 y
      004 sin cambios).
    - Una planta real elegida no se toca.
  - Se borra el `ListTile` «Panel Solar» (1045-1052) (CA-19).
  - «Diagnóstico IA / Cámara En Vivo»: guarda de D2.
  - «Cerrar Sesión»: secuencia de D4.
  - La caja de lecturas pasa a un widget propio (D11).

- **D9 · Eliminar una planta** (`my_plants_tab.dart`).
  - En `confirmDismiss`:
    1. Muestra el diálogo de confirmación, como hoy. Si se cancela, devuelve `false`.
    2. Si `plant.isDemo`, muestra «No disponible en modo demo.» y devuelve `false`.
    3. Guarda `ScaffoldMessenger.of(context)` y `context.read<PlantProvider>()` **antes** del
       `await`.
    4. `final ok = await provider.deletePlant(plant.id);`
    5. Si `ok`, muestra «${plant.commonName} eliminada». Si no, `DemoMessages.deleteFailed` con
       fondo `SolarColors.error`.
    6. **Devuelve siempre `false`.**
  - Se quita `onDismissed`.
  - *Motivo:* `deletePlant` pone `isLoading` y la pestaña cambia la lista por el indicador de carga,
    así que el `Dismissible` se desmonta en mitad de la confirmación. Si devolviera `true`, la
    animación de descarte correría sobre un widget desmontado, y si el borrado falla la tarjeta
    desaparecería aunque la planta siguiera en la lista. Devolviendo `false`:
    - si se borra, la tarjeta se va porque el provider la quita de `_plants` (como hoy);
    - si falla, la tarjeta se queda (CA-8).

- **D10 · Detalle** (`plant_detail_screen.dart`).
  - Se quitan `WeatherBar` (231-238), el import de `weather_bar.dart` y el de `sensor_card.dart`,
    que ya no se usaba. Así desaparece su aviso de `flutter analyze`.
  - **En el mismo sitio, como mucho uno de estos avisos:**
    - si `plant.isDemo`:
      `DataNoticeBanner(key: ValueKey('aviso-planta-ejemplo'), message: DemoMessages.plantBanner)`;
    - si no, y `plantProvider.sensorsUnavailable`:
      `DataNoticeBanner(key: ValueKey('aviso-sin-conexion'), message: DemoMessages.sensorsUnavailable)`;
    - si no, ninguno.
  - **Tarjetas (CA-11, CA-12).**
    - Con valor: `'${v.round()} %'` y `'${v.round()} °C'`, como hoy, con el mismo estilo.
    - Sin valor: `DemoMessages.noData` en tamaño 20, peso 700 y `SolarColors.textLight`.
    - *Motivo:* a 320 px cada tarjeta deja unos 117 px de texto. «Sin datos» a 28 y peso 900 haría
      salto de línea, y a 20 cabe en una sola.
  - **«Fertilizar» (CA-16):** `plant.nextFertilizeDate != null ? _formatDate(...) : DemoMessages.noDate`.
  - Guardas de D2 en «Regar», «Detener riego», «Programar tarea» y «Diagnósticos».
  - No cambian la etiqueta «Según sensores», la planta animada, la fila de botones ni la lógica de
    la spec 003.

- **D11 · Caja de lecturas del diálogo de Diagnóstico IA (CA-13).**
  - `_buildSensorsInfoBox` y `_buildSensorItem` (`home_screen.dart` 589-717) se mueven a
    `frontend/lib/widgets/sensors_info_box.dart` como `SensorsInfoBox({super.key, required SensorDataModel? data})`.
    El diálogo lo usa con `data: context.read<PlantProvider>().currentSensorData`.
  - Con `data == null` sigue mostrando «Cargando datos de sensores...».
  - Cada valor que falte se ve como `DemoMessages.noData`. Con valor, `toStringAsFixed(1)` más la
    unidad, como hoy.
  - Al moverlo, los `Colors.blue`, `Colors.grey` y sus tonos pasan a `SolarColors`:
    - bomba activa: `SolarColors.skyBlueLight` de fondo y `SolarColors.humidity` para icono y texto;
    - bomba inactiva: `SolarColors.cardBg` de fondo y `SolarColors.textLight`.
  - El título «Lecturas del ESP8266» no cambia (fuera de alcance).
  - *Motivo:* el widget se prueba sin abrir el diálogo, que llama al API directamente.

- **D12 · Recomendaciones y Notificaciones (CA-17, CA-18).**
  - **Recomendaciones:** se borran la lista fija (13-81), el `ListView` y `_RecItem`.
    - El `AppBar` no cambia, con el título «Recomendaciones IA» y la insignia «IA».
    - El cuerpo es un estado vacío centrado, con `Padding(32)` y `SingleChildScrollView`:
      - icono `Icons.menu_book_outlined` en `SolarColors.textLight`, tamaño 56;
      - «Todavía no hay recomendaciones automáticas.» en 16, peso 600, `SolarColors.textPrimary`,
        centrado;
      - «Para revisar una planta, usa el Diagnóstico IA del menú o el historial de Diagnósticos de la
        planta.» en 13, `SolarColors.textSecondary`, centrado.
  - **Notificaciones:** se borran la lista fija (13-60), `_NotifItem` y la acción «Marcar todas»
    (71-79).
    - El cuerpo es el mismo estado vacío, con `Icons.notifications_none` y «Todavía no hay
      notificaciones.».
  - Ningún texto lleva `maxLines`.

- **D13 · `WeatherBar` y `SensorCard` se quedan como archivos sin uso.**
  - No se borran `frontend/lib/widgets/weather_bar.dart` ni `sensor_card.dart`.
  - *Motivo:*
    - `frontend/CLAUDE.md` 28 los cita, y ese archivo no se edita dentro de esta spec;
    - un archivo sin uso no da avisos en `flutter analyze`;
    - ninguno de los dos se ve en pantalla.
  - Borrarlos es un `chore` aparte (ver «Riesgos»).

- **D14 · Pruebas existentes que cambian: exactamente dos,** porque la spec quita
  `SensorDataModel.demo` (decisión 2).

  | Archivo y líneas | Cambio | Lo que no cambia |
  |---|---|---|
  | `frontend/test/sensor_health_model_test.dart` 163-170 | El grupo `'demo'` pasa a `'empty'`. La prueba pasa a `'empty trae Sin datos y puntaje null'` y construye `SensorDataModel.empty(7, 'Echeveria')` en lugar de `.demo(...)` | Las cuatro aserciones (`healthStatus`, `healthScore`, `needsWater` y `healthLabel`) se quedan igual |
  | `frontend/test/plant_detail_health_test.dart` 484-494 | El nombre pasa a `'lectura vacía (API caído) muestra sin lecturas, nunca Sana'` y la prueba usa `_fake(SensorDataModel.empty(7, 'Echeveria'))` | Las tres aserciones se quedan igual |

  **No cambian:**
  - `plant_provider_stop_watering_test.dart` 147-158 y `plant_provider_health_test.dart` 397-425:
    tras el fallo, `currentSensorData` es la lectura vacía de D5, no nula, con `Sin datos`;
  - `plant_detail_overflow_test.dart`, `plant_detail_diagnoses_button_test.dart`,
    `plant_detail_stop_watering_test.dart` y el resto de `plant_detail_health_test.dart`: sus fakes
    dan plantas con `isDemo` en `false` y no sobreescriben `sensorsUnavailable`, que vale `false`.
    No buscan clima, fechas ni valores de tarjeta;
  - `task_provider_test.dart` y `create_task_sheet_test.dart`: las firmas de `createTask` y
    `completeTask` no cambian;
  - `stats_screen_test.dart`, `diagnosis_*_test.dart`, `sensor_history_provider_test.dart` y
    `widget_test.dart`: el splash no cambia;
  - ninguna prueba de `backend/tests/`.

## Archivos que se tocan

| Archivo | Cambio |
|---|---|
| `frontend/lib/models/plant_model.dart` | Campo `isDemo` (por defecto `false`, no se lee de JSON) (D1). |
| `frontend/lib/models/task_model.dart` | Campo `isDemo` (por defecto `false`, no se lee de JSON) (D1). |
| `frontend/lib/models/sensor_data_model.dart` | Se borra `demo()` y se añade `empty()` (D5). |
| `frontend/lib/providers/plant_provider.dart` | Ejemplos con `isDemo`, `showingDemoPlants`, se borra `_isDemoMode`; guardas de bomba (D2); planta de ejemplo sin peticiones (D3); `clearSession` y `_plantsRequestId` (D4); `sensorsUnavailable`, lectura vacía, nombre sin `_plants.first`, rama en vivo sin luz, voltaje, batería ni `?? 50.0` (D5); suelta la planta de ejemplo elegida al recargar con éxito (D8). |
| `frontend/lib/providers/task_provider.dart` | Ejemplos con `isDemo`, `showingDemoTasks`, `clearSession` y contadores de petición (D1, D4). |
| `frontend/lib/config/demo_messages.dart` | **Nuevo.** Textos de D6. |
| `frontend/lib/widgets/data_notice_banner.dart` | **Nuevo.** Aviso de D7. |
| `frontend/lib/widgets/sensors_info_box.dart` | **Nuevo.** Caja de lecturas sacada de Inicio, sin rellenos (D11). |
| `frontend/lib/screens/home/home_screen.dart` | Sin `WeatherBar`, aviso con «Reintentar», sin «Panel Solar», guarda de Diagnóstico IA, cierre de sesión con `clearSession`, usa `SensorsInfoBox` (D2, D4, D8, D11). |
| `frontend/lib/screens/home/my_plants_tab.dart` | Eliminar con guarda y resultado real (D2, D9). |
| `frontend/lib/screens/home/tasks_tab.dart` | `_handleComplete` recibe la tarea y aplica la guarda (D2). |
| `frontend/lib/screens/plant/plant_detail_screen.dart` | Sin `WeatherBar` ni imports sin uso, avisos, «Sin datos», «Sin fecha», guardas, respaldo `empty()` (D2, D5, D10). |
| `frontend/lib/screens/recommendations/recommendations_screen.dart` | Estado vacío honesto (D12). |
| `frontend/lib/screens/notifications/notifications_screen.dart` | Estado vacío honesto, sin «Marcar todas» (D12). |
| `frontend/test/demo_mode_provider_test.dart` | **Nuevo.** Providers y modelos (CA-1 a CA-7, CA-9, CA-11, CA-12, CA-14). |
| `frontend/test/home_demo_mode_test.dart` | **Nuevo.** Inicio, pestañas y menú (CA-1 a CA-5, CA-7 a CA-9, CA-15, CA-19, CA-20). |
| `frontend/test/login_demo_mode_test.dart` | **Nuevo.** Botón «Modo Demo (sin servidor)» con la app real y `MockClient` (CA-10). |
| `frontend/test/plant_detail_demo_test.dart` | **Nuevo.** Detalle (CA-6, CA-7, CA-11, CA-12, CA-15, CA-16, CA-20). |
| `frontend/test/sensors_info_box_test.dart` | **Nuevo.** Caja de lecturas (CA-13, CA-20). |
| `frontend/test/empty_screens_test.dart` | **Nuevo.** Recomendaciones y Notificaciones (CA-17, CA-18, CA-20). |
| `frontend/test/sensor_health_model_test.dart` | **Prueba existente que cambia:** 163-170, de `demo()` a `empty()` (D14). |
| `frontend/test/plant_detail_health_test.dart` | **Prueba existente que cambia:** 484-494, de `demo()` a `empty()` (D14). |
| `specs/005-aviso-modo-demo/*` | Spec, plan, tareas y, al final, `revision.md`. |

**No se tocan:**
- código: `auth_provider.dart`, `login_screen.dart`, `register_screen.dart`, `main.dart`,
  `create_task_sheet.dart`, `task_card.dart`, `weather_bar.dart`, `sensor_card.dart`;
- configuración y documentación: `api_constants.dart`, `pubspec.yaml`, `frontend/CLAUDE.md`;
- `backend/` entero, `esp8266_maceta_inteligente/`, `database/`.

## Pruebas por criterio

| Criterio | Prueba | Archivo |
|---|---|---|
| CA-1 | `si loadPlants falla sin red, con 401 o con 500 carga plantas de ejemplo marcadas` (3 variantes) | `frontend/test/demo_mode_provider_test.dart` |
| CA-1 | `las plantas que llegan del servidor nunca están marcadas como ejemplo` | `frontend/test/demo_mode_provider_test.dart` |
| CA-2 | `si loadTodayTasks falla carga tareas de ejemplo marcadas` | `frontend/test/demo_mode_provider_test.dart` |
| CA-3, CA-4 | `con respuestas 200, también con listas vacías, no hay nada de ejemplo` | `frontend/test/demo_mode_provider_test.dart` |
| CA-5 | `loadPlants con éxito reemplaza los ejemplos y suelta la planta de ejemplo elegida` | `frontend/test/demo_mode_provider_test.dart` |
| CA-5 | `loadPlants con éxito conserva una planta real elegida` | `frontend/test/demo_mode_provider_test.dart` |
| CA-6 | `loadSensorData de una planta de ejemplo no hace ninguna petición y deja una lectura vacía` | `frontend/test/demo_mode_provider_test.dart` |
| CA-7 | `activateWatering y stopWatering con una planta de ejemplo elegida no hacen peticiones y devuelven false` | `frontend/test/demo_mode_provider_test.dart` |
| CA-7 | `activateWatering con la planta real de id 1 elegida sí hace la petición` | `frontend/test/demo_mode_provider_test.dart` |
| CA-9 | `clearSession vacía plantas, planta elegida, lectura, historial y tareas` | `frontend/test/demo_mode_provider_test.dart` |
| CA-9 | `una respuesta de la sesión anterior que llega después de clearSession no se aplica` (plantas, tareas de hoy y lecturas) | `frontend/test/demo_mode_provider_test.dart` |
| CA-11 | `si las lecturas fallan queda una lectura vacía y sensorsUnavailable; al volver se apaga` | `frontend/test/demo_mode_provider_test.dart` |
| CA-11 | `si las lecturas fallan con la lista de plantas vacía no lanza` | `frontend/test/demo_mode_provider_test.dart` |
| CA-12 | `latest 200 sin lecturas deja sensorsUnavailable en false` | `frontend/test/demo_mode_provider_test.dart` |
| CA-14 | `en vivo la lectura no trae luz, voltaje ni batería y sin humedad del aire queda vacía` | `frontend/test/demo_mode_provider_test.dart` |
| CA-14 | `en vivo livePumpOn y la salud siguen funcionando` | `frontend/test/demo_mode_provider_test.dart` |
| CA-12 | `empty trae lecturas nulas, Sin datos y puntaje null` | `frontend/test/demo_mode_provider_test.dart` |
| CA-1 | `con plantas de ejemplo se ve el aviso en Mis Plantas y en Tareas` | `frontend/test/home_demo_mode_test.dart` |
| CA-2 | `con plantas reales y tareas de ejemplo se ve el aviso` | `frontend/test/home_demo_mode_test.dart` |
| CA-3, CA-4 | `sin ejemplos, con listas llenas o vacías, no hay aviso` | `frontend/test/home_demo_mode_test.dart` |
| CA-5 | `Reintentar recarga plantas y tareas y el aviso desaparece cuando llegan datos reales` | `frontend/test/home_demo_mode_test.dart` |
| CA-5 | `Reintentar está desactivado mientras se carga` | `frontend/test/home_demo_mode_test.dart` |
| CA-7 | `completar una tarea de ejemplo no llama a completeTask y avisa No disponible en modo demo` | `frontend/test/home_demo_mode_test.dart` |
| CA-7 | `eliminar una planta de ejemplo no llama a deletePlant y la planta sigue` | `frontend/test/home_demo_mode_test.dart` |
| CA-7 | `en modo demo Diagnóstico IA del menú avisa y no abre el diálogo` | `frontend/test/home_demo_mode_test.dart` |
| CA-8 | `eliminar una planta real que falla avisa el error y la planta sigue` | `frontend/test/home_demo_mode_test.dart` |
| CA-8 | `eliminar una planta real que se borra muestra eliminada` | `frontend/test/home_demo_mode_test.dart` |
| CA-9 | `Cerrar Sesión limpia los dos providers antes de salir al login` | `frontend/test/home_demo_mode_test.dart` |
| CA-15 | `Inicio no muestra clima` | `frontend/test/home_demo_mode_test.dart` |
| CA-19 | `el menú no tiene Panel Solar y conserva los demás elementos` | `frontend/test/home_demo_mode_test.dart` |
| CA-20 | `el aviso de Inicio con Reintentar se ve entero a 320 y 360 px` (dos anchos) | `frontend/test/home_demo_mode_test.dart` |
| CA-10 | `Modo Demo sin servidor lleva a Inicio con plantas de ejemplo y el aviso` | `frontend/test/login_demo_mode_test.dart` |
| CA-6 | `una planta de ejemplo muestra su aviso, Sin datos y sin lecturas` | `frontend/test/plant_detail_demo_test.dart` |
| CA-7 | `Regar, Programar tarea y Diagnósticos de una planta de ejemplo avisan y no hacen nada` (3 variantes) | `frontend/test/plant_detail_demo_test.dart` |
| CA-7 | `Regar en una planta real con id 1 llama a activateWatering` | `frontend/test/plant_detail_demo_test.dart` |
| CA-11 | `si las lecturas fallan se ve Sin conexión y Sin datos, sin el aviso de ejemplo` | `frontend/test/plant_detail_demo_test.dart` |
| CA-11 | `cuando vuelve una lectura desaparece Sin conexión y se ven los valores` | `frontend/test/plant_detail_demo_test.dart` |
| CA-12 | `sin lecturas o antes de la primera carga se ve Sin datos y nunca 0 %` | `frontend/test/plant_detail_demo_test.dart` |
| CA-12 | `con temperatura y sin suelo se ve 24 °C y Sin datos` | `frontend/test/plant_detail_demo_test.dart` |
| CA-15 | `el detalle no muestra clima` | `frontend/test/plant_detail_demo_test.dart` |
| CA-16 | `Fertilizar muestra Sin fecha o la fecha real` (2 variantes) | `frontend/test/plant_detail_demo_test.dart` |
| CA-20 | `avisos, Sin datos y Sin fecha se ven enteros a 320 y 360 px` (dos anchos) | `frontend/test/plant_detail_demo_test.dart` |
| CA-13 | `cada valor que falta se ve como Sin datos, nunca 25.0 ni 50.0` | `frontend/test/sensors_info_box_test.dart` |
| CA-13 | `con todos los valores se ven con un decimal` | `frontend/test/sensors_info_box_test.dart` |
| CA-20 | `la caja se ve entera en 240 y 280 px` | `frontend/test/sensors_info_box_test.dart` |
| CA-17 | `Recomendaciones muestra el estado vacío y nada inventado` | `frontend/test/empty_screens_test.dart` |
| CA-18 | `Notificaciones muestra el estado vacío sin Marcar todas` | `frontend/test/empty_screens_test.dart` |
| CA-20 | `los estados vacíos se ven enteros a 320 y 360 px` (dos anchos) | `frontend/test/empty_screens_test.dart` |
| CA-21 | `flutter test` completo, con las dos pruebas de D14 cambiadas y todas las demás sin cambios | todo `frontend/test/` |
| CA-22 | Paso manual | T10 |

Notas para quien escribe las pruebas:

- **Qué debe fallar al principio.**
  - **Todo lo nuevo debe fallar.** Muchos archivos no compilarán hasta que existan `isDemo`,
    `showingDemoPlants`, `showingDemoTasks`, `clearSession`, `sensorsUnavailable`,
    `SensorDataModel.empty`, `DataNoticeBanner` y `SensorsInfoBox`. Se avisa a `frontend-dev`.
  - **Pasan desde el principio, porque fijan el comportamiento actual:** las de CA-3/CA-4 en el
    provider, `la planta real de id 1 sí hace la petición` y `con todos los valores se ven con un
    decimal`. Se anotan.
- **Provider** (`demo_mode_provider_test.dart`). Mismo patrón que
  `plant_provider_stop_watering_test.dart`: `SharedPreferences.setMockInitialValues({})`,
  `http.runWithClient` con `MockClient`, que **cuenta las peticiones**, y respuestas JSON.
  - **401 y 500:** `http.Response(jsonEncode({'detail': 'x'}), 401)` o `500`. Sin red:
    `throw http.ClientException('sin conexión')`.
  - **Planta de ejemplo elegida:** forzar el fallo de `loadPlants`, luego
    `selectPlant(provider.plants.first)` (id 1, `isDemo`) y comprobar que el contador de peticiones
    no sube con `loadSensorData(1)`, `activateWatering(1)` ni `stopWatering(1)`. `error` debe valer
    `'No disponible en modo demo.'`.
  - **Id 1 real:** `loadPlants` responde `[{'id': 1, 'common_name': 'Echeveria'}]`; tras
    `selectPlant`, `activateWatering(1)` hace un `POST /api/controls/water`.
  - **Respuesta tardía (CA-9):** el `MockClient` espera un `Completer`. Se lanza `loadPlants()` sin
    `await`, se llama a `clearSession()`, se completa el `Completer` con plantas, se espera, y
    `plants` debe seguir vacía. Lo mismo con `loadTodayTasks` y con `loadSensorData`.
  - **CA-14:** `clima-actual` «En línea» con `plant_id` 7, `temperatura` 24, sin `humedad_aire` ni
    `humedad`, y `led_encendido: true` → `lightLevel`, `solarVoltage`, `batteryLevel` y `airHumidity`
    son `null`, y `livePumpOn(7) == true`.
- **Pantallas: fakes y montaje.**
  - **Fakes.** `PlantProvider` y `TaskProvider` falsos que **extienden los reales**:
    - sobreescriben `plants`, `isLoading`, `selectedPlant`, `currentSensorData`,
      `sensorsUnavailable`, `todayTasks`, `upcomingTasks`, `loadPlants`, `loadTodayTasks`,
      `loadUpcomingTasks`, `deletePlant`, `completeTask`, `activateWatering`, `clearSession` y
      `loadSensorData`;
    - cuentan las llamadas;
    - **no** sobreescriben `showingDemoPlants` ni `showingDemoTasks`. Así la prueba usa el getter
      real sobre la lista falsa: si alguien lo cambia para mirar otra cosa, la prueba falla.
  - **Inicio.** Un `AuthProvider` falso con `isAuthenticated => true` y `logout` que cuenta, para
    que `_loadData` y «Reintentar» llamen a los fakes. `MaterialApp(routes: {'/login': ...})` con un
    `Scaffold` que diga «LOGIN».
  - **Detalle.** Como `plant_detail_health_test.dart`: `AuthProvider()` sin sesión,
    `tester.view.physicalSize = Size(900, 2600)` para el comportamiento, y al final
    `pumpWidget(SizedBox())` más `pump(Duration(seconds: 15))`, por la planta animada y los 10 s de
    «Regar». Nunca `pumpAndSettle`.
  - **Rutas del detalle.** Se registran `'/plant-diagnoses'` y `'/plant-info'` con un `Scaffold`
    que diga «RUTA». CA-7 comprueba que «RUTA» no aparece.
  - **«Programar tarea»** bloqueado: no aparece el texto «Tipo de tarea» del formulario.
- **CA-10** (`login_demo_mode_test.dart`). Copiar el patrón de `diagnosis_route_test.dart` 49-61:
  - `SharedPreferences.setMockInitialValues({})` y `http.runWithClient` con un `MockClient` que
    responde 500 a todo;
  - `pumpWidget(const SolarGrowApp())` y `pump` de 300 ms, 600 ms y 2 s, como `widget_test.dart`,
    hasta llegar al login;
  - tocar «Modo Demo (sin servidor)», hacer `pump` dos veces y comprobar la clave
    `aviso-modo-demo` y el texto «Echeveria».
- **CA-20: el texto no debe recortarse** (lección de la obs. 2 de la revisión de la spec 004).
  Medir el rectángulo no basta. Un helper `_expectTextoEntero(tester, Finder texto, double ancho)`
  comprueba tres cosas:
  1. `final p = tester.renderObject<RenderParagraph>(texto);` y `expect(p.didExceedMaxLines, isFalse)`;
  2. `expect(p.getMinIntrinsicWidth(double.infinity), lessThanOrEqualTo(p.size.width + 0.5))`. La
     palabra más ancha cabe, así que con `softWrap: false` o un ancho forzado la prueba falla;
  3. `tester.getRect(texto)` queda entre 0 y `ancho`.
  - **Mutantes que deben matar estas pruebas:** `maxLines: 1` con `TextOverflow.ellipsis`,
    `softWrap: false` y `fontSize: 40` en el texto del aviso, en «Sin datos» de las tarjetas y en el
    estado vacío.
  - **Errores de desborde.**
    - En Inicio, Recomendaciones, Notificaciones y la caja: no se tolera ninguno (se comprueba con
      `tester.takeException()` nulo).
    - En el detalle se toleran solo los «overflowed» de las filas que ya se desbordan en `main`,
      con el patrón de `plant_detail_overflow_test.dart` 40-74. Además, el helper anterior
      comprueba los textos nuevos.
    - Si en Inicio a 320 px aparece un desborde previo ajeno a la spec, se tolera **solo ese** y se
      anota en «Diferencias con lo planeado».
- **CA-17 y CA-18.** Además de los textos nuevos, comprobar con `find.textContaining` que no
  aparecen «87%», «panel solar», «Batería», «tracking», «Raspberry», «Hace 30 min» ni «Marcar
  todas».

## Riesgos y lo que no se puede verificar

- **Bomba real.** El bloqueo de «Regar» sobre la Echeveria de ejemplo se prueba con fakes y
  `MockClient`. Con servidor y placa reales solo se comprueba en T10 (CA-22): durante la prueba no
  debe aparecer ningún `POST /api/controls/water` en el registro de `uvicorn`.
- **Lista mezclada.** Si el servidor vuelve mientras la app muestra plantas de ejemplo y la persona
  **agrega** una planta, `createPlant` la inserta entre las de ejemplo. El aviso sigue (es correcto,
  sigue habiendo ejemplos) y los bloqueos van por objeto, así que nada se riega por error. La lista
  se arregla con «Reintentar». No se añade lógica para esto.
- **401 a mitad de sesión.** Se ve como modo demo y no lleva al login (decisión 3).
- **Sin tiempo límite en `ApiService`.** Con una IP inalcanzable (como la `baseUrl` local), el
  aviso puede tardar lo que tarde el sistema en cortar la conexión.
- **Parpadeo al eliminar.** `deletePlant` sigue poniendo `isLoading`, y la pestaña muestra el
  indicador de carga un momento, como hoy. Con D9 la tarjeta ya no se desliza fuera: desaparece al
  reconstruirse la lista.
- **Desbordes previos del detalle a 320 px.** Las pruebas los toleran. Por eso los textos nuevos se
  comprueban con el helper de CA-20 y no solo con la ausencia de errores.
- **Archivos sin uso.** `weather_bar.dart` (todavía con «Parcialmente nublado» por defecto) y
  `sensor_card.dart` quedan sin uso (D13). Borrarlos y actualizar `frontend/CLAUDE.md` 28 queda para
  un `chore` posterior.
- **Commit.** `frontend/lib/config/api_constants.dart` tiene la IP local de la responsable y no
  entra en ningún commit: los archivos se agregan uno por uno.
- **Aspecto visual.** El color del aviso, el tamaño de «Sin datos» y los estados vacíos solo se
  revisan a mano en Chrome y en el emulador (T10).
- **`flutter analyze`.** Deben desaparecer dos avisos previos (`_isDemoMode` sin usar y el import sin
  uso de `sensor_card.dart`) y no debe aparecer ninguno nuevo.

## Diferencias con lo planeado

- **Sin cambios de comportamiento** respecto de las decisiones del plan. No se tocó `backend/`, el
  firmware, `seed_data.py`, `main.dart`, `auth_provider.dart` ni
  `frontend/lib/config/api_constants.dart`. Sin paquetes nuevos.
- **`DataNoticeBanner` tiene un parámetro extra, `showRetry`** (por defecto `false`). El plan decía
  que con `onRetry` nulo el botón no aparece, pero Inicio necesita «Reintentar» visible y
  desactivado mientras carga; Inicio pasa `showRetry: true` y el detalle usa el aviso sin botón.
- **Provider de plantas:** el nombre de la planta de la lectura vacía sale de un ayudante
  (`_plantNameFor`) también en la rama en vivo, para que no lance con la lista vacía; se añadió el
  ayudante privado `_isDemoSelected` para las guardas de la bomba.
- **Inicio:** el modo demo del menú se lee en el `onTap` con `context.read`; el diálogo de eliminar
  usa `showDialog<bool>`. Se borró `_buildSensorItem`, que solo usaba la caja de lecturas antigua.
- **Textos de las pantallas vacías:** van como literales en Recomendaciones y Notificaciones; D6 no
  los definía en `DemoMessages`.
- **Colores no fijados por el plan:** en `SensorsInfoBox`, icono `skyBlue`/`textLight` y texto
  `primaryDark`/`textSecondary`; el aviso usa `SolarColors.warning`.
- **Pruebas existentes cambiadas (las dos previstas en D14):** `sensor_health_model_test.dart` y
  `plant_detail_health_test.dart` pasan de `SensorDataModel.demo` a `SensorDataModel.empty`, con las
  mismas aserciones.
- **Correcciones a pruebas de esta spec durante la implementación:**
  - `demo_mode_provider_test.dart`: el historial de la prueba de `clearSession` no traía `id` ni
    `plant_id` (obligatorios en `SensorReadingModel.fromJson`); se corrigieron solo los datos de
    preparación.
  - `home_demo_mode_test.dart`: cinco pruebas fallaban por dos desbordes que ya existen en `main` y
    que la fuente de pruebas exagera (fila «Mis Plantas | Tareas», 149 px a 320 px y 109 px a
    360 px; cabecera del menú lateral, 8 px). Se acotaron para tolerar solo esos dos orígenes y
    seguir midiendo el aviso; se comprobó con copias en el scratchpad que siguen fallando si el
    texto del aviso se recorta o se sale. **Esas dos filas no se tocaron: fuera de alcance.**
- **Límite de las pruebas de ancho:** con la fuente de pruebas, la fila «Fertilizar» y las etiquetas
  de `SensorsInfoBox` no caben a 320 px aunque en un teléfono sí puedan caber; ahí solo se comprueba
  que el texto no se recorta. Se revisa a mano en T10.
- **Tras la revisión (aprobada con observaciones)** se cerraron cuatro observaciones:
  - Obs. 1: el helper `_tolerante` de `home_demo_mode_test.dart` identifica ahora el `RenderFlex`
    culpable y solo tolera la fila de pestañas (hasta 150 px) y la cabecera del menú (hasta 10 px,
    solo en las pruebas que abren el menú); cualquier otro desborde de Inicio hace fallar la prueba.
  - Obs. 2: dos pruebas nuevas de respuesta tardía del historial tras `clearSession` (éxito y
    fallo).
  - Obs. 5: «Sin datos» en las tarjetas del detalle usa `SolarColors.textLight` y peso 700, como
    pedía D10 (la primera entrega usaba `primary` y w900).
  - Obs. 6: `SensorsInfoBox` usa `DemoMessages.noData` en vez del literal.
  - Quedan abiertas, sin corregir: obs. 3 (completar una tarea real próxima con id 1–5 sustituye la
    tarea de ejemplo con ese id en Hoy; no llega al servidor) y obs. 4 (Estadísticas pide el
    historial de una planta de ejemplo: si el servidor volvió sin «Reintentar», muestra el historial
    real de la planta con ese id; solo lectura, aviso en Estadísticas fuera de alcance).
- **Decisiones del plan que la responsable no tomó expresamente** (se siguió la propuesta del
  planificador): el Diagnóstico IA del menú se bloquea mientras se ve el aviso, también si solo
  fallaron las tareas; al eliminar, la tarjeta desaparece al recargarse la lista en vez de
  deslizarse; `weather_bar.dart` y `sensor_card.dart` quedan en el repo sin uso; mientras
  «Reintentar» carga, el aviso se mantiene con el botón desactivado.
