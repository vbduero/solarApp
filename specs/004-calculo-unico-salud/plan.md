# Plan · Spec 004

## Lo que se comprobó en el código antes de planear

- **`backend/app/routers/sensors.py`.**
  - `calculate_health(plant, data)` (22-64) vive en el router. Usa suelo, temperatura y luz.
    Devuelve `{"health_status": <inglés>, "health_score": round(score, 1)}`. Solo la usa
    `get_latest_sensors` (98); no se importa en ningún otro sitio.
  - `GET /api/sensors/latest/{plant_id}` filtra por dueño (404 «Planta no encontrada»), **no** por
    `is_active`. Toma la lectura más reciente por `recorded_at`. Sin lecturas devuelve `"unknown"` y
    `50.0` (90-96).
- **`backend/app/schemas/sensor_data.py` 49-68.** `SensorLatestResponse` tiene
  `health_status: str = "healthy"` y `health_score: float = 100.0`.
- **`backend/app/models/plant.py` 51-52.** `min_humidity` (por defecto 30) y `max_temperature` (por
  defecto 35) son `Float` **sin `nullable=False`**. `PlantUpdate` (`schemas/plant.py` 35-36) los
  acepta como `Optional` y `routers/plants.py` 188-190 aplica `model_dump(exclude_unset=True)`, así
  que un `null` explícito los deja en `None` en la base.
- **`backend/app/routers/hardware.py` 21-52.** `clima-actual` llama a `obtener_datos_actuales()` y a
  `get_device_plant(db, ESP8266_PLANT_ID)`, **sin mirar el usuario**. Devuelve `plant_id` y las
  lecturas con claves en español. No calcula salud.
- **`backend/app/utils/hardware_helper.py`.** `LATEST_DATA["status_conexion"]` vale `"En línea"`
  (169) o `"Desconectado"` (233). Al arrancar trae 25 °C, 50 % y 50 % (17-25).
- **`backend/app/services/hardware_service.py`.** `get_device_plant_for_user(db, configured_plant_id,
  user_id)` ya existe y tiene pruebas. `parse_health_status` es del diagnóstico IA y no se toca.
- **`backend/tests/conftest.py`.** La fixture `plant` crea la planta sin umbrales, así que en SQLite
  quedan los valores por defecto de la columna: 30 y 35. Las pruebas de esta spec ponen 25 y 35.
- **`backend/tests/test_seguridad_hardware.py`.**
  - Tiene la fixture `autouse` de la spec 003, que fija `ESP8266_PLANT_ID = None`.
  - `test_clima_actual_con_sesion_devuelve_lectura` (89-105) solo comprueba `plant_id` y
    `humedad_suelo`.
  - Monta su propia app con `hardware` y `sensors`; importar `app.routers.hardware` ya funciona en
    la CI.
- **`frontend/lib/models/sensor_data_model.dart`.**
  - `healthStatus` (`String`, por defecto `'healthy'`) y `healthScore` (`double`, por defecto 100).
  - `isHealthy` (puntaje ≥ 60), `needsWater` (`needs_water` o `critical`) y `needsLight` (no se usa).
  - `fromJson` da `'unknown'` y 50 cuando faltan los campos. `demo()` da `'healthy'` y 85.
- **`frontend/lib/providers/plant_provider.dart` 135-221, `loadSensorData`.**
  - **Rama en vivo.** Exige `estado_conexion == 'En línea'`, `plant_id == plantId` y
    `temperatura != null`. Calcula la salud en 160-174, usa `humAire` si falta el suelo (157) y fija
    `_livePumpPlantId` y `_livePumpOn` (spec 003).
  - **Rama de base.** `SensorDataModel.fromJson` de `/api/sensors/latest/{id}`.
  - **Rama de fallo.** `SensorDataModel.demo`.
  - El contador `_sensorRequestId` descarta las respuestas viejas.
- **`frontend/lib/widgets/animated_plant.dart`.**
  - Recibe `healthScore` (por defecto 100) y `healthStatus` (por defecto `'healthy'`, sin usar).
  - `_isHealthy` (≥ 60) y `_isCritical` (< 30) deciden el color de las hojas (182-188), el tallo
    (287) y la boca (396-411). La boca es `_SmilePainter` o `_SadMouthPainter(isCritical)`.
  - Solo lo usa `plant_detail_screen.dart` 287.
