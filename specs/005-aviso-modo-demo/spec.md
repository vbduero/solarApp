# Spec 005 · Aviso de modo demo

- **Estado:** aprobada
- **Rama:** `feat/005-aviso-modo-demo`
- **Responsable:** Valentina Bermeo

## Qué se construye

La app deja de mostrar como reales datos que no lo son. Esto pasa de dos formas, y cada una se
trata por separado:

- **(a) Modo demo por falta de conexión.** Cuando la app no puede traer las plantas o las tareas
  del servidor, sigue enseñando las de ejemplo, pero ahora lo **avisa** con un aviso fijo en
  Inicio (con un botón «Reintentar») y en el detalle de una planta de ejemplo. El aviso desaparece
  cuando vuelven los datos reales. Sobre una planta o una tarea de ejemplo no se manda nada al servidor:
  regar, programar o completar una tarea, ver los diagnósticos y eliminar una planta dicen «No
  disponible en modo demo.». Las lecturas de sensores ya no se inventan nunca: si no llegan, se ve
  «Sin datos».
- **(b) Valores de relleno permanentes.** Lo que nunca es real, ni siquiera con conexión, se
  **quita** en lugar de etiquetarse:
  - el clima de la barra superior;
  - la fecha de fertilización inventada;
  - los textos fijos de Recomendaciones y Notificaciones;
  - el elemento «Panel Solar» del menú.

Es un cambio solo de la app: no toca ningún archivo de `backend/` ni
`frontend/lib/config/api_constants.dart` (decisión de la responsable, ver «Preguntas abiertas»).

## Por qué

`CLAUDE.md` dice que la luz, el voltaje solar y la batería son constantes de relleno y no deben
presentarse como lecturas reales. `.claude/rules/frontend-pantallas.md` pide además: «No muestres
datos inventados como si fueran reales […] si son de demostración, dilo en pantalla». Hoy la app no
cumple ninguna de las dos cosas. Nada en pantalla distingue un dato de ejemplo de uno real, y hay
pantallas enteras escritas a mano. Además, las plantas de ejemplo tienen los **mismos ids y nombres**
que las que siembra `backend/seed_data.py` (51-135; Echeveria es la 1 y, por ser la más antigua, es
también la planta del ESP8266). Por eso un «Regar» sobre la Echeveria de ejemplo puede llegar a la
bomba real si el servidor vuelve mientras la app sigue en modo demo.

### Inventario: (a) datos demo por falta de conexión

| # | Dónde | Cuándo se activa | ¿Queda marca? | ¿Se limpia al volver la conexión? |
|---|---|---|---|---|
| A1 | `frontend/lib/providers/plant_provider.dart` 48-64 (`loadPlants`) → `_loadDemoPlants` 309-372: cinco plantas (Echeveria, Áloe de arena, Nenúfares, Geranios, Hoja aplastada, ids 1-5) | **Cualquier** excepción: sin red, 401, 500 o JSON inválido. `ApiService._handleResponse` (`frontend/lib/services/api_service.dart` 171-181) lanza `ApiException` con cualquier código que no sea 2xx, y el `catch (e)` de 57 no distingue | `_isDemoMode` (19, 56, 310) se pone a `true`, pero **no tiene getter** y nadie lo lee (`flutter analyze` lo marca como campo sin usar, `specs/001-estadisticas-reales/revision.md` 15) | Solo si se vuelve a llamar a `loadPlants`, cosa que hace únicamente `initState` de Inicio (`frontend/lib/screens/home/home_screen.dart` 38-48). No hay «Reintentar» ni se puede tirar hacia abajo para recargar: la persona se queda en modo demo hasta salir de Inicio |
| A2 | `frontend/lib/providers/task_provider.dart` 33-49 (`loadTodayTasks`) → `_loadDemoTasks` 133-197: cinco tareas (Regar, Fertilizar, Trasplantar…) de las plantas 1 y 2, cuatro de ellas «Atrasada» | Cualquier excepción, igual que A1 | **Ninguna** | Igual que A1. `loadUpcomingTasks` (52-65) no carga demo, pero si falla **conserva la lista anterior** |
| A3 | `plant_provider.dart` 193-201 (`loadSensorData`) → `SensorDataModel.demo` (`frontend/lib/models/sensor_data_model.dart` 86-102): 26 °C, aire 65 %, suelo 50 %, luz 67, voltaje 15,5 y batería 85 | Cualquier excepción de `GET /api/sensors/latest/{id}`, también con una **planta real** y la sesión iniciada. El detalle refresca cada 3 s (`frontend/lib/screens/plant/plant_detail_screen.dart` 43-53), así que basta un corte breve | Ninguna. Desde la spec 004 solo se ve «Según sensores: sin lecturas», pero las tarjetas muestran 50 % y 26 °C como si fueran reales | Sí: el siguiente refresco que sale bien la reemplaza |
| A4 | `plant_detail_screen.dart` 214-216: `currentSensorData ?? SensorDataModel.demo(...)` | Antes de la primera respuesta | Ninguna | Al llegar la primera respuesta |
| A5 | `frontend/lib/providers/auth_provider.dart` 168-180 (`enterDemoMode`): usuario «Agricultor Solar», `demo@solargrow.com`, Neiva, **sin token**. Se entra con «Modo Demo (sin servidor)» (`frontend/lib/screens/auth/login_screen.dart` 288-307, `frontend/lib/screens/auth/register_screen.dart` 80-81 y 402-422) | Lo elige la persona | `isAuthenticated` vale `true`, como con una sesión real | — Después, todas las peticiones salen sin token, responden 401 o fallan, y entran A1-A3 |
| A6 | Cierre de sesión (`home_screen.dart` 1093-1099 → `AuthProvider.logout` 116-121) | — | — | `logout` solo borra el token y el usuario. `PlantProvider` y `TaskProvider` son globales (`frontend/lib/main.dart` 62-66) y **conservan** plantas, planta elegida, lectura, tareas y `_isDemoMode` de la sesión anterior. Las próximas tareas de otra cuenta pueden seguir visibles si su carga falla (A2) |

