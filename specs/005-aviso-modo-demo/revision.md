# Revisión · Spec 005

- **Revisado por:** agente `revisor`
- **Commit revisado:** ninguno propio. La rama `feat/005-aviso-modo-demo` no tiene commits: `HEAD` es
  `9f5e9fb`, igual que `main`. Se revisó el árbol de trabajo del 2026-11-12, es decir, `git diff main`
  más los archivos sin seguimiento de `git status --short`.
- **Veredicto:** APROBADA CON OBSERVACIONES

## Verificación ejecutada

| Comprobación | Resultado |
|---|---|
| `python -m pytest -q --cov --cov-config=.coveragerc` | **254 passed**, 9 warnings (las de siempre), 6,65 s. Cobertura total **72,63 %** con umbral de 60 %. Coincide con `main`: esta spec no toca el backend. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | Código de salida 0. **28 issues** en la rama frente a **33** en `main`. Se midió sobre una copia de `main` en el scratchpad y se compararon las listas sin números de línea. **Ningún aviso nuevo.** Desaparecen 5: `unused_field` de `_isDemoMode` (`plant_provider.dart`), `unused_import` de `sensor_card.dart` (`plant_detail_screen.dart`), un `withOpacity` de `home_screen.dart` (estaba en la caja de lecturas que se movió) y un `unnecessary_underscores` en cada una de `recommendations_screen.dart` y `notifications_screen.dart`, que pertenecían a las listas fijas que se borraron. |
| `flutter test` | **260 pruebas, «All tests passed!»**, código de salida 0. En `main` hay 173, así que la rama añade 87 en los 6 archivos nuevos. |
| Archivos cambiados dentro del alcance del plan | **Sí.** Los 13 archivos de `lib/` (10 modificados y 3 nuevos) y los 8 de `test/` (2 modificados y 6 nuevos) están en la tabla «Archivos que se tocan». `git diff main --stat` no muestra nada en `backend/`, `esp8266_maceta_inteligente/`, `database/` ni `frontend/pubspec.yaml`. No hay `.env`, `venv/`, `build/` ni imágenes nuevas: `backend/static/ultimo_diagnostico.jpg` está ignorado y no aparece en el estado. **`frontend/lib/config/api_constants.dart`** está modificado, pero su único cambio es `baseUrl` → `http://10.97.203.53:8000`, la IP local de la responsable. No es un hallazgo de la spec, pero **ese archivo no debe entrar en ningún commit** (obs. 8). |
| Pruebas existentes cambiadas | **Solo las dos de D14**, y solo como dice el plan (`git diff main -- frontend/test`). En `sensor_health_model_test.dart`, el grupo y el nombre pasan de `demo` a `empty` y se usa `SensorDataModel.empty(7, 'Echeveria')`. En `plant_detail_health_test.dart`, el nombre pasa a «lectura vacía (API caído)…» y se usa `_fake(SensorDataModel.empty(7, 'Echeveria'))`. Las aserciones son idénticas (4 y 3): no se debilitó nada. |
| Búsqueda de rellenos en `frontend/lib/` | No quedan `SensorDataModel.demo`, `_isDemoMode`, `Parcialmente` (salvo el valor por defecto de `weather_bar.dart`, que ya no se usa: D13), `26 de Junio`, `"25.0"`, `"50.0"`, `?? 0} %`, `?? 0} °C`, `?? 50`, `?? 25`, `?? 26`, `87%`, `Panel Solar`, `lightLevel: 85`, `batteryLevel: 98` ni `12.4`. Los dos `?? 0` que quedan son `days_overdue` y `pump_active` en `fromJson`, que no son lecturas. `WeatherBar` y `SensorCard` solo aparecen en sus propios archivos, sin uso, como decide D13. No hay ningún `!` ni `toStringAsFixed` sobre `soilHumidity`, `temperature` o `airHumidity` sin comprobar antes el nulo: los únicos `!` (`plant_detail_screen.dart` 452 y 511) están dentro de la rama `!= null`. |

## Criterios de aceptación

Para ver si las pruebas pueden fallar se usaron mutantes en una copia de `frontend/` dentro del
scratchpad, y se ejecutaron solo los archivos de prueba afectados. La copia sin cambios pasa.
Resultado: **37 de 40 mutantes mueren**. Los tres que sobreviven son el contador del historial en
`clearSession` (obs. 2) y dos desbordes nuevos en Inicio que tapa `_tolerante` (obs. 1).