- **`frontend/lib/screens/plant/plant_detail_screen.dart`.**
  - `sensorData = currentSensorData ?? SensorDataModel.demo(...)` (214-216).
  - `WeatherBar(weather: sensorData.isHealthy ? 'Parcialmente nublado' : 'Parcialmente soleado')`
    (233-239). Inicio usa el texto fijo `'Parcialmente nublado'` (`home_screen.dart` 777).
  - `AnimatedPlantWidget(healthScore:, healthStatus:, isWatering:)` (287-293).
  - «Regar» toma el color `SolarColors.error` si `needsWater` y `SolarColors.primaryDark` si no
    (520, 547). `isHighlighted` llega a `_buildCircleButton`, pero no se usa: el resaltado es solo el
    color del borde y del icono.
- **Pruebas de frontend que tocan el detalle o los datos de sensores.**
  - `plant_detail_overflow_test.dart` y `plant_detail_diagnoses_button_test.dart`: fake con
    `loadSensorData` vacío y `currentSensorData` nulo, así que hoy usan `demo`. Miden la fila de
    botones. El de desborde tolera los errores «overflowed» de otras filas.
  - `plant_detail_stop_watering_test.dart`: `fakeSensorData` es nulo, salvo en 351-355, que llama a
    `fromJson` sin campos de salud. No comprueba nada de salud.
  - `plant_provider_stop_watering_test.dart`: `latestJson` (36-50) lleva `'health_status': 'healthy'`
    y `'health_score': 90.0`; `climaJson` (21-34) no trae salud. Solo se comprueban `pumpActive` y
    `livePumpOn`.
  - Las de diagnóstico (`diagnosis_*_test.dart`) usan el `health_status` del diagnóstico IA, que no
    cambia.
- **`frontend/lib/config/api_constants.dart`** no hace falta: no hay rutas nuevas. `clima-actual`
  sigue como texto en el provider.

## Decisiones técnicas

- **D1 · La regla, en un servicio nuevo y puro** (`backend/app/services/health_service.py`).
  - Constantes con los cinco estados: `SANA = "Sana"`, `NECESITA_AGUA = "Necesita agua"`,
    `EXCESO_DE_CALOR = "Exceso de calor"`, `CRITICA = "Critica"` y `SIN_DATOS = "Sin datos"`.
  - `SensorHealth(NamedTuple)` con `status: str` y `score: Optional[float]`.
  - `calculate_sensor_health(soil_humidity, temperature, min_humidity, max_temperature) -> SensorHealth`,
    con todos los argumentos `Optional[float]`. No recibe `Session` ni `Plant`. Hace esto:
    1. `soil_humidity is None` → `SensorHealth(SIN_DATOS, None)`.
    2. Umbral `None` → se usa el valor por defecto de la columna (`DEFAULT_MIN_HUMIDITY = 30.0`,
       `DEFAULT_MAX_TEMPERATURE = 35.0`), que es el que la base habría puesto al crear la planta sin
       él.
    3. `score = 100.0`.
       - Si `soil < min`, resta `min(2 × (min − soil), 40)`.
       - Si `temperature is not None and temperature > max`, resta `min(3 × (temperature − max), 30)`.
       - Las comparaciones son estrictas: estar justo en el umbral no cuenta.
    4. Estado: `score < 40` → `CRITICA`; si no, suelo bajo el mínimo → `NECESITA_AGUA`; si no,
       temperatura sobre el máximo → `EXCESO_DE_CALOR`; si no, `SANA`.
    5. Devuelve `round(score, 1)`. El puntaje nunca baja de 30 (la resta máxima es 70), así que no
       hace falta acotarlo.
  - `calculate_live_health(plant: Optional[Plant], connection_status: str, soil_humidity, temperature) -> Optional[SensorHealth]`:
    devuelve `None` si `connection_status != "En línea"` (constante `ONLINE_STATUS`) o si `plant` es
    `None`. Si no, llama a `calculate_sensor_health` con los umbrales de la planta.
  - *Motivo:* `backend/CLAUDE.md` y la regla de routers piden la lógica en `services/`. Siendo pura,
    se prueba sin base ni hardware, y los dos endpoints usan la misma función (CA-7).
- **D2 · `GET /api/sensors/latest` usa el servicio.**
  - Se **borra** `calculate_health` de `sensors.py`; no queda ninguna regla en el router.
  - Con lectura: `calculate_sensor_health(latest.soil_humidity, latest.temperature, plant.min_humidity, plant.max_temperature)`.
  - Sin lectura: `calculate_sensor_health(None, None, ...)` → `"Sin datos"` y `None`. Así se borra
    también el `"unknown"`/`50.0` fijo.
  - Los campos de lectura (luz, voltaje, batería) se siguen devolviendo como hoy. Lo que se muestre
    de ellos es de la spec 005.
  - El filtro por dueño y el 404 no cambian (CA-6). No se añade `is_active` (fuera de alcance).