`tryAutoLogin` (`auth_provider.dart` 25-43) borra el token y lleva al login ante cualquier fallo de
`/api/auth/me`. Por eso, con el servidor caído al abrir la app, solo se llega a Inicio por A5. A1-A3
se ven, sobre todo, cuando el servidor se cae **después** de iniciar sesión.

**Qué hacen hoy las acciones en modo demo:**

| Acción | Resultado hoy | ¿Finge éxito? |
|---|---|---|
| «Regar» (`plant_detail_screen.dart` 62-118 → `PlantProvider.activateWatering` 247-266) | Hace la petición. Si falla, muestra un SnackBar con el error. **Si el servidor volvió y hay token, riega la planta 1 real**, que es la del ESP8266 | No, pero puede regar de verdad |
| «Detener riego» | Solo aparece con `livePumpOn`, que en demo vale `null` (spec 003) | No aparece |
| «Programar tarea» (`frontend/lib/widgets/create_task_sheet.dart` 83, 164) | Hace la petición. Si falla: «No se pudo programar la tarea…» | No |
| Completar tarea (`frontend/lib/screens/home/tasks_tab.dart` 232-244) | Hace la petición. Si falla: «No se pudo completar la tarea…» | No |
| **Eliminar planta** (`frontend/lib/screens/home/my_plants_tab.dart` 289-296) | No mira el resultado de `deletePlant` y muestra «*X* eliminada» **siempre**. La tarjeta desaparece aunque la planta siga en la lista | **Sí** |
| Diagnóstico IA (`home_screen.dart` 56-176) | Muestra la tarjeta de error con el texto de la excepción | No |
| Editar perfil (`frontend/lib/screens/profile/edit_profile_screen.dart` 60-98) | Muestra el error. Además, `updateProfile` deja `status = error` (`auth_provider.dart` 142-146), y eso pone `isAuthenticated` en `false` | No |

### Inventario: (b) valores de relleno permanentes

