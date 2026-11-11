# Plan · Spec 001

## Lo que se comprobó en el código antes de planear

- `/stats` → `const StatsScreen()` en `frontend/lib/main.dart` (línea 81). Se navega desde dos
  sitios de `frontend/lib/screens/home/home_screen.dart`: la barra inferior (índice 2,
  `pushNamed('/stats')`) y el menú lateral («Estadísticas»). En ninguno se pasan argumentos y
  `StatsScreen` no tiene parámetros ni lee ningún provider: **hoy la pantalla no recibe planta**.
- `PlantProvider.selectedPlant` solo se asigna en `my_plants_tab.dart` (`selectPlant`, al abrir el
  detalle de una planta) y no se limpia al volver. Al abrir Estadísticas recién iniciada la app es
  `null`.
- `PlantProvider.plants` lo carga `HomeScreen` al iniciar (`loadPlants`). El backend lista las
  plantas de la más nueva a la más antigua (`plants.py`, `order_by(Plant.created_at.desc())`), y el
  ESP8266 escribe por defecto en la planta activa **más antigua** (`hardware_service.get_device_plant`).
  O sea: la primera planta de la lista suele ser justo la que no tiene lecturas.
- `GET /api/sensors/history/{plant_id}` existe (`backend/app/routers/sensors.py`), exige sesión,
  filtra por dueño (404 «Planta no encontrada»), devuelve `List[SensorDataResponse]` ordenada por
  `recorded_at` descendente. `hours` y `limit` son `Query(24)` y `Query(100)` sin `ge`/`le`.
- `ApiConstants.sensorsHistory = '/api/sensors/history'` existe y no se usa en ningún archivo Dart.
  No termina en `/`, así que la ruta con id es `'${ApiConstants.sensorsHistory}/$plantId'`.
- `ApiService.get` ya acepta `queryParams`.
- `SensorDataResponse` trae `temperature`, `air_humidity`, `soil_humidity` y `recorded_at` (más las
  columnas de relleno). No hace falta tocar schemas ni modelos SQLAlchemy.
- Las lecturas del ESP8266 se guardan como mucho una vez por minuto y solo si cambió algún valor
  (`hardware_helper.py`, `INTERVALO_INSERCION_DB = 60`): hasta 1 440 por día y 43 200 en 30 días.
- `fl_chart` e `intl` ya están en `frontend/pubspec.yaml`. No existe ninguna prueba de la pantalla
  de estadísticas ni del historial.

## Decisiones técnicas

- **D1 · Qué planta muestra la pantalla (decisión explícita).** La ruta `/stats` sigue sin
  argumentos. La pantalla toma la planta inicial de `PlantProvider`: `selectedPlant` si existe y, si
  no, `plants.first`. Muestra el nombre de la planta y, cuando el usuario tiene más de una, un
  selector desplegable con sus plantas; elegir otra recarga el historial con el periodo actual. La
  planta elegida se guarda en el estado de la pantalla y **no** llama a `selectPlant` (que además
  dispara `loadSensorData` y cambiaría lo que ve el detalle).
  *Motivo:* es lo que menos toca: no cambia `main.dart` ni `home_screen.dart`, y reutiliza el estado
  que ya existe. El selector es necesario porque sin él, quien entra desde la barra inferior vería
  la planta más nueva —casi siempre sin lecturas— sin forma de cambiarla.
  *Alternativas descartadas:* pasar la planta por `arguments` (los dos accesos actuales no tienen
  planta que pasar); abrir Estadísticas solo desde el detalle de la planta (obliga a cambiar la
  navegación de `home_screen.dart`); preguntar al backend cuál es la planta del ESP8266 (acopla la
  pantalla a `/api/hardware/*`, que depende del hardware).