- **D3 · Schema.** En `SensorLatestResponse`: `health_status: str = "Sin datos"` y
  `health_score: Optional[float] = None`. Se corrige el comentario con los cinco valores. *Motivo:*
  CA-3 y CA-4; el valor por defecto ya no inventa una planta sana.
- **D4 · `clima-actual` devuelve el estado en vivo** (`routers/hardware.py`).
  - Se añaden dos claves a la respuesta: `"health_status"` y `"health_score"`.
  - Se calculan con `calculate_live_health(get_device_plant_for_user(db, get_settings().ESP8266_PLANT_ID, current_user.id), datos["status_conexion"], datos["humedad_suelo"], datos["temperatura"])`.
  - Si devuelve `None`, las dos claves van en `null` (CA-8). Así no se calcula nada con los 25 °C y
    50 % iniciales ni con los umbrales de una planta ajena.
  - El `plant_id` sigue saliendo de `get_device_plant` como hoy: lo usa `livePumpOn` (spec 003), y
    que revele el id de una planta ajena queda fuera de alcance.
  - Las claves van en inglés (`health_status`/`health_score`) aunque el resto de esa respuesta use
    claves en español. *Motivo:* son las mismas de `/latest`, y la app las lee con el mismo código.
- **D5 · Modelo de la app** (`sensor_data_model.dart`).
  - Constantes estáticas con los cinco estados, por ejemplo `SensorDataModel.sana`.
  - `static String parseHealthStatus(Object? raw)`: devuelve el valor si es uno de los cinco; si no
    (nulo, `'healthy'`, `'unknown'`, cualquier otro), devuelve `'Sin datos'`.
  - `healthStatus` sigue siendo `String`, ahora por defecto `'Sin datos'`.
  - `healthScore` pasa a `double?`, por defecto `null`.
  - `fromJson` usa `parseHealthStatus(json['health_status'])` y
    `(json['health_score'] as num?)?.toDouble()`.
  - `needsWater` es `healthStatus == 'Necesita agua' || healthStatus == 'Critica'`.
  - Nuevo `String get healthLabel`: `'Critica'` → `'Crítica'`, `'Sin datos'` → `'sin lecturas'`; el
    resto tal cual.
  - Se **borran** `isHealthy` (umbral propio de 60) y `needsLight` (luz de relleno, sin uso).
  - En `demo()` solo cambian `healthStatus: 'Sin datos'` y `healthScore: null`. Las lecturas demo
    quedan como están (spec 005).
  - *Motivo:* CA-3, CA-9 y CA-11. Tolerar valores desconocidos evita mostrar una planta sana si el
    backend todavía es el viejo.
- **D6 · Provider** (`plant_provider.dart`, `loadSensorData`).
  - **Rama en vivo.** La condición de entrada no cambia: así `livePumpOn` y la spec 003 siguen
    igual.
    - Se borra el cálculo de 160-174.
    - `humSuelo` pasa a `num?` y es `hardwareData['humedad_suelo']`, sin usar `humAire` (CA-5);
      `soilHumidity: humSuelo?.toDouble()`.
    - `healthStatus: SensorDataModel.parseHealthStatus(hardwareData['health_status'])` y
      `healthScore: (hardwareData['health_score'] as num?)?.toDouble()`.
    - Las constantes de luz, voltaje y batería (183-185) y el `?? 50.0` del aire no se tocan
      (spec 005).
  - **Rama de base.** Sin cambios: la salud viene de `fromJson`.
  - **Rama de fallo.** Sin cambios: `demo()` ya trae `Sin datos` (D5).
  - El contador de petición, `livePumpOn` y `selectPlant` no cambian.
- **D7 · Planta animada** (`animated_plant.dart`).
  - Se **quita** el parámetro `healthScore`. `healthStatus` pasa a ser el único que decide, con
    `'Sin datos'` por defecto.
  - `_isCritical => healthStatus == 'Critica'`.
  - `_isHappy => healthStatus == 'Sana' || healthStatus == 'Sin datos'` sustituye a `_isHealthy`
    en hojas, tallo y boca.
  - `Necesita agua` y `Exceso de calor` dan la boca triste.
  - **`Sin datos` usa la cara feliz que ya existe.** No se dibuja una cara nueva: la spec solo pide
    que no sea triste ni crítica, y la etiqueta «sin lecturas» dice que no hay datos.
  - Para poder probarlo, el `SizedBox` de la boca lleva `ValueKey('boca-feliz')`,
    `ValueKey('boca-triste')` o `ValueKey('boca-critica')`.