| Criterio | ¿Tiene prueba? | ¿La prueba puede fallar? | Observación |
|---|---|---|---|
| CA-1 | Sí. En el provider, sin red, 401 y 500, y el JSON con `is_demo` que no se lee. En Inicio, el aviso en las dos pestañas, encima de la fila de pestañas. | Sí. Con `showingDemoPlants => false` fallan 6 pruebas. | — |
| CA-2 | Sí. `si loadTodayTasks falla…` y `con plantas reales y tareas de ejemplo se ve el aviso`. | Sí. Muere el mutante que quita la comprobación del contador en el `catch` de `loadTodayTasks`. | — |
| CA-3 / CA-4 | Sí. Hay cuatro casos sin aviso: listas llenas, vacías y mezcladas. Además, `una carga correcta apaga el modo demo aunque la lista llegue vacía` y, en el detalle de una planta real, ningún aviso. | Fijan el comportamiento previo, como anota el plan. | — |
| CA-5 | Sí. «Reintentar» llama 3 veces a las 3 cargas, el aviso desaparece y queda uno solo si vuelve a fallar. También comprueba el botón desactivado mientras cargan las plantas o las tareas, sin segunda llamada, y que se suelta la planta de ejemplo elegida. | Sí. Fallan si `onRetry` queda siempre activo (2 pruebas) y si no se suelta la planta de ejemplo elegida. | — |
| CA-6 | Sí. Provider: `loadSensorData` de una planta de ejemplo no hace peticiones. Detalle: aviso, «Sin datos» ×2 y «sin lecturas». | Sí. Si se quita la salida temprana del provider, la prueba que cuenta peticiones falla. | El refresco de 3 s llama a `loadSensorData`, que sale sin red para la planta de ejemplo. |
| CA-7 | Sí. Regar, Detener, Programar tarea y Diagnósticos en el detalle; completar y eliminar en Inicio; Diagnóstico IA del menú; las guardas de la bomba en el provider; y la Echeveria real con id 1, que sí se riega (en el provider y en la pantalla). | Sí. Muere cada guarda que se quita: las cuatro del detalle, la de tareas, la de eliminar, la del menú y las dos del provider. También muere el bloqueo por id (`plant.id > 5` en la pantalla y `plantId <= 5` en el provider). | **El bloqueo va por el objeto (`isDemo`), no por el id.** Detalles en «Bomba real». |
| CA-8 | Sí. Borrado que falla y borrado correcto. | Sí. Si se ignora el resultado de `deletePlant`, falla. | `confirmDismiss` siempre devuelve `false`. No hay `onDismissed`. `messenger` se captura antes del `await` y hay `mounted` tras el diálogo. Las dos pruebas terminan sin excepciones aunque el `Dismissible` se desmonta mientras se borra. |
| CA-9 | Sí. Hay pruebas de que `clearSession` vacía todo y de las respuestas tardías de plantas (éxito y fallo), tareas de hoy (éxito y fallo), próximas y lecturas en vivo. En Inicio, el orden `plants.clear` → `tasks.clear` → `auth.logout` → LOGIN. | Sí, salvo el historial. Mueren los mutantes que quitan `_plantsRequestId++` (2 pruebas), `_sensorRequestId++`, `_todayRequestId++` y `_upcomingRequestId++` de los `clearSession`, y también los que quitan las comprobaciones del contador después del `await`. **Sobrevive quitar `_historyRequestId++`** (obs. 2). | — |
| CA-10 | Sí. `login_demo_mode_test.dart` con `SolarGrowApp` real y `MockClient` a 500. | Sí. Comprueba la clave del aviso, el texto, «Reintentar», la Echeveria y que no salió ninguna petición a `/api/controls`. | — |
| CA-11 | Sí. Provider: lectura vacía, `sensorsUnavailable` con sin red, 401 y 500, se apaga al volver la conexión y no lanza con la lista vacía. Detalle: «Sin conexión…», «Sin datos» ×2 y ningún aviso de ejemplo. | Sí. Con `_sensorsUnavailable = false` en el fallo caen 5 pruebas. | — |
| CA-12 | Sí. Respuesta 200 con lecturas nulas, antes de la primera carga, 24 °C sin suelo y 40 % sin temperatura. | Sí. | — |
| CA-13 | Sí. `sensors_info_box_test.dart`: los tres huecos, uno por uno, y ninguno «25.0» ni «50.0». | Sí, por construcción: el valor sale de `_format`. | Usa el literal `'Sin datos'` en lugar de `DemoMessages.noData` (obs. 7). |
| CA-14 | Sí. En vivo, luz, voltaje y batería salen nulos y la humedad del aire queda vacía. La lectura en vivo sigue dando `livePumpOn` y la salud. | Sí. Si se vuelve a poner `?? 50.0` en la humedad del aire, falla. | — |
| CA-15 | Sí. En Inicio y en el detalle (planta real y de ejemplo) no aparecen `WeatherBar`, «Parcialmente», «nublado», «Neiva» ni «26». | Sí. | — |
| CA-16 | Sí. «Fertilizar: Sin fecha» y «Fertilizar: 3 de Diciembre». | Sí. | — |
| CA-17 / CA-18 | Sí. Se comprueban los textos exactos y que no aparece ninguno de los 15 textos prohibidos, ni `TextButton`, `Card` o `ListTile`. | Sí. | — |
| CA-19 | Sí. El menú no tiene «Panel Solar» ni su icono y conserva los otros 7 elementos. | Sí. | — |
| CA-20 | Sí. El aviso de Inicio, los dos avisos del detalle, «Sin datos» y «Sin fecha» a 320 y 360 px; la caja de lecturas a 240 y 280 px; y los estados vacíos a 320 y 360 px. Todo con `_expectTextoEntero` (párrafo, ancho intrínseco y rectángulo). | Sí, para los textos nuevos. Mueren `maxLines: 1` con elipsis, `softWrap: false` y `fontSize: 40` en el aviso, y `maxLines: 1` y `softWrap: false` con 40 en «Sin datos». También muere un desborde dentro del propio aviso (`SizedBox(width: 400)` en su fila): `_tolerante` lo rechaza. **Sin embargo, `_tolerante` deja pasar cualquier otro desborde nuevo de `home_screen.dart`** a 320/360 px (obs. 1). | En el detalle y en la caja se toleran todos los «overflowed», igual que en `plant_detail_overflow_test.dart`, como dice el plan. Los textos nuevos se validan aparte. |
| CA-21 | Sí. El `flutter test` completo pasa y solo cambian las dos pruebas de D14. No hay cambios en `backend/`. | — | `api_constants.dart` aparece modificado solo por la IP local, que no debe subirse (obs. 8). |
| CA-22 | Manual (T10). | — | No se pudo comprobar aquí. |