- **D2 · El estado va en `PlantProvider`, no en un provider nuevo.** Se agregan `sensorHistory`
  (lista en orden cronológico ascendente), `isHistoryLoading`, `historyError` y
  `Future<bool> loadSensorHistory(int plantId, {required int hours})`.
  *Motivo:* `PlantProvider` ya «gestiona las plantas y datos de sensores»; así la pantalla usa un
  solo provider, no hay que registrar nada en `main.dart` y la prueba de widget necesita un solo
  provider falso. Se usan campos propios (no `isLoading`/`error`) para no interferir con las otras
  pantallas que observan ese provider.
- **D3 · Modelo Dart nuevo `SensorReadingModel`** (`id`, `plantId`, `temperature`, `airHumidity`,
  `soilHumidity`, `recordedAt`) con `fromJson`. *Motivo:* `SensorDataModel` representa «la última
  lectura con estado de salud» (`plant_name`, `health_status`, `health_score`), campos que el
  historial no trae; reutilizarlo dejaría `healthStatus: 'unknown'` en cada punto. El modelo nuevo
  ignora a propósito luz, voltaje y batería.
- **D4 · Error sin datos inventados.** Si `ApiService.get` lanza cualquier excepción,
  `loadSensorHistory` deja `sensorHistory` vacía, pone `historyError` con el mensaje en español y
  devuelve `false`. No hay rama de datos demo (a diferencia de `loadSensorData`). Al empezar cada
  carga se vacía la lista anterior, para que nunca se vean lecturas de otro periodo u otra planta
  bajo el selector nuevo. El error se muestra en la pantalla (no en `SnackBar`) porque debe quedar
  visible junto al botón «Reintentar».
- **D5 · Límites del endpoint:** `hours: int = Query(24, ge=1, le=720)` y
  `limit: int = Query(100, ge=1, le=500)`; FastAPI responde 422.
  *Motivo:* 720 h es el periodo más largo del selector (30 d). 500 puntos sobran para una gráfica
  de 150 px de alto en un móvil y mantienen la respuesta pequeña. La validación es declarativa, como
  pide `.claude/rules/backend-routers.md` (equivalente a `Field(ge=, le=)` para parámetros de
  consulta), sin `if` en el endpoint. Los valores por defecto no cambian.
- **D6 · El periodo completo con pocos puntos: muestreo parejo en el backend (decisión explícita).**
  Cuando en el periodo hay más lecturas que `limit`, el endpoint ya no devuelve las `limit` más
  recientes sino `limit` lecturas repartidas por todo el periodo. Pasos: (1) consultar solo los `id`
  del periodo ordenados por `recorded_at` descendente; (2) si son `N <= limit`, se usan todos; si
  no, se eligen las posiciones `round(i * (N - 1) / (limit - 1))` para `i = 0 … limit-1` (con
  `limit = 1`, solo la posición 0), que siempre incluyen la más reciente y la más antigua; (3) traer
  esas filas con `id IN (...)` y devolverlas en el mismo orden descendente. La app pide siempre
  `limit=200`.
  *Motivo:* es la forma más simple que funciona igual en PostgreSQL (real) y en SQLite (pruebas):
  no usa funciones de fecha propias de un motor. La app no necesita lógica de reducción y nunca
  descarga 43 200 filas. Traer solo los `id` (enteros) de 30 días es barato; el tope de 500 mantiene
  el `IN` muy por debajo del máximo de variables de SQLite.
  *Alternativas descartadas:* que la app pida `limit=43200` (respuesta de varios MB y gráfica
  ilegible); promediar por intervalos en SQL (`date_trunc` no existe en SQLite, habría dos
  implementaciones); paginar (más código en los dos lados para el mismo resultado).
  *Cambio de comportamiento:* con más lecturas que `limit`, la respuesta ya no son «las últimas
  N». Se comprobó con Grep que ningún archivo Dart consume este endpoint, así que no rompe a nadie.
- **D7 · La lógica de D6 va en `backend/app/services/sensor_service.py`** (nuevo), como pide
  `backend/CLAUDE.md`: una función pura `pick_evenly(items, limit)` y
  `get_history(db, plant_id, hours, limit)` que recibe la `Session`. El router se queda con validar,
  comprobar el dueño y armar la respuesta.