| # | Dónde | Qué muestra | Real o no |
|---|---|---|---|
| B1 | `WeatherBar` (`frontend/lib/widgets/weather_bar.dart` 13-18, 37) en Inicio (`home_screen.dart` 773-780) | «Neiva, Parcialmente nublado 26°C» | El texto y los 26 °C son fijos. No hay ninguna fuente de clima. La ciudad sí es la del usuario |
| B2 | `WeatherBar` en el detalle (`plant_detail_screen.dart` 231-238) | «Parcialmente nublado» fijo (lo dejó así la spec 004, D8) y **la temperatura del sensor de la maceta** como si fuera la de la ciudad (26 si no hay) | Inventado y engañoso |
| B3 | Tarjetas del detalle (`plant_detail_screen.dart` 373-477) | Humedad `${soilHumidity?.round() ?? 0} %` (414) y temperatura `${temperature?.round() ?? 0} °C` (464) | Sin lectura se ve **«0 %» y «0 °C»**. «0 %» se lee como tierra seca (obs. 3 de `specs/004-calculo-unico-salud/revision.md`). El comentario de 278 dice «Humedad y Luz solar», pero **no hay tarjeta de luz**: son humedad y temperatura |
| B4 | «Fertilizar:» del detalle (`plant_detail_screen.dart` 511-514) | `nextFertilizeDate` o, si no hay, **«26 de Junio»** | `seed_data.py` no rellena `next_fertilize_date` y nada en la app lo pide, así que **todas las plantas reales** muestran esa fecha inventada |
| B5 | Caja «Lecturas del ESP8266» del diálogo de Diagnóstico IA (`home_screen.dart` 589-691) | Rellenos `"25.0"` °C (640), `"50.0"` % de suelo (646) y `"50.0"` % de aire (652) cuando falta un dato | Inventado |
| B6 | Luz, voltaje y batería en la app | En vivo, `plant_provider.dart` 166-168 los fija en 85, 12,4 y 98; `demo()` los fija en 67, 15,5 y 85. En vivo también salen `temperatura ?? 26.0` (154) y `humedad_aire ?? humedad ?? 50.0` (155-156) | **Ninguna pantalla los muestra hoy** (búsqueda de `lightLevel`, `solarVoltage` y `batteryLevel` en `frontend/lib/screens` y `frontend/lib/widgets`: sin resultados). `SensorCard` (`frontend/lib/widgets/sensor_card.dart`) se importa en el detalle, pero no se usa en ninguna parte. Son inventados en el modelo, no en pantalla |
| B7 | `frontend/lib/screens/recommendations/recommendations_screen.dart` 13-81 | Seis tarjetas fijas. Entre ellas, «Estado general: Bueno (87% confianza)» (65), «tracking solar… 67% de exposición» (32), «panel solar de 20W… 12.8W… Batería al 85%» (75-77) y la humedad de la Echeveria «por debajo del 30%» (21) | Todo inventado. No llama a ningún endpoint. `GET /api/ai/recommendations/{plant_id}` existe (`backend/app/routers/ai.py` 19-44), pero la app no lo usa |
| B8 | `frontend/lib/screens/notifications/notifications_screen.dart` 13-60 | Seis notificaciones fijas: suelo al 27 %, 32 °C, «batería del sistema solar está al 100%», «87% confianza», «Tracking solar optimizado»… con horas inventadas («Hace 30 min») | Todo inventado. No hay endpoint de notificaciones. «Marcar todas» (72-78) no hace nada |
| B9 | Menú lateral, «Panel Solar» (`home_screen.dart` 1045-1052) | Solo cierra el menú | No hay panel solar (`CLAUDE.md`) |
| B10 | `backend/app/routers/controls.py` 108-140, `GET /api/controls/status/{plant_id}` | `pump_active: false` fijo, `solar_tracker` con ángulos 0 y `tracking_active: true`, y `battery` con 85 % y `charging: true` | Todo inventado. **Ni la app ni ninguna prueba lo usan**: solo está declarado como `controlStatus` (`frontend/lib/config/api_constants.dart` 31). Sus líneas son las que quedan sin cubrir en `controls.py` (`specs/003-detener-riego/revision.md` 120) |
| B11 | `backend/app/routers/ai.py` 74-101, `POST /api/ai/request-diagnosis/{plant_id}` | `success: true`, «La Raspberry Pi está capturando y analizando la imagen», `estimated_time_seconds: 30` | No hace nada. Es éxito fingido, contra `.claude/rules/backend-routers.md` («Nunca devuelvas éxito sin haberlo enviado»). Ni la app ni ninguna prueba lo usan: solo está declarado como `aiRequestDiagnosis` (`api_constants.dart` 36). El diagnóstico real es `GET /api/hardware/diagnostico-ia` |
| B12 | `backend/app/main.py` 67-83, `GET /` | `"hardware"`: «Raspberry Pi 4 (4GB)», «Cámara Módulo 3 Raspberry», «ESP32», «DHT22», «LDR», «Servomotores tracking solar», «Panel solar 20W + Batería recargable» | Inventado. El hardware real es un ESP8266 NodeMCU con DHT11 (`esp8266_maceta_inteligente/esp8266_maceta_inteligente.ino` 9 y 39), sensor de humedad del suelo, bomba, la webcam del PC y Gemini. Ninguna prueba usa `GET /` |
| B13 | `backend/app/utils/hardware_helper.py` 280-283 (`_guardar_datos_en_db`) | Guarda en cada lectura del ESP8266 `light_level=85.0`, `solar_voltage=12.4`, `solar_power=8.0` y `battery_level=95.0` | Inventado. Viaja como lectura en `GET /api/sensors/latest/{id}` (`backend/app/schemas/sensor_data.py` 59-61), pero ninguna pantalla lo muestra (B6) y desde la spec 004 no cuenta para la salud. `seed_data.py` 147-155 guarda valores al azar |
| B14 | `hardware_helper.py` 17-25 (`LATEST_DATA` inicial: 25 °C, aire 50 %, suelo 50 %) devueltos por `GET /api/hardware/clima-actual` con el ESP8266 desconectado | — | La app ya los ignora: exige «En línea» (`plant_provider.dart` 146-149), y la spec 004 no calcula salud con ellos (CA-8). **Hoy no se ven** |
| B15 | Textos de Raspberry Pi, ESP32, MQTT, DHT22 y LDR en docstrings y comentarios: `ai.py` 28-29 y 55-56, `controls.py` 48 y 127, `backend/app/models/sensor_data.py` 13-14, 21, 28 y 46, `backend/app/models/recommendation.py` 24 y 44, `backend/app/schemas/sensor_data.py` 12 y 25, `backend/app/routers/sensors.py` 127, `hardware_helper.py` 88, `backend/app/config.py` 26-33 (`MQTT_*`) y el comentario de `plant_provider.dart` 187 | — | No se ven en la app. Solo confunden a quien lee el código |
| B16 | `frontend/lib/screens/plant/plant_info_screen.dart` 158, 164 y 170 | «Fácil», «Regular» y «Parcial» cuando la planta no trae esos datos | Inventado, pero es ficha botánica, no lectura |