### Bomba real: caminos revisados

- **Detalle.** «Regar», «Detener riego», «Programar tarea» y «Diagnósticos» llaman primero a
  `_blockIfDemo()` (`plant_detail_screen.dart` 63-78), que mira `selectedPlant.isDemo`: el mismo objeto
  que se muestra y cuyo id se manda. Debajo, `activateWatering` y `stopWatering` tienen la segunda
  barrera (`plant_provider.dart` 308-319 y 343-347). Esa barrera compara el id **y** la marca de
  `_selectedPlant`. Por eso la Echeveria real con id 1 se riega, y lo prueban el provider y la pantalla.
- **Lecturas.** `loadSensorData` sale sin red para la planta de ejemplo elegida (187-200), también en
  el refresco de 3 s.
- **Planta de ejemplo en la lista pero no elegida.** Desde Inicio solo se puede eliminar, y
  `confirmDismiss` mira `plant.isDemo` del objeto de la tarjeta. Para regarla o pedir sus lecturas hay
  que abrirla, y abrirla la elige.
- **`selectedPlant` de ejemplo tras «Reintentar».** Si `loadPlants` sale bien, se sueltan la planta de
  ejemplo elegida, su lectura, `sensorsUnavailable` y la bomba en vivo, y se invalida la lectura en
  vuelo (`plant_provider.dart` 68-75). Si vuelve a fallar, todo sigue siendo de ejemplo y sigue
  bloqueado. Mientras carga, la pestaña muestra el indicador y no se puede abrir ninguna planta.
- **Lista mezclada.** Si se agrega una planta real con el servidor de vuelta (riesgo del plan), cada
  acción mira su propio objeto. No encontré ningún camino en el que una acción sobre un ejemplo use
  la planta real con el mismo id.
- **Otras pantallas.**
  - Información de la planta solo lee `selectedPlant` y no tiene acciones.
  - Agregar planta crea una planta nueva y no actúa sobre un ejemplo.
  - No existe pantalla de edición de planta.
  - `showCreateTaskSheet` solo se abre desde el detalle, que tiene su guarda.
  - Estadísticas no manda órdenes, pero sí pide el historial por el id de una planta de ejemplo
    (obs. 4).