- **D8 · Orden.** El API mantiene «más reciente primero» (contrato actual). El provider ordena de
  forma ascendente por `recordedAt` antes de exponer la lista; la pantalla no reordena.
- **D9 · Respuestas fuera de orden (CA-8).** `loadSensorHistory` lleva un contador de petición: al
  volver del `await`, si ya se lanzó otra carga, descarta su resultado y no toca el estado.
- **D10 · Gráficas.** Se conserva `_buildChartCard` y el estilo actual. El eje X es el tiempo real
  de cada lectura (no su posición en la lista), para que un hueco sin lecturas se vea como hueco.
  Una lectura con la variable en `null` no genera punto en esa gráfica; si la variable no tiene
  ningún punto, la tarjeta muestra «Sin datos» (hoy `spots.last` reventaría con lista vacía). Con un
  solo punto se muestran los puntos (`dotData`), porque una línea de un punto no se ve. El valor
  destacado es el del último punto. `horizontalInterval` deja de ser 10 fijo si hace falta para que
  la rejilla no falle con rangos pequeños. Las horas se muestran en hora local (`toLocal()`).
- **D11 · Colores.** Temperatura `SolarColors.temperature`, humedad del suelo `SolarColors.humidity`,
  humedad del aire `SolarColors.skyBlueLight` (ya existen en `theme.dart`; no se agregan colores).
- **D12 · Carga inicial.** La pantalla lanza la primera carga después del primer frame
  (`addPostFrameCallback` o `Future.microtask`, como hace `HomeScreen`), nunca dentro de `build`. Si
  `plants` está vacía y `PlantProvider.isLoading` es `true`, muestra el indicador de carga y lanza
  la carga cuando llega la lista; si está vacía y no está cargando, muestra el estado de CA-7.
- **D13 · Textos fijos** (las pruebas los buscan tal cual): «Esta planta no tiene lecturas en este
  periodo.», «No se pudieron cargar las estadísticas.», «Reintentar», «Aún no tienes plantas
  registradas.», «Sin datos», «Temperatura», «Humedad del Suelo», «Humedad del Aire».
- **Sin migraciones, sin paquetes nuevos, sin cambios en firmware, `main.dart`, `api_constants.dart`
  ni schemas.**

## Archivos que se tocan

| Archivo | Cambio |
|---|---|
| `backend/app/routers/sensors.py` | `get_sensor_history`: `ge`/`le` en `hours` y `limit` (D5) y delega la consulta en el servicio (D6, D7). No se toca el resto del router. |
| `backend/app/services/sensor_service.py` | **Nuevo.** `pick_evenly` y `get_history` (D6, D7). |
| `backend/tests/test_sensors_history.py` | **Nuevo.** Pruebas del endpoint con una app de prueba que incluye `sensors.router` (como `test_seguridad_hardware.py`) y los fixtures de `conftest.py`. |
| `backend/tests/test_sensor_service.py` | **Nuevo.** Pruebas unitarias de `pick_evenly`. |
| `frontend/lib/models/sensor_reading_model.dart` | **Nuevo.** `SensorReadingModel` (D3). |
| `frontend/lib/providers/plant_provider.dart` | Estado y método del historial (D2, D4, D8, D9). No se cambia `loadSensorData` ni los datos demo. |
| `frontend/lib/screens/stats/stats_screen.dart` | Usa el provider; quita `_generateDemoSpots`, la gráfica de luz, `_buildSystemStats` y `_buildStatItem`; agrega humedad del aire, selector de planta y estados de carga, vacío y error (D1, D10–D13). |
| `frontend/test/sensor_history_provider_test.dart` | **Nuevo.** Pruebas de `loadSensorHistory` con `MockClient` (como `task_provider_test.dart`). |
| `frontend/test/stats_screen_test.dart` | **Nuevo.** Pruebas de widget con un `PlantProvider` falso (como `create_task_sheet_test.dart`). |
| `specs/001-estadisticas-reales/*` | Spec, plan, tareas y, al final, `revision.md`. |

No se modifica ninguna prueba existente.

## Pruebas por criterio