### Lo que heredan las specs 001-004

| De | Qué dejó para esta spec | Dónde queda aquí |
|---|---|---|
| 001 `spec.md` 37-38, `plan.md` 208-210 | Luz, voltaje y batería de otras pantallas, y las plantas demo de `PlantProvider` | B6 (no se muestran; se deja de inventarlos en la app, CA-14) y A1 (CA-1 a CA-5) |
| 001 `spec.md` 45 | El elemento «Panel Solar» del menú | B9 → CA-19 |
| 001 `spec.md` 39-40, `plan.md` 200-204 | Las lecturas al azar de `seed_data.py` | Fuera de alcance (no se toca `seed_data.py`) |
| 002 `spec.md` 39-42 y 56-58 | Recomendaciones y su «87% confianza», `POST /api/ai/request-diagnosis` y los textos de Raspberry Pi | B7 → CA-17. B11, B12 y B15 quedan fuera (sin backend en esta spec) |
| 003 `spec.md` 48-49 y 73-74 | `GET /api/controls/status/{plant_id}` y el aviso de modo demo | A1-A3 → CA-1 a CA-11. B10 queda fuera (sin backend en esta spec) |
| 003 `revision.md`, obs. 3 y 5 | `_plants.first` con lista vacía en la rama demo, y `ApiService` sin tiempo límite | La rama demo de las lecturas desaparece (CA-11). El tiempo límite queda fuera |
| 003 `revision.md`, obs. 7 | Comentarios «MQTT»/«ESP32» en `controls.py` 48 y 127 | Fuera (B15, sin backend en esta spec) |
| 004 `spec.md` 102-106 y `plan.md` D9 | Números de `demo()`; usar o no `demo()` y el aviso; constantes de luz, voltaje y batería del provider y de `hardware_helper.py`; el `?? 50.0` del aire; los rellenos «25.0»/«50.0» de Inicio; `WeatherBar`; `GET /api/controls/status` | `demo()` deja de usarse (CA-11, CA-12); provider (CA-14); rellenos de Inicio (CA-13); `WeatherBar` (CA-15). `hardware_helper.py` y `/status` quedan fuera |
| 004 `plan.md` D8, «Diferencias» | El clima del detalle quedó fijo en «Parcialmente nublado» a la espera de esta spec | CA-15 |
| 004 `revision.md`, obs. 3 | La tarjeta de humedad muestra «0 %» sin lectura de suelo | CA-12 |
| 004 `revision.md`, obs. 5 | `clima-actual` consulta dos veces la planta del ESP8266 | Fuera de alcance (no es un dato inventado) |