- **D8 · Detalle** (`plant_detail_screen.dart`).
  - `AnimatedPlantWidget` deja de recibir `healthScore`.
  - Justo debajo de la planta animada (antes del `SizedBox(height: 30)`) va
    `Text('Según sensores: ${sensorData.healthLabel}', textAlign: TextAlign.center)`, con estilo de
    `SolarColors`/`SolarTheme` y sin `maxLines`, para que haga salto de línea y nunca se desborde.
  - Textos exactos: «Según sensores: Sana», «Según sensores: Necesita agua», «Según sensores: Exceso
    de calor», «Según sensores: Crítica» y «Según sensores: sin lecturas».
  - «Regar» sigue usando `needsWater`, que ahora depende solo del estado (D5).
  - El respaldo `currentSensorData ?? SensorDataModel.demo(...)` se queda. Con D5 ya da `Sin datos`
    antes de la primera carga (CA-11).
  - **Texto del clima.** `WeatherBar` recibe el texto fijo `'Parcialmente nublado'`, igual que
    Inicio. *Motivo:* era un clima inventado que cambiaba con la salud y usaba el umbral propio de 60
    que la spec elimina. Si se quita o se marca como demo lo decide la spec 005.
- **D9 · Reparto con la spec 005.** La 004 solo cambia **qué estado de salud** se muestra:
  - los dos campos de salud de `demo()`;
  - que el respaldo del detalle dé `Sin datos`;
  - el texto del clima, que ya no depende de la salud.

  Quedan para la 005:
  - los números de lectura de `demo()`;
  - si se usa o no `demo()` y el aviso de modo demo;
  - las constantes de luz, voltaje y batería del provider y de `hardware_helper.py`;
  - el `?? 50.0` del aire y los rellenos «25.0»/«50.0» de Inicio;
  - `WeatherBar` como tal;
  - `GET /api/controls/status`.

  Si las dos specs tocan `sensor_data_model.dart` o `plant_detail_screen.dart`, la segunda en
  fusionarse resuelve el conflicto conservando las dos cosas.
- **D10 · Pruebas existentes: no se cambia ninguna.** Ninguna aserción existente depende de la
  salud según sensores:
  - `plant_provider_stop_watering_test.dart` 47-48: `'healthy'`/90 pasa a leerse como `Sin datos`
    (D5), pero ninguna prueba lo comprueba. Se deja tal cual; cambiarlo no aporta nada y la regla de
    pruebas pide no tocarlas sin un cambio de comportamiento esperado.
  - `plant_detail_stop_watering_test.dart` 351-355: `fromJson` sin salud pasa a `Sin datos`; solo se
    comprueban `pumpActive` y los botones. No cambia.
  - `plant_detail_overflow_test.dart` y `plant_detail_diagnoses_button_test.dart`: ahora aparece la
    etiqueta «Según sensores: sin lecturas» bajo la planta. Ninguna de las dos busca ese texto y
    la fila de botones no cambia. No cambian. Como la prueba de desborde tolera desbordes, el
    de la etiqueta se comprueba en una prueba nueva que mide su rectángulo.
  - `test_seguridad_hardware.py` (`clima-actual`): la respuesta tiene dos claves más y las aserciones
    siguen valiendo. No cambia.
  - Las pruebas de diagnóstico IA (backend y app) no cambian; son la comprobación de CA-12.
- **Sin migraciones, columnas, paquetes ni rutas nuevas.** No se tocan el firmware,
  `seed_data.py`, `database/init.sql`, `hardware_helper.py`, `hardware_service.py`,
  `api_constants.dart`, `home_screen.dart`, `weather_bar.dart` ni nada del diagnóstico IA.

## Archivos que se tocan