| Criterio | Prueba | Archivo |
|---|---|---|
| CA-1 | `con lecturas muestra las tres gráficas en orden cronológico y el último valor` | `frontend/test/stats_screen_test.dart` |
| CA-1 | `loadSensorHistory deja las lecturas en orden ascendente por fecha` | `frontend/test/sensor_history_provider_test.dart` |
| CA-2 | `no muestra Luz Solar ni Sistema Solar en ningún estado` | `frontend/test/stats_screen_test.dart` |
| CA-3 | `abre en 24h y cada periodo pide 6, 24, 168 o 720 horas` | `frontend/test/stats_screen_test.dart` |
| CA-3 | `mientras carga muestra el indicador de progreso` | `frontend/test/stats_screen_test.dart` |
| CA-3 | `envía GET a /api/sensors/history/7 con hours y limit=200` | `frontend/test/sensor_history_provider_test.dart` |
| CA-4 | `sin lecturas muestra el estado vacío y ninguna gráfica` | `frontend/test/stats_screen_test.dart` |
| CA-5 | `si el API falla muestra el error con Reintentar y ninguna gráfica` | `frontend/test/stats_screen_test.dart` |
| CA-5 | `Reintentar vuelve a pedir la misma planta y periodo y muestra las gráficas` | `frontend/test/stats_screen_test.dart` |
| CA-5 | `si el API falla devuelve false, deja el error y vacía el historial anterior` | `frontend/test/sensor_history_provider_test.dart` |
| CA-6 | `usa la planta seleccionada y, si no hay, la primera de la lista` | `frontend/test/stats_screen_test.dart` |
| CA-6 | `al elegir otra planta recarga con el periodo actual` | `frontend/test/stats_screen_test.dart` |
| CA-7 | `sin plantas muestra el aviso y no pide historial` | `frontend/test/stats_screen_test.dart` |
| CA-8 | `si una respuesta anterior llega tarde se conserva la de la última petición` | `frontend/test/sensor_history_provider_test.dart` |
| CA-9 | `una lectura sin valor no se dibuja como cero y una variable sin valores muestra Sin datos` | `frontend/test/stats_screen_test.dart` |
| CA-10 | `test_historial_devuelve_solo_las_lecturas_del_periodo_y_de_la_planta` | `backend/tests/test_sensors_history.py` |
| CA-10 | `test_historial_ordena_de_la_mas_reciente_a_la_mas_antigua` | `backend/tests/test_sensors_history.py` |
| CA-10 | `test_historial_sin_lecturas_devuelve_lista_vacia` | `backend/tests/test_sensors_history.py` |
| CA-11 | `test_historial_rechaza_hours_fuera_de_rango` (0, -1, 721) | `backend/tests/test_sensors_history.py` |
| CA-11 | `test_historial_rechaza_limit_fuera_de_rango` (0, -1, 501) | `backend/tests/test_sensors_history.py` |
| CA-11 | `test_historial_acepta_los_limites` (hours 1 y 720; limit 1 y 500) | `backend/tests/test_sensors_history.py` |
| CA-12 | `test_historial_con_mas_lecturas_que_limit_cubre_todo_el_periodo` | `backend/tests/test_sensors_history.py` |
| CA-12 | `test_pick_evenly_*` (menos elementos que el límite, más, límite 1, lista vacía, incluye extremos) | `backend/tests/test_sensor_service.py` |
| CA-13 | `test_historial_de_planta_ajena_devuelve_404` | `backend/tests/test_sensors_history.py` |
| CA-13 | `test_historial_sin_token_devuelve_401` | `backend/tests/test_sensors_history.py` |

Agregadas en la vuelta 1 de corrección (y las extra de la primera entrega):