### Pruebas existentes que dependen de los datos demo

- `frontend/test/sensor_health_model_test.dart` 163-170 (`demo trae Sin datos y puntaje null`) y
  `frontend/test/plant_detail_health_test.dart` 484-494 (`lectura demo (API caído)…`) construyen
  `SensorDataModel.demo`. Como las lecturas demo desaparecen (decisión 2), **cambian**. El plan
  dice exactamente cómo.
- `frontend/test/plant_provider_stop_watering_test.dart` 147-158 y
  `frontend/test/plant_provider_health_test.dart` 397-425 esperan que, cuando el API falla,
  `currentSensorData` **no sea nulo** y valga `Sin datos`. Siguen valiendo sin cambios, porque tras
  el fallo queda una lectura vacía (plan, D5).
- `frontend/test/plant_detail_overflow_test.dart`, `plant_detail_diagnoses_button_test.dart`,
  `plant_detail_stop_watering_test.dart` y la CA-11 de `plant_detail_health_test.dart` montan el
  detalle con `currentSensorData` nulo, así que hoy pasan por el respaldo `demo()` de A4. No
  comprueban números de lectura.
- **No hay ninguna prueba** de `_loadDemoPlants`, `_loadDemoTasks`, `enterDemoMode`, `logout`,
  `WeatherBar`, Recomendaciones, Notificaciones, el menú lateral (salvo
  `frontend/test/stats_screen_test.dart` 165, que comprueba que Estadísticas no muestra «Panel
  Solar»), `GET /api/controls/status`, `POST /api/ai/request-diagnosis` ni `GET /`.

## Fuera de alcance

- **Eliminar los endpoints fingidos `GET /api/controls/status/{plant_id}` y
  `POST /api/ai/request-diagnosis/{plant_id}` (B10, B11) y sus constantes `controlStatus` y
  `aiRequestDiagnosis`.** Era la CA-20 del borrador. Quitarlos obliga a tocar
  `frontend/lib/config/api_constants.dart`, que tiene la IP local de la responsable sin subir.
  Ningún archivo de la app los usa, así que su efecto en pantalla es nulo. Decisión de la
  responsable.
- **Corregir el hardware inventado de `GET /`** (`backend/app/main.py` 67-83, B12). Era la CA-21 del
  borrador. Esta spec no toca el backend: decisión de la responsable.
- **Conectar Recomendaciones a `GET /api/ai/recommendations/{plant_id}`.** Haría falta elegir planta,
  definir estados de carga y error y probarlo. Esta spec solo quita lo inventado (CA-17).
- **Notificaciones reales.** No existe backend para ellas.
- **Lo que guarda el backend en luz, voltaje, potencia y batería** (`hardware_helper.py` 280-283,
  B13), y las columnas `light_level`, `solar_voltage`, `solar_power`, `battery_level`, `servo_angle_*`
  de `sensor_data`. Ese código solo corre con la placa y ninguna pantalla muestra esos valores
  (decisión 8).
- **Docstrings, comentarios y ajustes con Raspberry, ESP32, MQTT, DHT22 o LDR** (B15), incluidos los
  `MQTT_*` y `RASPBERRY_*` de `config.py`, el `source="esp32"` por defecto y el comentario de
  `plant_provider.dart` 187. No se ven en la app.
- **Los valores por defecto de la ficha botánica** «Fácil», «Regular» y «Parcial» de
  `plant_info_screen.dart` (B16).
- **El título «Lecturas del ESP8266»** de la caja del diálogo de Diagnóstico IA (`home_screen.dart`
  624). Muestra la lectura de la última planta abierta, que puede no ser la del ESP8266. Solo se
  quitan sus rellenos (CA-13).
- **Mandar al login ante un 401.** Con esta spec, un 401 se trata igual que un servidor caído
  (decisión 3).
- **Un tiempo límite en `ApiService`** (obs. 5 de la revisión de la spec 003).
- **Que un `updateProfile` fallido deje `isAuthenticated` en `false`** (`auth_provider.dart` 142-146).
- **Un aviso propio en Información de la planta, Estadísticas y Agregar planta.** Estadísticas ya
  muestra un error sin datos inventados (spec 001).
- **Quitar el botón «Modo Demo (sin servidor)»**, «Configuración», «Ayuda» o «Continuar con Google»
  (`register_screen.dart` 353-363, sin implementar). No muestran datos inventados.