- **Diagnóstico IA del menú.** Es la única entrada a `_abrirDiagnosticoIA`. Se bloquea si hay
  ejemplos en cualquiera de las dos listas (`home_screen.dart` 935-946).

### Otras comprobaciones

- **Desbordes previos de Inicio.** Monté `HomeScreen` con el mismo fake en la rama y en una copia de
  `main`. Los dos desbordes existen igual en las dos y no los introduce la spec:
  - la fila de pestañas: 124 px a 320 px y 84 px a 360 px;
  - la cabecera del menú: 8 px «on the bottom», a cualquier ancho.

  Las cifras no coinciden con las del plan (149/109 px) porque ese fake no tenía tareas.
- **`mounted` y `BuildContext`.** `flutter analyze` no da `use_build_context_synchronously`.
  - `my_plants_tab.dart` comprueba `mounted` después del diálogo y captura `messenger` y el provider
    antes del `await`.
  - En el menú, `messenger` se captura antes de `Navigator.pop`.
  - `_handleComplete` no tiene `await` antes de la guarda.
- **`notifyListeners` tras `dispose`.** Los providers son globales y no se desechan. Los contadores
  descartan las respuestas viejas en éxito y en fallo.
  - En `loadPlants` y `loadTodayTasks`, una respuesta descartada no vuelve a poner `isLoading` en
    `false`. Esto no deja estados atascados: o lo hizo `clearSession` o lo hará la carga nueva que la
    reemplazó.
- **Cerrar sesión.** `clearSession()` de los dos providers se llama antes de `logout()`.
  - Vacía plantas, planta elegida, lectura, `sensorsUnavailable`, bomba en vivo, error, historial (con
    su error y su indicador de carga), tareas de hoy, tareas próximas e `isLoading`.
  - Es el único sitio que llama a `logout`.
- **Convenciones.**
  - Los textos están en español.
  - Los archivos nuevos usan `SolarColors`. Los `Colors.transparent` de los `AppBar` de
    Recomendaciones y Notificaciones ya estaban en `main`.
  - El flujo de pantalla → provider se respeta en todo lo nuevo. La llamada directa a `ApiService`
    del diálogo de Diagnóstico IA ya existía.
  - No se tocó el firmware.
- **Specs 001-004.** Siguen en verde sin cambios las pruebas de Estadísticas e historial, el
  historial de diagnósticos y la ruta `/plant-diagnoses`, la detención del riego con confirmación y la
  salud según sensores. El detalle conserva la etiqueta de la spec 004 y la lógica de la spec 003.
- **`tasks.md`.** T1-T8 están marcadas `[x]` y lo que piden está hecho. Lo comprobé en el código, con
  las pruebas y con `flutter analyze`.

## Observaciones