| Criterio | Prueba | Archivo |
|---|---|---|
| CA-5 | `tras un fallo historyError es exactamente el mensaje de CA-5` | `frontend/test/sensor_history_provider_test.dart` |
| CA-6 | `CA-6 con selectedPlant que no está en la lista (2 plantas) usa la primera sin lanzar excepción` | `frontend/test/stats_screen_test.dart` |
| CA-6 | `CA-6 con selectedPlant que no está en la lista (1 planta) usa la primera y no muestra la ajena` | `frontend/test/stats_screen_test.dart` |
| CA-6 | `si la planta mostrada desaparece de la lista pasa a la primera y recarga con el periodo actual` | `frontend/test/stats_screen_test.dart` |
| CA-7 (D12) | `D12 con plantas vacías e isLoading muestra la carga, no pide historial y al llegar la lista lo pide con 24h` | `frontend/test/stats_screen_test.dart` |
| CA-8 | `si las respuestas llegan en orden se conserva la de la última petición` | `frontend/test/sensor_history_provider_test.dart` |
| CA-8 | `si una respuesta anterior llega tarde y falla no pisa los datos de la última petición` | `frontend/test/sensor_history_provider_test.dart` |
| CA-10 | `test_historial_con_el_mismo_recorded_at_desempata_por_id_descendente` | `backend/tests/test_sensors_history.py` |
| CA-11 | `test_historial_sin_parametros_usa_24_horas_y_limite_100` | `backend/tests/test_sensors_history.py` |
| CA-12 | `test_historial_con_empates_y_mas_lecturas_que_limit_no_repite_ni_pierde_extremos` | `backend/tests/test_sensors_history.py` |
| CA-13 | `test_historial_de_planta_inexistente_devuelve_404` | `backend/tests/test_sensors_history.py` |

Notas para quien escribe las pruebas:

- Las pruebas de CA-10 y CA-13 fijan comportamiento que ya existe: **pasarán desde el principio**.
  Las que deben fallar antes del código son las de CA-11, CA-12 y todas las del frontend.
- Backend: crear las lecturas con `recorded_at` explícito y con zona
  (`datetime.now(timezone.utc) - timedelta(...)`); no depender de `server_default`. Para CA-12, por
  ejemplo 50 lecturas repartidas en 29 días y `hours=720&limit=10`: deben volver 10, la primera es
  la más reciente, la última es la más antigua, y no coinciden con las 10 más recientes.
- Frontend (widget): el provider falso extiende `PlantProvider` y sobreescribe
  `loadSensorHistory`, `sensorHistory`, `isHistoryLoading`, `historyError`, `plants` y
  `selectedPlant`; registra `plantId` y `hours` de cada llamada. Las gráficas se cuentan con
  `find.byType(LineChart)` y sus puntos se leen de `LineChart.data.lineBarsData.first.spots`
  (valores `y` y `x` creciente).
- Frontend (provider): `http.runWithClient` + `MockClient`; para CA-8, retrasar la primera respuesta
  con un `Completer`.

## Riesgos y lo que no se puede verificar

- **El muestreo descarta lecturas, no promedia.** En 30 días con 200 puntos queda una lectura cada
  ~3,6 horas: un pico corto (p. ej. la humedad justo después de regar) puede no verse en 7d o 30d.
  En 6h y 24h con el guardado actual casi no se pierde nada. Si se necesita ver picos, hace falta
  otra spec (mínimos/máximos por intervalo).
- **SQLite frente a PostgreSQL.** Las pruebas corren en SQLite, que guarda las fechas sin zona; la
  comparación `recorded_at >= since` funciona porque todo se escribe en UTC. En PostgreSQL real no
  se ejecuta ninguna prueba automática: conviene una comprobación manual con el backend levantado.
- **Las lecturas de `seed_data.py` son aleatorias.** El script de datos demo inserta, para cada
  planta, 48 lecturas con `random.uniform(...)` (una cada 30 minutos, `source="esp32"`). En una base
  recién sembrada la pantalla las graficará como historial porque el API no las distingue de las
  del ESP8266 (`source="esp8266"`). Esta spec no toca `seed_data.py` ni filtra por `source`; si la
  responsable quiere que los datos demo no aparezcan o se marquen como demo, es otra decisión.