- **Los emojis del logo del splash** (`frontend/lib/screens/splash_screen.dart` 118-126): son
  decorativos.
- **La doble consulta de `clima-actual`** (obs. 5 de la revisión de la spec 004) y las observaciones
  pendientes de la spec 003 (obs. 2, 4 y 9).
- **`backend/seed_data.py`, `database/init.sql`, el firmware y `baseUrl`/`webBaseUrl`** de
  `api_constants.dart`.

## Criterios de aceptación

En las pruebas automáticas no se usan HTTP, PostgreSQL, el ESP8266, la webcam ni Gemini reales.
«Planta de ejemplo» y «tarea de ejemplo» son las que la app carga cuando falla el servidor.
«Planta real» es una que llegó del servidor. Los textos entre comillas son exactos y son los que
aprobó la responsable (decisión 10).

Numeración: el borrador tenía 24 criterios. La CA-20 (endpoints fingidos) y la CA-21 (`GET /`)
salieron del alcance (ver «Fuera de alcance»), y los tres criterios comunes se renumeraron como
CA-20, CA-21 y CA-22.

### (a) Modo demo por falta de conexión

- **CA-1. Aviso en Inicio.** Dado un usuario en Inicio, cuando al cargar las plantas el servidor
  no responde, responde 401 o responde 500, entonces se ven las plantas de ejemplo y, encima de las
  pestañas, el aviso «Modo demo: no se pudo conectar con el servidor. Las plantas y tareas que ves
  son de ejemplo.» con un botón «Reintentar». El aviso sigue visible en «Mis Plantas» y en
  «Tareas».
- **CA-2. Basta con que fallen las tareas.** Dadas plantas reales cargadas sin error, cuando falla
  la carga de las tareas de hoy y se muestran las de ejemplo, entonces se ve el mismo aviso de CA-1.
- **CA-3. Caso normal.** Dado que las plantas y las tareas de hoy cargan bien, entonces no aparece
  ningún aviso de modo demo en Inicio ni en el detalle.
- **CA-4. Sin datos no es modo demo.** Dado un usuario sin plantas ni tareas (el servidor responde
  200 con listas vacías), entonces Inicio no muestra plantas ni tareas de ejemplo ni el aviso.
- **CA-5. Vuelve la conexión.** Dado el aviso de CA-1 visible, cuando se toca «Reintentar» y ahora
  el servidor responde bien, entonces las plantas y tareas de ejemplo se sustituyen por las reales
  y el aviso desaparece. Si vuelve a fallar, siguen las de ejemplo con un solo aviso.
- **CA-6. Detalle de una planta de ejemplo.** Dada una planta de ejemplo, cuando se abre su detalle,
  entonces se ve el aviso «Modo demo: esta planta es de ejemplo y no tiene lecturas reales.».
  Humedad y temperatura muestran «Sin datos», y la etiqueta de la spec 004 dice «Según sensores: sin
  lecturas». **No se pide ninguna lectura al servidor para esa planta**, ni al abrirla ni en el
  refresco de 3 s.
- **CA-7. Las acciones sobre ejemplos no se envían ni fingen éxito.**
  - Dada una planta de ejemplo, al tocar «Regar», «Programar tarea» o «Diagnósticos», o al deslizar
    para eliminarla y confirmar, se ve el SnackBar «No disponible en modo demo.» y **no se envía
    ninguna petición**. No se abre el formulario de la tarea ni el historial de diagnósticos.
  - Lo mismo pasa al completar una tarea de ejemplo.
  - Mientras Inicio muestra el aviso de CA-1, «Diagnóstico IA / Cámara En Vivo» del menú también
    responde «No disponible en modo demo.» y no abre el diálogo: el diagnóstico se guardaría en la
    planta real del ESP8266.
  - En ningún caso aparece «¡Riego completado exitosamente!», «Tarea programada», «*nombre*
    eliminada» ni «Detener riego». La planta o la tarea siguen en su lista.
  - El bloqueo depende de que la planta o la tarea **sea de ejemplo**, no de su id. Una planta real
    con el mismo id que una de ejemplo (por ejemplo, la Echeveria 1 sembrada) se riega con
    normalidad.