| # | Gravedad | Observación | Decisión del equipo | Motivo |
|---|---|---|---|---|
| 1 | media | **`_tolerante` acepta más desbordes de los dos que declara.** Está en `frontend/test/home_demo_mode_test.dart` 298-336. Acepta cualquier error que (a) diga «overflowed», (b) contenga `home_screen.dart` y (c) sea horizontal «on the right» o vertical «on the bottom» (325-333). No comprueba la línea de origen ni el tamaño. Lo comprobé con dos mutantes que **sobreviven**: añadir en Inicio, solo por debajo de 400 px, una `Row` de 500 px, o una `Column` que se sale de su caja. Las 20 pruebas de `home_demo_mode_test.dart` siguen pasando. Dentro de esos dos orígenes, cualquier desborde nuevo de Inicio a 320/360 px pasa sin que nadie lo vea, y lo mismo con los desbordes verticales en las pruebas del menú y de cerrar sesión. Además, en las 5 pruebas envueltas, la comprobación `tester.takeException()` de `_finish` (238) no puede fallar, porque los errores los recoge el helper. El aviso sí queda protegido: un desborde dentro de `DataNoticeBanner` hace fallar la prueba, y el texto se mide aparte. Sugerencia: además de las condiciones actuales, exigir el número de línea de las dos filas (o el texto «Mis Plantas» y la cabecera) y que como mucho haya un error de cada tipo. | | |
| 2 | baja | **Ninguna prueba cubre `_historyRequestId++` en `clearSession`** (`frontend/lib/providers/plant_provider.dart` 168). Si se quita, las 29 pruebas de `demo_mode_provider_test.dart` siguen pasando. El plan ya lo anota como «hueco conocido». El código es correcto: una respuesta de historial que llegue después de cerrar sesión se descarta en 291 y 298. Falta una prueba como las demás de «respuesta tardía» para `loadSensorHistory`. | | |
| 3 | baja | **`completeTask` reemplaza por id en las dos listas** (`frontend/lib/providers/task_provider.dart` 137-139, código previo). En el caso de CA-2, Hoy tiene tareas de ejemplo con ids 1-5 y Próximamente puede tener tareas reales. Si se completa una tarea real próxima con id del 1 al 5, la de ejemplo con ese id en Hoy se sustituye por la tarea real completada. No manda nada al servidor por un ejemplo ni afecta a la bomba, pero mezcla un dato real dentro de la lista de ejemplo. Se arregla reemplazando solo si `!t.isDemo`, o con «Reintentar». | | |
| 4 | baja | **Estadísticas pide el historial por el id de una planta de ejemplo.** Ocurre en `frontend/lib/screens/stats/stats_screen.dart` 71, 86 y 95. Si se entra en modo demo, se lanza `GET /api/sensors/history/1..5`. Sin servidor o sin token da el error de la spec 001, que es honesto. Pero si el servidor volvió sin «Reintentar», muestra el historial real de la planta con ese id bajo el nombre de la planta de ejemplo, y sin aviso. Es solo lectura, y la spec deja fuera de alcance el aviso propio de Estadísticas. Lo dejo anotado para un `chore` o una spec posterior. | | |
| 5 | baja | **El estilo de «Sin datos» del detalle no sigue D10 y no se anotó.** En `frontend/lib/screens/plant/plant_detail_screen.dart` 443-450 y 502-509, D10 pide `SolarColors.textLight` y peso 700. El código usa `SolarColors.primary` y `FontWeight.w900`, el mismo color que una lectura real. La sección «Diferencias con lo planeado» no lo menciona. Así, «Sin datos» se distingue menos de un valor real. | | |
| 6 | baja | **`frontend/lib/widgets/sensors_info_box.dart` 15 escribe el literal `'Sin datos'`** en lugar de `DemoMessages.noData` (D6 y D11 piden los textos en un solo sitio). El texto es correcto y las pruebas lo fijan. | | |
| 7 | baja | **Diferencia de colores ya declarada, para que la valide una persona.** En `SensorsInfoBox`, con la bomba activa, el icono es `SolarColors.skyBlue` y el texto `SolarColors.primaryDark`, en lugar del `SolarColors.humidity` de D11. Está anotado en «Diferencias con lo planeado»; solo se ve a mano (T10). | | |
| 8 | baja | **Advertencia de commit.** `frontend/lib/config/api_constants.dart` está modificado solo con la IP local de la responsable (`baseUrl` → `http://10.97.203.53:8000`). No es parte de la spec y **no debe entrar en ningún commit**: hay que agregar los archivos uno por uno, como dice `tasks.md`. Si entrara, se incumplirían CA-21 y `frontend/CLAUDE.md` («No cambiar `baseUrl`»). | | |

## Lo que esta revisión no pudo comprobar

- **CA-22 de punta a punta** (T10): Chrome y emulador con `uvicorn` y PostgreSQL reales. En particular,
  que el registro de `uvicorn` no muestre ningún `POST /api/controls/water` al tocar «Regar» sobre la
  Echeveria de ejemplo. El bloqueo solo está probado con fakes y `MockClient`.
- **Hardware real.** El ESP8266, la bomba y la lectura en vivo de `clima-actual` con la placa conectada.
- **Webcam y Gemini.** Solo se comprobó que Diagnóstico IA no se abre en modo demo; el diálogo real no
  se ejecutó.
- **Aspecto visual.** El color y el contraste del aviso, «Sin datos» con el color de un valor real
  (obs. 5), los estados vacíos y los textos a 320 y 360 px en un teléfono. Las pruebas usan la fuente
  Ahem, que exagera los anchos. Por eso no se pudo juzgar la fila «Fertilizar» ni las etiquetas de la
  caja de lecturas, que con esa fuente no caben.
- **Tiempo de espera** del aviso con una IP inalcanzable (`ApiService` sin tiempo límite), fuera de
  alcance.