- **Sin el ESP8266 no hay lecturas nuevas.** La comprobación manual de CA-1 necesita lecturas en la
  base (las que haya dejado la placa o las aleatorias del punto anterior); si son más viejas que 30
  días la pantalla mostrará, correctamente, el estado vacío.
- **Modo demo.** Si el API no responde al listar plantas, `PlantProvider` carga plantas demo; al
  abrir Estadísticas el historial fallará y se verá el error de CA-5 con el selector de plantas
  demo. Es coherente con la spec, pero puede confundir; arreglar el modo demo está fuera de alcance.
- **Pruebas de widget con `fl_chart`.** No se verifica el dibujo en píxeles, solo los datos que
  recibe `LineChart`. El aspecto (colores, hueco entre lecturas, selector de planta en pantallas
  angostas) se revisa a mano en Chrome o en el emulador.
- **Cobertura.** El umbral de `backend/.coveragerc` (60 %) no debe bajar; el servicio nuevo es
  lógica pura y debe quedar cubierto por completo.

## Diferencias con lo planeado

- **Sin cambios de comportamiento** respecto de las decisiones D1–D13.
- **Dos añadidos en la pantalla que el plan no pedía** (`frontend-dev`): bajo cada gráfica se muestra
  la hora de la primera y de la última lectura (`d/MM HH:mm`, hora local) y el tooltip de la gráfica
  muestra el valor con su hora. Motivo: con el eje X en tiempo real (D10) la gráfica no tenía
  ninguna referencia de cuándo es cada punto. No tienen criterio de aceptación ni prueba propia: se
  revisan a mano en T8.
- **Pruebas extra fuera de la tabla «Pruebas por criterio»** (`pruebas`):
  `test_historial_sin_parametros_usa_24_horas_y_limite_100` (CA-11),
  `test_historial_de_planta_inexistente_devuelve_404` (CA-13) y
  `si las respuestas llegan en orden se conserva la de la última petición` (CA-8).
- **Las pruebas fijan detalles que la spec no decía:** el selector de planta es un
  `DropdownButton<int>`, el valor destacado es el entero redondeado con la unidad pegada (`24°C`) y
  las tarjetas van en el orden Temperatura, Humedad del Suelo, Humedad del Aire.
- **Redondeo de `pick_evenly`:** se usa el `round` de Python (el .5 va al par). Las pruebas no
  dependen de los empates.
- **Imports sin usar en `backend/app/routers/sensors.py`** (`datetime`, `timedelta`, `timezone`):
  quedaron al mover la consulta al servicio y se quitaron en la vuelta 1 de corrección.
- **Vuelta 1 de corrección (el revisor rechazó la primera entrega):**
  - D1 se precisó: la planta inicial (`selectedPlant`) y la elegida en la pantalla solo valen si su
    id está en `plants`; si no, se usa `plants.first`. Antes, una planta que quedó seleccionada de
    otra sesión rompía el selector o mostraba una planta ajena (CA-6). Si la planta mostrada
    desaparece de la lista, la pantalla pasa a la primera y vuelve a pedir el historial.
  - D6 se precisó: las dos consultas ordenan por `recorded_at` e `id` descendentes, para que el
    orden sea determinista cuando dos lecturas tienen la misma fecha.
  - D10: la línea curva usa `preventCurveOverShooting` para no dibujar valores fuera de los medidos.
  - Pruebas agregadas: selección inválida con una y con varias plantas, planta que desaparece, lista
    de plantas que llega tarde (D12), texto exacto del error (CA-5), error tardío de una petición
    vieja (CA-8) y empates de `recorded_at`.
  - Queda sin corregir, a decisión de la responsable: `DateTime.parse` lee como hora local una fecha
    sin zona (solo pasa con SQLite; PostgreSQL devuelve la zona).
- **`dart format`** se aplicó a los tres archivos tocados de `frontend/lib/`; en
  `plant_provider.dart` puede haber líneas existentes con formato cambiado y la misma lógica.
- **Las lecturas aleatorias de `seed_data.py`** siguen fuera de alcance por decisión de la
  responsable (2026-11-11).