| Archivo | Cambio |
|---|---|
| `backend/app/services/health_service.py` | **Nuevo.** Estados, `SensorHealth`, `calculate_sensor_health` y `calculate_live_health` (D1). |
| `backend/app/routers/sensors.py` | Se borra `calculate_health`; `get_latest_sensors` usa el servicio también sin lecturas (D2). |
| `backend/app/schemas/sensor_data.py` | `SensorLatestResponse`: `"Sin datos"` por defecto, `health_score` opcional, comentario corregido (D3). |
| `backend/app/routers/hardware.py` | `obtener_clima` añade `health_status` y `health_score` (D4). Nada más. |
| `backend/tests/test_health_service.py` | **Nuevo.** Regla pura (CA-1, CA-5, umbrales nulos, redondeo, estado en vivo). |
| `backend/tests/test_salud_sensores.py` | **Nuevo.** API `latest` y `clima-actual` (CA-1 a CA-8). |
| `frontend/lib/models/sensor_data_model.dart` | Constantes, `parseHealthStatus`, `healthScore` opcional, `needsWater`, `healthLabel`, salud de `demo()`; se borran `isHealthy` y `needsLight` (D5). |
| `frontend/lib/providers/plant_provider.dart` | Rama en vivo: sin cálculo propio y sin cambiar el suelo por el aire (D6). |
| `frontend/lib/widgets/animated_plant.dart` | Sin `healthScore`; la cara depende del estado; claves de la boca (D7). |
| `frontend/lib/screens/plant/plant_detail_screen.dart` | Etiqueta «Según sensores: …», llamada a la planta animada sin puntaje, clima fijo (D8). |
| `frontend/test/sensor_health_model_test.dart` | **Nuevo.** Modelo (CA-3, CA-4, CA-9, CA-11). |
| `frontend/test/plant_provider_health_test.dart` | **Nuevo.** Provider con `MockClient` (CA-5, CA-8, CA-10, CA-11). |
| `frontend/test/plant_detail_health_test.dart` | **Nuevo.** Pantalla (CA-9 a CA-12), incluido el ancho de 320 y 360 px. |
| `specs/004-calculo-unico-salud/*` | Spec, plan, tareas y, al final, `revision.md`. |

Ninguna prueba existente se modifica (D10). `frontend/lib/config/api_constants.dart` no se toca y no
entra en ningún commit. `esp8266_maceta_inteligente/` y `backend/seed_data.py` no se tocan.

## Pruebas por criterio