- **CA-8. Eliminar una planta real que falla.** Dada una planta real, cuando se confirma su
  eliminación y el servidor responde con error o no responde, entonces se ve «No se pudo eliminar la
  planta. Intenta de nuevo.», la planta sigue en la lista y no aparece «*nombre* eliminada». Si el
  servidor la elimina, se ve «*nombre* eliminada», como hoy.
- **CA-9. Cerrar sesión no arrastra nada.** Dado un usuario que vio plantas, tareas o lecturas
  (reales o de ejemplo, con o sin el aviso), cuando cierra sesión e inicia otra, entonces antes de
  que lleguen los datos nuevos no se ve nada de la sesión anterior: ni plantas, ni tareas de hoy o
  próximas, ni lecturas, ni el aviso. Si los datos nuevos cargan bien, no hay aviso.
- **CA-10. Botón «Modo Demo (sin servidor)».** Dado el login, cuando se toca «Modo Demo (sin
  servidor)», entonces Inicio muestra las plantas y tareas de ejemplo con el aviso de CA-1.

### Lecturas de sensores: nunca inventadas

- **CA-11. Fallan las lecturas de una planta real.** Dada una planta real en el detalle, cuando la
  petición de lecturas falla (sin red, 401 o 500), entonces humedad y temperatura muestran «Sin
  datos». Nunca muestran 50 %, 26 °C, «0 %» ni «0 °C». Se ve «Sin conexión con el servidor: no se
  pueden mostrar las lecturas.» y la etiqueta «Según sensores: sin lecturas». Cuando el siguiente
  refresco trae una lectura, ese texto desaparece y se ven los valores reales. El aviso de modo demo
  de CA-6 **no** aparece, porque la planta es real.
- **CA-12. Planta sin lecturas o lectura incompleta.** Dada una planta real sin lecturas (el servidor
  responde 200 con las lecturas en `null`), entonces humedad y temperatura muestran «Sin datos» y no
  aparece el texto «Sin conexión…» de CA-11. Dada una lectura con temperatura 24 y sin humedad del
  suelo, se ve «24 °C» y la humedad muestra «Sin datos», no «0 %». Antes de la primera respuesta
  también se ve «Sin datos».
- **CA-13. Caja de lecturas del Diagnóstico IA.** Dada la caja «Lecturas del ESP8266» del diálogo de
  Diagnóstico IA, cuando falta la temperatura, la humedad del suelo o la del aire, entonces ese valor
  se ve como «Sin datos». Nunca como «25.0°C» ni «50.0%».
- **CA-14. La app no inventa luz, voltaje ni batería.** Dada una lectura en vivo de `clima-actual`
  (ESP8266 «En línea» en esa planta), entonces la lectura que guarda la app tiene luz, voltaje solar
  y batería vacíos (`null`), no 85, 12,4 ni 98. Si `clima-actual` no trae la humedad del aire,
  queda vacía y no vale 50. La salud y `livePumpOn` (specs 003 y 004) no cambian.

### (b) Valores de relleno permanentes

- **CA-15. Sin clima inventado.** Dados Inicio y el detalle de cualquier planta, entonces no se ven
  «Parcialmente nublado», «Parcialmente soleado» ni una temperatura de la ciudad. La temperatura del
  sensor solo aparece en su tarjeta.
- **CA-16. Fecha de fertilización.** Dada una planta sin `next_fertilize_date`, el detalle muestra
  «Fertilizar: Sin fecha», nunca «26 de Junio». Con fecha, la muestra como hoy (por ejemplo, «Fertilizar: 3
  de Diciembre»).
- **CA-17. Recomendaciones.** Al abrir Recomendaciones (barra inferior) se ve «Todavía no hay
  recomendaciones automáticas.» y debajo «Para revisar una planta, usa el Diagnóstico IA del menú o
  el historial de Diagnósticos de la planta.». No aparece ninguna de las seis tarjetas fijas, ni
  «87%», «panel solar», «Batería», «tracking» o «Raspberry».
- **CA-18. Notificaciones.** Al abrir Notificaciones se ve «Todavía no hay notificaciones.». No
  aparece ninguna de las seis notificaciones fijas ni el botón «Marcar todas».
- **CA-19. Menú lateral.** Al abrir el menú de Inicio, no aparece «Panel Solar». Los demás elementos
  siguen igual.
### Comunes

- **CA-20. Nada se desborda.** A 320 y 360 px de ancho, el aviso de CA-1 con «Reintentar», el aviso
  de CA-6, el texto de CA-11, las tarjetas con «Sin datos» de CA-11 y CA-12, «Fertilizar: Sin fecha»,
  la caja de CA-13 y los textos de CA-17 y CA-18 se ven enteros: sin error de desborde y sin texto
  cortado. El salto de línea está permitido. Los colores salen de `SolarColors`.