| Criterio | Prueba | Archivo |
|---|---|---|
| CA-1 | `test_regla_de_salud_da_estado_y_puntaje_de_la_tabla` (parametrizada, 7 filas) | `backend/tests/test_health_service.py` |
| CA-1 | `test_regla_de_salud_redondea_el_puntaje_a_un_decimal` | `backend/tests/test_health_service.py` |
| CA-1 | `test_regla_de_salud_con_umbrales_nulos_usa_30_y_35` | `backend/tests/test_health_service.py` |
| CA-5 | `test_regla_de_salud_sin_humedad_del_suelo_da_sin_datos` | `backend/tests/test_health_service.py` |
| CA-5 | `test_regla_de_salud_sin_temperatura_evalua_solo_el_suelo` | `backend/tests/test_health_service.py` |
| CA-7 | `test_salud_en_vivo_en_linea_usa_los_umbrales_de_la_planta` | `backend/tests/test_health_service.py` |
| CA-8 | `test_salud_en_vivo_es_none_si_no_esta_en_linea_o_no_hay_planta` (parametrizada) | `backend/tests/test_health_service.py` |
| CA-1 | `test_latest_devuelve_estado_y_puntaje_de_la_tabla` (parametrizada) | `backend/tests/test_salud_sensores.py` |
| CA-2 | `test_latest_ignora_luz_voltaje_bateria_y_min_light` (parametrizada) | `backend/tests/test_salud_sensores.py` |
| CA-3 | `test_latest_solo_envia_los_cinco_estados_en_espanol` | `backend/tests/test_salud_sensores.py` |
| CA-4 | `test_latest_sin_lecturas_devuelve_sin_datos_y_puntaje_null` | `backend/tests/test_salud_sensores.py` |
| CA-5 | `test_latest_sin_humedad_del_suelo_devuelve_sin_datos` | `backend/tests/test_salud_sensores.py` |
| CA-5 | `test_latest_sin_temperatura_evalua_solo_el_suelo` | `backend/tests/test_salud_sensores.py` |
| CA-6 | `test_latest_de_planta_ajena_o_inexistente_devuelve_404` (parametrizada) | `backend/tests/test_salud_sensores.py` |
| CA-6 | `test_latest_sin_token_devuelve_401` | `backend/tests/test_salud_sensores.py` |
| CA-7 | `test_clima_actual_en_linea_da_la_misma_salud_que_latest` (parametrizada, 7 filas) | `backend/tests/test_salud_sensores.py` |
| CA-8 | `test_clima_actual_desconectado_no_devuelve_salud` | `backend/tests/test_salud_sensores.py` |
| CA-8 | `test_clima_actual_con_planta_del_esp8266_de_otro_usuario_no_devuelve_salud` | `backend/tests/test_salud_sensores.py` |
| CA-8 | `test_clima_actual_sin_planta_del_esp8266_no_devuelve_salud` | `backend/tests/test_salud_sensores.py` |
| CA-3 | `fromJson conserva los cinco estados en español` | `frontend/test/sensor_health_model_test.dart` |
| CA-3 | `fromJson convierte estados en inglés o desconocidos en Sin datos` | `frontend/test/sensor_health_model_test.dart` |
| CA-4 | `fromJson sin health_status ni health_score da Sin datos y puntaje null` | `frontend/test/sensor_health_model_test.dart` |
| CA-9 | `needsWater solo es verdadero con Necesita agua y Critica` | `frontend/test/sensor_health_model_test.dart` |
| CA-9 | `healthLabel muestra Crítica con tilde y sin lecturas para Sin datos` | `frontend/test/sensor_health_model_test.dart` |
| CA-11 | `demo trae Sin datos y puntaje null` | `frontend/test/sensor_health_model_test.dart` |
| CA-10 | `en vivo usa el estado que manda clima-actual sin recalcularlo` | `frontend/test/plant_provider_health_test.dart` |
| CA-10 | `desde la base usa el estado de sensors latest` | `frontend/test/plant_provider_health_test.dart` |
| CA-5 | `en vivo sin humedad del suelo no usa la humedad del aire` | `frontend/test/plant_provider_health_test.dart` |
| CA-8 | `clima-actual en línea sin health_status deja Sin datos y livePumpOn sigue funcionando` | `frontend/test/plant_provider_health_test.dart` |
| CA-11 | `si el API falla el estado es Sin datos` | `frontend/test/plant_provider_health_test.dart` |
| CA-9 | `muestra etiqueta, cara y Regar según el estado` (5 variantes) | `frontend/test/plant_detail_health_test.dart` |
| CA-9 | `la cara depende del estado y no del puntaje` | `frontend/test/plant_detail_health_test.dart` |
| CA-9 | `la etiqueta Según sensores no se sale de la pantalla a 320 y 360 px` (dos anchos) | `frontend/test/plant_detail_health_test.dart` |
| CA-10 | `pasar de dato en vivo a lectura guardada con el mismo estado no cambia lo que se ve` | `frontend/test/plant_detail_health_test.dart` |
| CA-11 | `antes de la primera carga muestra sin lecturas y no resalta Regar` | `frontend/test/plant_detail_health_test.dart` |
| CA-12 | `el detalle muestra el estado según sensores y no el del diagnóstico IA` | `frontend/test/plant_detail_health_test.dart` |
| CA-12 | Pruebas existentes de la spec 002, sin cambios | `backend/tests/test_ai_diagnoses.py`, `backend/tests/test_hardware_service.py`, `frontend/test/diagnosis_*_test.dart` |
| CA-13 | Paso manual con la placa | T8 |

Notas para quien escribe las pruebas:

- **Qué pasa desde el principio y qué debe fallar.**
  - **Deberían pasar ya**, porque fijan el comportamiento actual: las de CA-6 (404 y 401).
  - **Deben fallar** todas las demás.
    - `test_health_service.py` falla entero al importar `app.services.health_service`, que aún no
      existe. Se avisa a `backend-dev`.
    - `sensor_health_model_test.dart` y `plant_detail_health_test.dart` no compilan hasta que
      existan `healthLabel` y `healthScore` opcional. Se avisa a `frontend-dev`.
- **Backend, servicio.** Funciones puras, sin `db`. Tabla de CA-1 con `min_humidity=25` y
  `max_temperature=35`.
  - Redondeo: suelo 24.97 → `99.9`.
  - Umbrales nulos: suelo 25 y 36 °C con `None, None` → `"Necesita agua"` y `87.0` (mínimo 30 →
    déficit 5 → resta 10; máximo 35 → exceso 1 → resta 3). Con los umbrales 25 y 35 la misma lectura
    daría `"Exceso de calor"` y `97.0`, así que la prueba distingue los dos casos.
  - Estado en vivo: con `connection_status="Desconectado"` o `plant=None` devuelve `None`. Para
    `plant` basta un `Plant(min_humidity=25, max_temperature=35)` sin guardar.