- **CA-21. Las specs anteriores no se rompen.** Siguen pasando las pruebas de las specs 001 a 004,
  salvo las dos que construyen `SensorDataModel.demo` (ver «Pruebas existentes que dependen de los
  datos demo»). Esas cambian solo en lo que esta spec cambia, y el plan lo declara. No se modifica
  ningún archivo de `backend/` ni `frontend/lib/config/api_constants.dart`.

**Verificación manual (Chrome y emulador):**

- **CA-22. De punta a punta.** Con el backend encendido, se inicia sesión con
  `demo@solargrow.com`: no hay aviso. Se abre la Echeveria y se apaga `uvicorn`. En 3-6 s, las
  tarjetas pasan a «Sin datos» y aparece «Sin conexión…». Se vuelve a Inicio, se cierra sesión y se
  entra con «Modo Demo (sin servidor)»: aparece el aviso de CA-1, y «Regar» sobre la Echeveria de
  ejemplo dice «No disponible en modo demo.». Se enciende `uvicorn`, se cierra sesión y se inicia
  sesión de nuevo: no hay aviso y se ven los datos reales. En los registros de `uvicorn` no aparece
  ningún `POST /api/controls/water` durante la prueba.

## Preguntas abiertas

- Ninguna. La responsable (Valentina Bermeo) aprobó la spec el 2026-11-12, con alcance reducido,
  mediante el diálogo de preguntas de la sesión principal. Estas son sus decisiones:
  1. **Plantas y tareas de ejemplo.** Se mantienen cuando falla el servidor, con el aviso de CA-1 y
     «Reintentar». Hacen falta para el botón «Modo Demo (sin servidor)» y para presentar sin
     servidor.
  2. **Lecturas de `SensorDataModel.demo`.** Se quitan. Sin lectura se ve «Sin datos» y, si falló
     el servidor, «Sin conexión con el servidor: no se pueden mostrar las lecturas.» (CA-11, CA-12).
     Las dos pruebas existentes que construyen `demo()` cambian.
  3. **401 y 500** se tratan igual que la falta de red (CA-1). Mandar al login ante un 401 queda
     fuera.
  4. **Acciones sobre plantas y tareas de ejemplo.** Se bloquean con «No disponible en modo demo.»,
     sin enviar nada al servidor (CA-6, CA-7), porque los ids de ejemplo coinciden con los sembrados
     y la planta 1 es la del ESP8266. Eliminar una planta real que falla deja de decir que salió
     bien (CA-8).
  5. **Barra del clima.** Se quita de Inicio y del detalle (CA-15).
  6. **Recomendaciones y Notificaciones** pasan a pantalla vacía honesta, sin contenido inventado y
     sin «Marcar todas» (CA-17, CA-18).
  7. **Alcance reducido: solo la app.** Eliminar los endpoints fingidos y sus constantes y corregir
     `GET /` quedan fuera. Obligarían a tocar `api_constants.dart`, que tiene la IP local, y el
     backend. Esta spec no modifica ningún archivo de `backend/` ni `api_constants.dart`.
  8. **Luz, voltaje y batería.** Solo se dejan de inventar en la app (CA-14). `hardware_helper.py`
     queda fuera.
  9. (Era la corrección de `GET /`: queda fuera, ver decisión 7.)
  10. **Textos.** Son los propuestos y los que figuran en los criterios:
      - «Modo demo: no se pudo conectar con el servidor. Las plantas y tareas que ves son de
        ejemplo.» y el botón «Reintentar»;
      - «Modo demo: esta planta es de ejemplo y no tiene lecturas reales.»;
      - «Sin conexión con el servidor: no se pueden mostrar las lecturas.»;
      - «No disponible en modo demo.»;
      - «Sin datos»;
      - «Fertilizar: Sin fecha»;
      - «No se pudo eliminar la planta. Intenta de nuevo.»;
      - los de CA-17 y CA-18.

  La extensión del bloqueo a «Diagnósticos» de una planta de ejemplo y a «Diagnóstico IA / Cámara
  En Vivo» en modo demo (CA-7) aplica la decisión 4 a las dos acciones de diagnóstico, que la sesión
  principal incluyó en la lista de acciones que hay que bloquear.