- **Backend, API** (`test_salud_sensores.py`).
  - App propia con `sensors.router` y `hardware.router`, como en `test_seguridad_hardware.py`:
    `get_db` sobreescrito, `get_current_user` sobreescrito con `user` y un cliente sin
    sobreescribirlo para el 401.
  - Fixture `autouse` que fija `monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", None)`.
  - Antes de cada caso: `plant.min_humidity = 25`, `plant.max_temperature = 35` y commit.
  - Lecturas con `SensorData(plant_id=plant.id, soil_humidity=..., temperature=..., light_level=..., recorded_at=datetime.now(timezone.utc))`.
  - CA-2: luz 0 y 85, `solar_voltage` 0 y 18, `battery_level` 0 y 100, y `plant.min_light = 90`. El
    resultado debe ser el de la fila de CA-1.
  - CA-3: recorrer las 7 filas más el caso sin lecturas, y comprobar que `health_status` está en el
    conjunto de cinco valores y no en `{"healthy", "needs_water", "needs_light", "stressed", "critical", "unknown"}`.
  - `clima-actual`: `monkeypatch.setattr(hardware, "obtener_datos_actuales", lambda: {...})` con
    `status_conexion`, `temperatura`, `humedad_aire`, `humedad_suelo`, `humedad_suelo_raw` y
    `led_encendido`.
    - CA-7: comparar `health_status` y `health_score` con los de `/latest` para una lectura guardada
      con los mismos valores, y con los esperados de la tabla.
    - CA-8, desconectado: `"Desconectado"` con 0 % de suelo → `null`, `null`.
    - CA-8, planta ajena: `ESP8266_PLANT_ID = other_plant.id` → `null`, `null`.
    - CA-8, sin planta: `ESP8266_PLANT_ID = 9999` → `null`, `null`.
- **Frontend, modelo.** Sin red. `SensorDataModel.fromJson({...})` y `SensorDataModel.demo(7, 'Echeveria')`.
- **Frontend, provider** (`plant_provider_health_test.dart`). Mismo patrón que
  `plant_provider_stop_watering_test.dart`: `SharedPreferences.setMockInitialValues({})`,
  `http.runWithClient` con `MockClient` y `loadPlants()` con las plantas 7 y 8.
  - CA-10, en vivo: `clima-actual` con `humedad_suelo: 0`, `temperatura: 45` y
    `health_status: 'Sana'`, `health_score: 100` → `currentSensorData.healthStatus == 'Sana'`.
  - CA-5: `clima-actual` sin `humedad_suelo` y con `humedad_aire: 50` → `soilHumidity` es `null`.
  - CA-8: `clima-actual` en línea sin campos de salud y `led_encendido: true` → `Sin datos` y
    `livePumpOn(7) == true` (la spec 003 no se rompe).
  - CA-11: `MockClient` que lanza `ClientException` → `Sin datos` y `healthScore == null`.
- **Frontend, pantalla** (`plant_detail_health_test.dart`).
  - `FakePlantProvider extends PlantProvider` con `selectedPlant` fijo (id 7), `currentSensorData`
    sobreescrito con un campo que la prueba puede cambiar (y `notifyListeners()`), y
    `loadSensorData` vacío. `livePumpOn` no se sobreescribe: devuelve `null` y se ve «Regar».
  - Se monta como `plant_detail_diagnoses_button_test.dart`: `AuthProvider()` sin sesión (no
    arranca el refresco de 3 s) y `tester.view.physicalSize = Size(900, 2600)`.
  - Cara: `find.byKey(const ValueKey('boca-feliz'))` (o `'boca-triste'`, `'boca-critica'`) con
    `findsOneWidget`, y las otras dos con `findsNothing`.
  - «Regar» resaltado:
    `tester.widget<Icon>(find.byIcon(Icons.water_drop_outlined)).color == SolarColors.error`; normal
    es `SolarColors.primaryDark`.
  - Etiqueta: `find.text('Según sensores: Exceso de calor')` y los demás textos exactos de D8.
  - CA-9, puntaje: `Necesita agua` con 65 → boca triste; `Sana` con 90 → boca feliz.
  - CA-9, ancho: copiar el patrón de `plant_detail_overflow_test.dart` (320 y 360 px, `FlutterError.onError`
    que tolera solo los «overflowed» de las cuatro filas que ya se desbordan en `main`, fuera de
    alcance), con `Exceso de calor`. Comprobar que el rectángulo de la etiqueta queda entre 0 y el
    ancho.
  - CA-10: empezar con `Necesita agua`, `soilHumidity: 20`; cambiar a otro `SensorDataModel` con el
    mismo estado y otros valores; `pump()`; la etiqueta, la boca y el color de «Regar» siguen igual.
  - CA-11: `currentSensorData` nulo → «Según sensores: sin lecturas», boca feliz y «Regar» normal.
  - CA-12: con `Necesita agua`, `find.text('Buena')` no encuentra nada y la etiqueta es «Según
    sensores: Necesita agua».
  - **Final de cada prueba:** `await tester.pumpWidget(const SizedBox())` y
    `await tester.pump(const Duration(seconds: 10))`, para que termine el temporizador de parpadeo de
    `AnimatedPlantWidget`. Usar siempre `pump`, nunca `pumpAndSettle`, por las animaciones que se
    repiten.

## Riesgos y lo que no se puede verificar

- **Cambio de contrato.** El backend y la app deben salir juntos. Una app vieja con el backend nuevo
  lee `"Sana"` como estado desconocido, y su `isHealthy` falla con `health_score: null`. Una app
  nueva con el backend viejo muestra `Sin datos` (D5). Como todo va en un mismo pull request, no
  afecta a la entrega.
- **Cara feliz con `Sin datos`.** Puede leerse como «está bien». La etiqueta «sin lecturas» lo
  aclara. Una cara neutra nueva quedaría para después de la entrega.
- **Datos sembrados.** Con lecturas de suelo al azar entre 20 y 70, Nenúfares (mínimo 60) y Geranios
  (35) saldrán casi siempre «Necesita agua». Es lo esperado y no se toca `seed_data.py`.
- **Lectura vieja.** `/latest` puede usar una lectura de hace días como si fuera actual. Está fuera de
  alcance.
- **En vivo sin temperatura.** La rama en vivo exige `temperatura != null` (spec 003). Si el DHT11
  falla, la app usa la lectura guardada; CA-5 se cumple en el backend y en esa rama.
- **`plant_id` ajeno en `clima-actual`.** Ya pasaba antes de esta spec y no se arregla aquí, pero el
  estado de salud no se calcula para esa planta (CA-8).
- **Conflictos con la spec 005** en `sensor_data_model.dart` y `plant_detail_screen.dart` (D9).
- **Sensor real.** Que la lectura del ESP8266 dé el mismo estado en vivo y guardada solo se comprueba
  con la placa (CA-13, T8).
- **Cobertura.** El umbral de `backend/.coveragerc` no debe bajar. Se borran unas 40 líneas de
  `sensors.py` sin cubrir y se añade un servicio cubierto entero.

## Diferencias con lo planeado

- **Sin cambios de comportamiento** respecto de las decisiones del plan, ni en backend ni en la app.
  No se modificó ninguna prueba existente, ni el firmware, `seed_data.py` o
  `frontend/lib/config/api_constants.dart`; sin migraciones.
- **`AnimatedPlantWidget`:** un estado desconocido que llegue al widget también usa la cara feliz
  (el modelo ya convierte cualquier valor desconocido en `Sin datos`).
- **Etiqueta «Según sensores: …»:** el estilo (tamaño 16, peso 700, `SolarColors.primaryDark`) lo
  eligió `frontend-dev`; la spec no lo fijaba. Se revisa a mano en T8.
- **El resaltado de «Regar»** ya dependía de `needsWater`; no hizo falta tocarlo en la pantalla,
  solo cambió la definición de `needsWater` en el modelo.
- **Pruebas extra fuera de la tabla «Pruebas por criterio»** (`pruebas`): bordes de la regla
  (24,9 % de suelo, 35,1 °C, puntaje exactamente 40 y 39), un solo umbral nulo, valores en inglés
  del backend viejo tratados como `Sin datos` en modelo, provider y detalle, y `Buena` (valor del
  diagnóstico IA) tratado como `Sin datos` en la salud según sensores.
- **Tras la revisión (aprobada con observaciones)** se agregaron dos pruebas que faltaban, sin
  cambiar código: `test_regla_de_salud_limita_la_resta_por_temperatura_a_30` (obs. 1) y
  `la etiqueta Según sensores no se corta y hace salto de línea a 320 px` (obs. 2). Quedan abiertas
  las observaciones bajas: la tarjeta de humedad muestra «0 %» sin lectura de suelo (se deja a la
  spec 005) y `clima-actual` consulta dos veces la planta del ESP8266.
- **`flutter analyze` baja de 38 a 33 avisos:** desaparecen los cinco de código muerto del cálculo de
  salud que tenía `plant_provider.dart`.
- **Decisiones del plan que la responsable no tomó expresamente** (se siguió la propuesta del
  planificador): `Sin datos` usa la cara feliz existente; con un umbral de planta nulo se usan 30 y
  35; el texto del clima del detalle queda fijo en «Parcialmente nublado»; las claves nuevas de
  `clima-actual` son `health_status` y `health_score`; el puntaje no se muestra en ninguna pantalla.
