# Plan · Spec 003

## Lo que se comprobó en el código antes de planear

- **Firmware** (`esp8266_maceta_inteligente/esp8266_maceta_inteligente.ino`, solo lectura). Entiende
  dos comandos: `WATER:<s>` (máximo 60 s) y `STOP`, que apaga el riego manual y el automático. El
  `loop` no se bloquea. Cuando la bomba cambia de estado imprime enseguida «BOMBA ENCENDIDO» o «BOMBA
  APAGADO», y repite el estado cada 2 s. **No hace falta tocarlo.**
- **`backend/app/routers/controls.py`.**
  - `POST /api/controls/water` y `POST /api/controls/stop-water` reciben `WaterControlRequest`
    (`plant_id` y `duration_seconds`, este con valor por defecto 10 y rango de 1 a 60). Buscan la
    planta con `Plant.id` y `Plant.user_id`, **sin `is_active`**, y responden 404 «Planta no
    encontrada» si no existe.
  - Después llaman a `enviar_comando_serial` (importada en el módulo del router) con `WATER:<s>` o
    `STOP`. Si devuelve `False`, responden 503 con mensajes en español. Ninguno de los dos mira la
    planta del ESP8266.
  - El módulo guarda `settings = get_settings()` al importarse. Es el mismo objeto cacheado que
    devuelve `get_settings()`, así que `monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", ...)`
    también lo cambia.
  - `stop-water` responde `{"success": True, "message": "Riego detenido para <nombre>"}` sin
    `response_model`.
- **`backend/app/services/hardware_service.py`.** Ya existen `get_device_plant(db, configured_plant_id)`
  (solo plantas activas; con id configurado no cae en otra planta) y
  `get_device_plant_for_user(db, configured_plant_id, user_id)`. Las dos tienen pruebas en
  `backend/tests/test_hardware_service.py`.
- **`backend/app/utils/hardware_helper.py`.** `enviar_comando_serial` devuelve `True` en cuanto
  escribe en el puerto. `LATEST_DATA["led_encendido"]` y `LATEST_DATA["status_conexion"]` los
  actualiza el hilo serial. `GET /api/hardware/clima-actual` (`routers/hardware.py`) los expone como
  `led_encendido`, `estado_conexion` y `plant_id` (el de la planta del ESP8266).
- **`backend/app/config.py`.** `Settings` lee `.env` desde el directorio de trabajo. Al correr pytest
  desde `backend\`, un `ESP8266_PLANT_ID` del `.env` local afecta a las pruebas. En la CI no hay
  `.env`, así que vale `None`.
- **`backend/tests/test_seguridad_hardware.py`.**
  - Fixtures `auth_client`, `anonymous_client` y `serial_commands` (este último sustituye
    `controls.enviar_comando_serial` y registra los comandos).
  - Pruebas de riego: `test_riego_rechaza_duracion_fuera_de_rango`, `test_riego_acepta_los_limites`,
    `test_stop_water_envia_stop_al_esp8266`, `test_stop_water_sin_esp8266_devuelve_503` y
    `test_stop_water_de_planta_ajena_devuelve_404`.
  - Ninguna fija `ESP8266_PLANT_ID`. Con `None`, `plant` es la planta del ESP8266 porque es la activa
    más antigua, y siguen dando 200 o 503 tras el cambio.
  - Con un `.env` local que tenga `ESP8266_PLANT_ID` distinto del id de `plant` (en SQLite empieza en
    1), las de 200 y 503 pasarían a dar 409. Ver D8.
- **`backend/tests/conftest.py`.** Da `db`, `user`, `other_user`, `plant` y `other_plant`, con SQLite
  en memoria que se recrea en cada prueba.
- **`frontend/lib/config/api_constants.dart`.** En `main` ya existe
  `controlStopWater = '/api/controls/stop-water'`, sin `/` final. **No hace falta tocar el archivo.**
  `clima-actual` se usa como texto suelto en `plant_provider.dart`; eso queda como está.
- **`frontend/lib/providers/plant_provider.dart`.**
  - `activateWatering(int plantId, {int durationSeconds = 10}) -> Future<bool>`: en una
    `ApiException` guarda `_error = e.message` (el `detail` del backend); en cualquier otro error,
    `'No se pudo conectar con el servidor para activar el riego'`.
  - `loadSensorData(int plantId)`: primero llama a `clima-actual`. Usa el hardware solo si
    `estado_conexion == 'En línea'`, `plant_id == plantId` y `temperatura != null`, y en ese caso
    `pumpActive = led_encendido`. La rama de hardware usa `_plants.firstWhere(..., orElse: _plants.first)`,
    que lanza un error con `_plants` vacío y entonces cae a la base. Si no usa el hardware, toma
    `/api/sensors/latest/{id}` (el `pump_active` guardado) y, si eso falla, `SensorDataModel.demo`
    (`pumpActive: 0`). No tiene contador de petición.
  - `selectPlant` asigna la planta y llama a `loadSensorData`. Es un provider global: `logout()` no lo
    limpia.
- **`frontend/lib/services/api_service.dart`.** `post` lanza `ApiException(statusCode, message)`, y
  `message` es el `detail` del JSON de error.
- **`frontend/lib/screens/plant/plant_detail_screen.dart`.**
  - `_isWatering` se pone en `true` al tocar «Regar» y vuelve a `false` si falla o tras
    `Future.delayed(10 s)`, que además muestra el SnackBar «¡Riego completado exitosamente!».
  - El temporizador de 3 s solo arranca si `AuthProvider.isAuthenticated`.
  - `_buildCircleButton(icon, label, color, isHighlighted, onTap, isLoading)` envuelve cada botón en
    `Flexible` y la etiqueta en `FittedBox`.
  - `AnimatedPlantWidget` usa `isWatering: _isWatering || pumpActive == 1` y deja un temporizador de
    parpadeo de 2,5 a 5,5 s.
- **Pruebas de frontend que sirven de patrón:**
  - `plant_detail_diagnoses_button_test.dart`: `FakePlantProvider` con `selectedPlant` fijo y
    `loadSensorData` sin red, `AuthProvider()` sin sesión, `pump()` y, al final, desmontar con
    `pumpWidget(SizedBox())` y luego `pump(10 s)`.
  - `plant_detail_overflow_test.dart`: anchos de 320 y 360 px y `FlutterError.onError` que tolera solo
    desbordes de otras filas.
  - `diagnosis_route_test.dart`: `http.runWithClient` con `MockClient` y
    `SharedPreferences.setMockInitialValues({})`.

## Decisiones técnicas

- **D1 · Reglas de planta controlable, en el servicio.** Se agregan dos funciones a
  `backend/app/services/hardware_service.py`:
  - `find_active_user_plant(db, plant_id, user_id) -> Optional[Plant]`: busca por `Plant.id`,
    `Plant.user_id` e `is_active == True`.
  - `is_device_plant(db, plant, configured_plant_id) -> bool`: devuelve `True` solo si
    `get_device_plant_for_user(db, configured_plant_id, plant.user_id)` no es `None` y su `id` es
    `plant.id`.

  *Motivo:* la regla se prueba sin hardware. `get_device_plant` y `get_device_plant_for_user` no
  cambian.
- **D2 · Orden de comprobaciones en `water` y `stop-water` (CA-4 a CA-6).** Un ayudante privado
  `_get_controllable_plant(db, plant_id, user)` en `controls.py` aplica este orden:
  1. sin sesión → 401 (lo hace `get_current_user`);
  2. cuerpo inválido → 422 (Pydantic, como hoy);
  3. `find_active_user_plant` es `None` → 404 «Planta no encontrada»;
  4. `not is_device_plant(db, plant, get_settings().ESP8266_PLANT_ID)` → 409 «Esta planta no tiene el
     ESP8266 conectado.»;
  5. enviar por serial; si no se envió → 503 con el mensaje de hoy.

  El `ESP8266_PLANT_ID` se lee al atender la petición con `get_settings()`, no al importar el módulo.
  No se envía nada por serial antes del paso 5. *Motivo:* la regla de routers pide 404 para lo ajeno
  y 503 si no se envió; el 409 lo decidió la responsable.
- **D3 · `stop-water` siempre envía `STOP` (CA-2).** No consulta `LATEST_DATA` ni `led_encendido`.
  Mantiene el schema de entrada `WaterControlRequest` (la app manda solo `plant_id`; la duración por
  defecto se ignora), la respuesta `{"success": true, "message": "Riego detenido para <nombre>"}`, el
  500 por excepción y el 503 con el mensaje «No se pudo detener el riego: el ESP8266 no está conectado
  al puerto serial del servidor.». *Motivo:* el estado del backend puede estar desfasado y `STOP` de
  más no hace daño. Cambiar el schema no aporta nada.
- **D4 · Estado de la bomba en vivo, en `PlantProvider`.**
  - Campos privados nuevos `int? _livePumpPlantId` y `bool? _livePumpOn`.
  - Método público `bool? livePumpOn(int plantId)`: devuelve `_livePumpOn` si
    `_livePumpPlantId == plantId`; si no, `null`. `null` significa «sin dato en vivo».
  - En `loadSensorData`, la rama de hardware asigna `_livePumpPlantId = plantId` y
    `_livePumpOn = ledOn`. La rama de base y la de demo los dejan en `null` (CA-8).
  - `selectPlant` los pone en `null` antes de notificar, para que no quede el estado de otra planta u
    otra sesión.
  - **Contador de petición** `_sensorRequestId`, como `loadSensorHistory`: si al terminar
    `loadSensorData` ya hay una llamada más nueva, se descarta sin tocar `_currentSensorData`, el
    estado en vivo ni notificar. *Motivo:* el refresco de 3 s y la espera de confirmación (D6) piden
    datos a la vez, y una respuesta vieja con la bomba encendida no debe tapar una nueva con la bomba
    apagada.
  - El resto de `loadSensorData` no cambia, incluido el cálculo de salud (es de la spec 004).
- **D5 · `PlantProvider.stopWatering(int plantId) -> Future<bool>`.**
  - Al empezar, `_error = null`.
  - Llama a `ApiService.post(ApiConstants.controlStopWater, body: {'plant_id': plantId})`. Si sale
    bien, devuelve `true` sin recargar sensores; la pantalla espera la confirmación.
  - Con `ApiException`: `_error = e.message`, notifica y devuelve `false`.
  - Con cualquier otro error: `_error = 'No se pudo conectar con el servidor para detener el riego.'`,
    notifica y devuelve `false`.
  - No usa datos demo. `activateWatering` no cambia.
- **D6 · Pantalla de detalle: estado y flujo** (`plant_detail_screen.dart`). Estado nuevo en
  `_PlantDetailScreenState`:
  - `bool _waterAccepted`: el API aceptó «Regar» y aún no terminó su espera de 10 s ni se confirmó una
    detención.
  - `bool _isStopping`: hay una detención enviada o pendiente de confirmar.
  - `int _waterRun`: se incrementa en cada «Regar» y al confirmar una detención.

  **Riego en curso** (CA-7, CA-8) =
  `_waterAccepted || plantProvider.livePumpOn(plant.id) == true`. No mira `sensorData.pumpActive`.

  `_handleWatering` cambia solo en esto:
  - guarda `final run = ++_waterRun;` al empezar;
  - si el API responde bien, `setState(() => _waterAccepted = true)`;
  - tras los 10 s, si `!mounted || run != _waterRun`, no hace nada (CA-9: no hay «completado» después
    de una detención confirmada);
  - si no, pone `_isWatering = false` y `_waterAccepted = false` y muestra el SnackBar de hoy.

  Con un error al regar, todo sigue igual.

  `_handleStopWatering()`:
  1. Si `_isStopping`, sale (CA-12). `setState(() => _isStopping = true)`.
  2. `ok = await plantProvider.stopWatering(plant.id)`; si `!mounted`, sale.
  3. Si `!ok`: `_isStopping = false` y SnackBar con `plantProvider.error ?? 'No se pudo conectar con
     el servidor para detener el riego.'` (CA-11).
  4. Si `ok`: hasta 10 veces, `await Future.delayed(1 s)`; si `!mounted`, sale;
     `await plantProvider.loadSensorData(plant.id)`; si `!mounted`, sale. Luego mira
     `livePumpOn(plant.id)`:
     - `false` → confirmado;
     - `null` → se corta sin confirmar (dejó de estar en línea);
     - `true` → sigue esperando.
  5. Si se confirmó: `setState` con `_isStopping = false`, `_waterAccepted = false`,
     `_isWatering = false` y `_waterRun++`, y SnackBar «Riego detenido. El riego automático puede
     volver a encender la bomba si la tierra sigue seca.» (CA-9, CA-13).
  6. Si no se confirmó: `_isStopping = false` y SnackBar «Se envió la orden, pero el ESP8266 no
     confirmó que la bomba se apagó. Revisa la maceta.» (CA-10). `_waterAccepted` no cambia.

  *Motivo:* la espera vive en el `State`, así que al cerrar la pantalla muere con ella. Cada `await`
  va seguido de `if (!mounted) return;` y nunca se llama a `setState` ni a `context` después de
  `dispose`. El provider global puede notificar después, pero tiene oyentes propios y no se destruye.
  Se pide un dato cada segundo, sin esperar al refresco de 3 s, porque ese refresco no corre sin sesión
  (las pruebas) y además tarda más.
- **D7 · Botón en el lugar de «Regar»** (`_buildActionButtons`, CA-7, CA-12).
  - Si hay riego en curso o `_isStopping`, el segundo botón es
    `_buildCircleButton(icon: Icons.stop_circle_outlined, label: _isStopping ? 'Deteniendo…' : 'Detener riego', color: SolarColors.error, isLoading: _isStopping, onTap: _isStopping ? null : _handleStopWatering)`.
  - Si no, es el «Regar» de hoy, con `onTap` nulo y spinner mientras `_isWatering && !_waterAccepted`
    (petición de riego en curso).
  - No se agrega ningún botón ni se cambia `_buildCircleButton`: el `Flexible` y el `FittedBox` que ya
    tiene hacen que «Detener riego» quepa a 320 px.

  *Motivo:* la decisión 5 de la spec; además, mientras se detiene no se puede tocar ni regar ni
  detener.
- **D8 · Pruebas existentes del backend.** En `backend/tests/test_seguridad_hardware.py` se **agrega**
  un fixture `autouse` que hace `monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", None)`. No se
  cambia ninguna aserción.
  *Motivo:* la spec ahora exige que la planta sea la del ESP8266. Con eso fijado en `None`, `plant`
  es siempre la planta del ESP8266 y las pruebas de 200 y 503 no dependen del `.env` local de quien
  las corre. Las cinco pruebas de riego conservan el resultado esperado:
  - `test_stop_water_de_planta_ajena_devuelve_404` sigue en 404, porque la planta es de otro usuario
    (paso 3 de D2);
  - `test_riego_rechaza_duracion_fuera_de_rango` sigue en 422.
- **D9 · Textos fijos** (las pruebas los buscan tal cual):
  - Backend: «Planta no encontrada», «Esta planta no tiene el ESP8266 conectado.», «No se pudo detener
    el riego: el ESP8266 no está conectado al puerto serial del servidor.».
  - App: «Regar», «Detener riego», «Deteniendo…» (con el carácter `…`), «Riego detenido. El riego
    automático puede volver a encender la bomba si la tierra sigue seca.», «Se envió la orden, pero el
    ESP8266 no confirmó que la bomba se apagó. Revisa la maceta.», «No se pudo conectar con el
    servidor para detener el riego.», «¡Riego completado exitosamente!».
- **Sin migraciones, columnas, paquetes ni rutas nuevas.** No se cambian el firmware,
  `api_constants.dart`, `seed_data.py`, `hardware_helper.py`, `routers/hardware.py`, los schemas,
  `home_screen.dart` ni `GET /api/controls/status`.

## Archivos que se tocan

| Archivo | Cambio |
|---|---|
| `backend/app/services/hardware_service.py` | Nuevas `find_active_user_plant` e `is_device_plant` (D1). |
| `backend/app/routers/controls.py` | `_get_controllable_plant` (D2), que usan `activate_watering` y `stop_watering`. Nada más. |
| `backend/tests/test_controles_riego.py` | **Nuevo.** CA-1 a CA-6 por API. |
| `backend/tests/test_hardware_service.py` | Se **agregan** pruebas de las dos funciones de D1; no se cambian las existentes. |
| `backend/tests/test_seguridad_hardware.py` | Se **agrega** solo el fixture `autouse` de D8; no se cambia ninguna aserción. |
| `frontend/lib/providers/plant_provider.dart` | `livePumpOn`, contador de petición y limpieza en `selectPlant` (D4); `stopWatering` (D5). |
| `frontend/lib/screens/plant/plant_detail_screen.dart` | Estado y flujo de D6; botón de D7. |
| `frontend/test/plant_provider_stop_watering_test.dart` | **Nuevo.** Provider con `MockClient` (D4, D5). |
| `frontend/test/plant_detail_stop_watering_test.dart` | **Nuevo.** Pruebas de widget del detalle (CA-7 a CA-13), incluido el desborde a 320 y 360 px. |
| `specs/003-detener-riego/*` | Spec, plan, tareas y, al final, `revision.md`. |

`frontend/lib/config/api_constants.dart` **no** se toca y no entra en ningún commit (tiene un cambio
local de la responsable). `esp8266_maceta_inteligente/` no se toca.

## Pruebas por criterio

| Criterio | Prueba | Archivo |
|---|---|---|
| CA-1 | `test_detener_en_la_planta_del_esp8266_envia_stop_una_vez` | `backend/tests/test_controles_riego.py` |
| CA-2 | `test_detener_con_la_bomba_apagada_igual_envia_stop` | `backend/tests/test_controles_riego.py` |
| CA-3 | `test_detener_sin_esp8266_devuelve_503_con_mensaje` | `backend/tests/test_controles_riego.py` |
| CA-4 | `test_detener_planta_ajena_devuelve_404_sin_enviar` | `backend/tests/test_controles_riego.py` |
| CA-4 | `test_detener_planta_inexistente_devuelve_404_sin_enviar` | `backend/tests/test_controles_riego.py` |
| CA-4 | `test_detener_planta_borrada_devuelve_404_sin_enviar` | `backend/tests/test_controles_riego.py` |
| CA-4 | `test_detener_sin_token_devuelve_401` | `backend/tests/test_controles_riego.py` |
| CA-5 | `test_detener_planta_propia_sin_esp8266_devuelve_409_sin_enviar` | `backend/tests/test_controles_riego.py` |
| CA-5 | `test_detener_con_planta_configurada_inexistente_devuelve_409` | `backend/tests/test_controles_riego.py` |
| CA-5 | `test_detener_si_la_planta_del_esp8266_es_de_otro_usuario_devuelve_409` | `backend/tests/test_controles_riego.py` |
| CA-6 | `test_regar_planta_propia_sin_esp8266_devuelve_409_sin_enviar` | `backend/tests/test_controles_riego.py` |
| CA-6 | `test_regar_planta_borrada_devuelve_404_sin_enviar` | `backend/tests/test_controles_riego.py` |
| CA-6 | `test_regar_planta_ajena_o_inexistente_devuelve_404_sin_enviar` (parametrizada) | `backend/tests/test_controles_riego.py` |
| CA-6 | `test_regar_en_la_planta_del_esp8266_envia_water` | `backend/tests/test_controles_riego.py` |
| CA-6 | `test_regar_sin_esp8266_devuelve_503` | `backend/tests/test_controles_riego.py` |
| CA-5, CA-6 | `test_is_device_plant_true_para_la_planta_del_esp8266` | `backend/tests/test_hardware_service.py` |
| CA-5, CA-6 | `test_is_device_plant_false_para_otra_planta_del_usuario` | `backend/tests/test_hardware_service.py` |
| CA-5, CA-6 | `test_is_device_plant_false_con_id_configurado_inexistente` | `backend/tests/test_hardware_service.py` |
| CA-4, CA-6 | `test_find_active_user_plant_ignora_plantas_ajenas_y_borradas` | `backend/tests/test_hardware_service.py` |
| CA-7 | `con la bomba encendida en vivo muestra Detener riego en lugar de Regar` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-7 | `tras aceptar Regar muestra Detener riego aunque aún no haya dato en vivo` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-7 | `la fila Info Detener riego Diagnósticos no se desborda a 320 y 360 px` (dos anchos) | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-8 | `sin dato en vivo muestra Regar y no Detener riego` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-8 | `livePumpOn es null si el ESP8266 está desconectado aunque la lectura guardada diga bomba encendida` | `frontend/test/plant_provider_stop_watering_test.dart` |
| CA-8 | `livePumpOn es null si clima-actual es de otra planta` | `frontend/test/plant_provider_stop_watering_test.dart` |
| CA-8 | `livePumpOn es null con datos demo cuando el API falla` | `frontend/test/plant_provider_stop_watering_test.dart` |
| CA-8 | `livePumpOn refleja led_encendido cuando el ESP8266 está en línea en esa planta` | `frontend/test/plant_provider_stop_watering_test.dart` |
| CA-8 | `selectPlant borra el estado en vivo de la planta anterior` | `frontend/test/plant_provider_stop_watering_test.dart` |
| CA-8 | `una respuesta vieja de loadSensorData no pisa el estado en vivo más nuevo` | `frontend/test/plant_provider_stop_watering_test.dart` |
| CA-9, CA-13 | `al confirmar la detención muestra Riego detenido con el aviso y vuelve Regar` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-9 | `después de detener no aparece Riego completado exitosamente` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-9 | `mientras se confirma muestra Deteniendo con indicador de carga` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-10 | `si a los 10 s la bomba sigue encendida avisa que no se confirmó y deja Detener riego` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-10 | `si el ESP8266 deja de estar en línea avisa que no se confirmó` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-11 | `si el API responde error muestra su mensaje y deja Detener riego habilitado` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-11 | `stopWatering envía plant_id a /api/controls/stop-water y devuelve true` | `frontend/test/plant_provider_stop_watering_test.dart` |
| CA-11 | `stopWatering con 503 devuelve false y deja el detail como error` | `frontend/test/plant_provider_stop_watering_test.dart` |
| CA-11 | `stopWatering sin servidor devuelve false con el mensaje fijo` | `frontend/test/plant_provider_stop_watering_test.dart` |
| CA-12 | `un segundo toque mientras se detiene no envía otra petición` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-12 | `al cerrar la pantalla mientras espera la confirmación no hay errores` | `frontend/test/plant_detail_stop_watering_test.dart` |
| CA-14 | Paso manual con la placa | T8 |

Notas para quien escribe las pruebas:

- **Qué pasa desde el principio y qué debe fallar.**
  - **Deberían pasar ya**, porque fijan el comportamiento actual: CA-1, CA-2, CA-3, las de CA-4 de
    planta ajena, inexistente y 401, y en CA-6 las de 404 por planta ajena o inexistente, «envía
    water» y 503.
  - **Deben fallar:**
    - CA-4 con planta borrada;
    - CA-5;
    - CA-6 con planta borrada y con 409;
    - las cuatro de servicio, por importar funciones que aún no existen; eso hace fallar todo
      `test_hardware_service.py` hasta T3, así que se avisa a `backend-dev`;
    - todas las de frontend (no existen `livePumpOn`, `stopWatering` ni «Detener riego»).
- **Backend.**
  - App de prueba propia en `test_controles_riego.py` con `controls.router`, como en
    `test_seguridad_hardware.py`: `get_db` y `get_current_user` sobreescritos, y un cliente sin
    `get_current_user` para el 401.
  - El envío por serial se sustituye con
    `monkeypatch.setattr(controls, "enviar_comando_serial", fake)`, donde `fake` agrega el comando a
    una lista y devuelve `True`, o devuelve `False` para el 503.
  - En **todas** las pruebas se fija
    `monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", <id o None>)`, para no depender del
    `.env`.
  - Planta propia sin ESP8266: `ESP8266_PLANT_ID = plant.id` y se crea una segunda planta del usuario
    con `Plant(user_id=user.id, common_name="Otra", location=PlantLocation.BALCON)`, que es la que se
    pide.
  - Planta del ESP8266 de otro usuario: `ESP8266_PLANT_ID = other_plant.id` y se pide `plant` → 409.
    Esto no revela nada de la otra planta.
  - Planta borrada: `plant.is_active = False` y commit.
  - CA-2: hacer explícito que no importa el estado de la bomba con
    `monkeypatch.setitem(hardware_helper.LATEST_DATA, "led_encendido", False)` (y
    `"status_conexion", "En línea"`), y comprobar que igual se envía `["STOP"]`. El router no debe
    leer `LATEST_DATA`. Importar `app.utils.hardware_helper` es seguro porque ya lo importa
    `test_seguridad_hardware.py`.
  - En cada caso de 404 o 409: la lista de comandos queda en `[]`.
- **Frontend, provider** (`plant_provider_stop_watering_test.dart`).
  - `SharedPreferences.setMockInitialValues({})` y `http.runWithClient(..., () => MockClient(...))`,
    como `diagnosis_route_test.dart`. El `MockClient` responde según `request.url.path`.
  - Para la rama de hardware hace falta que `_plants` tenga la planta: primero se llama a
    `loadPlants()` con `GET /api/plants/` respondiendo `[{"id": 7, "common_name": "Echeveria", ...}]`.
  - `clima-actual` responde por ejemplo
    `{"estado_conexion": "En línea", "plant_id": 7, "temperatura": 24, "humedad_aire": 50, "humedad_suelo": 45, "led_encendido": true}`.
  - Desconectado: `"estado_conexion": "Desconectado"` y `/api/sensors/latest/7` con
    `"pump_active": 1`. En ese caso `livePumpOn(7)` es `null`, aunque `currentSensorData.pumpActive`
    sea 1.
  - Fuera de orden: la primera petición de `clima-actual` espera un `Completer` y responde
    `led_encendido: true`; la segunda responde `false` en seguida. Se completa la primera al final y
    se comprueba `livePumpOn(7) == false`.
  - `stopWatering`: comprobar `request.method == 'POST'`, la ruta `/api/controls/stop-water` y
    `jsonDecode(request.body) == {'plant_id': 7}`. Un 503 con `{"detail": "No se pudo detener..."}`
    debe dejar ese texto en `error`. Que `MockClient` lance una excepción da el mensaje fijo.
- **Frontend, pantalla** (`plant_detail_stop_watering_test.dart`).
  - `FakePlantProvider extends PlantProvider` con:
    - `selectedPlant` fijo (id 7);
    - campo `bool? pumpOn` devuelto por `livePumpOn`;
    - `loadSensorData` que registra llamadas y aplica un posible cambio programado (por ejemplo
      `pumpOnAfterNextLoad`), sin red;
    - `stopWatering` que registra llamadas y devuelve un `Completer<bool>.future` controlado por la
      prueba;
    - `activateWatering` que devuelve un valor configurable;
    - `error` sobreescrito.
  - Se monta igual que en `plant_detail_diagnoses_button_test.dart`: `AuthProvider()` **sin sesión**,
    para que no arranque el refresco de 3 s, y `tester.view.physicalSize` grande.
  - **Tiempo falso:** la espera de confirmación usa `Future.delayed(1 s)`, que en `testWidgets` avanza
    con `await tester.pump(const Duration(seconds: 1))`, sin esperas reales. Para confirmar:
    completar el `Completer` con `true`, poner `fake.pumpOn = false` y avanzar 1 s. Para «no
    confirma»: dejar `pumpOn = true` y avanzar de 1 s en 1 s hasta 11 s. Para «deja de estar en
    línea»: `pumpOn = null` y avanzar 1 s.
  - CA-9 («no aparece completado»): tocar «Regar» (`activateWatering` → `true`), confirmar la
    detención y luego avanzar 11 s. «¡Riego completado exitosamente!» no debe aparecer en ningún
    momento.
  - SnackBars: buscar el texto exacto de D9 con `find.text`.
  - CA-12, cierre de pantalla: con la confirmación pendiente, `pumpWidget(SizedBox())` y luego avanzar
    11 s. No debe haber excepción (`tester.takeException()` es `null`).
  - **Final de cada prueba:** desmontar con `await tester.pumpWidget(const SizedBox())` y
    `await tester.pump(const Duration(seconds: 15))`. Así terminan el parpadeo de
    `AnimatedPlantWidget`, la espera de 10 s de «Regar» y la de confirmación, y `flutter_test` no
    encuentra temporizadores pendientes. Usar `pump`, nunca `pumpAndSettle`, por las animaciones que
    se repiten.
  - Desborde: copiar el patrón de `plant_detail_overflow_test.dart` (anchos de 320 y 360,
    `FlutterError.onError` que tolera solo «overflowed» de otras filas) con `pumpOn = true` y midiendo
    «Info», «Detener riego» y «Diagnósticos». Las cuatro filas que ya se desbordan en `main` quedan
    fuera de alcance.
  - `plant_detail_overflow_test.dart` y `plant_detail_diagnoses_button_test.dart` no se cambian:
    su fake no sobreescribe `livePumpOn` y el `PlantProvider` real devuelve `null`, así que siguen
    viendo «Regar».

## Riesgos y lo que no se puede verificar

- **Bomba real.** Que la bomba se apague físicamente, el retraso real y el texto que imprime el
  firmware solo se comprueban con la placa (T8, CA-14). Las pruebas automáticas simulan el serial y
  el estado en vivo.
- **200 no significa que la bomba se apagó.** Por eso la confirmación de D6. Si el ESP8266 se cuelga
  sin perder el puerto, la app avisa a los 10 s (CA-10), pero no puede apagar la bomba. En ese caso
  la protege el tope del firmware: 60 s en manual y 10 s por riego automático.
- **Riego automático.** Tras un `STOP`, el firmware espera 5 minutos y vuelve a regar si la tierra
  sigue seca. El SnackBar lo avisa (CA-13). Cambiarlo es una tarea de firmware aparte.
- **Concurrencia entre sesiones.** Hay un solo ESP8266 y su estado es global. Un «Regar» desde otra
  pestaña o dispositivo de la misma persona después de un «Detener» vuelve a encender la bomba, y la
  pantalla lo verá como riego en curso en el siguiente dato en vivo. No se bloquea porque no se guarda
  estado de riego (decisión 7).
- **Detención sin confirmar y sin conexión.** Si el ESP8266 deja de estar en línea, «Detener riego»
  solo sigue visible mientras `_waterAccepted` (hasta 10 s desde «Regar»). Después desaparece, porque
  sin dato en vivo no se muestra (CA-8). En ese caso, al terminar los 10 s de «Regar» puede aparecer
  «¡Riego completado exitosamente!», porque la decisión 8 solo lo quita cuando la detención se
  confirmó.
- **Más peticiones al backend.** Durante la confirmación la app pide `clima-actual` cada segundo,
  sumado al refresco de 3 s. Son como mucho 10 peticiones extra y solo en esa espera.
- **`.env` local.** Sin el fixture de D8, quien tenga `ESP8266_PLANT_ID` en su `.env` vería fallar
  las pruebas de 200 y 503 en local aunque la CI pase.
- **Cobertura.** El umbral de `backend/.coveragerc` no debe bajar. Las ramas nuevas de `controls.py`
  y del servicio quedan cubiertas por las pruebas de la tabla.

## Diferencias con lo planeado

- **Sin cambios de comportamiento** respecto de las decisiones del plan. No se tocó el firmware ni
  `frontend/lib/config/api_constants.dart`.
- **Backend:** el `settings = get_settings()` a nivel de módulo de `controls.py` quedó sin uso (el
  id del ESP8266 se lee ahora al atender cada petición); no se quitó para no tocar más que lo
  planeado.
- **Pantalla** (`frontend-dev`): se agregó el ayudante privado `_showStopSnackBar` para no repetir
  el SnackBar. El aviso de «no se confirmó» usa `SolarColors.error` y el de «Riego detenido…»
  `SolarColors.primary`; el plan no fijaba colores.
- **Pruebas extra fuera de la tabla «Pruebas por criterio»** (`pruebas`): en el provider,
  `una lectura de base o demo borra el dato en vivo anterior`,
  `selectPlant de la misma planta limpia el estado en vivo hasta tener uno nuevo`,
  `una respuesta vieja que falla no pisa el dato en vivo más nuevo` y
  `stopWatering limpia el error anterior al empezar`; en la pantalla,
  `si el API rechaza Regar no aparece Detener riego y se muestra el error`,
  `sin detener, el flujo de Regar sigue igual: a los 10 s avisa riego completado` y dos variantes de
  cierre de la pantalla (respuesta del API pendiente; error que llega con la pantalla cerrada). En
  el servicio, una comprobación de `is_device_plant` con `configured_plant_id=None`.
- **Detalles que fijaron las pruebas:** la confirmación hace exactamente 10 consultas (una por
  segundo); el mensaje de error de `stopWatering` lleva punto final.
- **Corrección tras la revisión (aprobada con observaciones):**
  - Obs. 1: `_handleWatering` ignora el resultado de una petición de «Regar» que quedó obsoleta
    (hubo una detención entretanto). Antes, si la detención se confirmaba con «Regar» aún en vuelo,
    «Detener riego» quedaba visible para siempre con la bomba apagada.
  - Obs. 3: una excepción de `loadSensorData` durante la espera de confirmación se trata como «no
    confirmado» en vez de dejar la pantalla en «Deteniendo…».
  - Obs. 6: prueba nueva del mensaje del 503 al regar
    (`test_regar_sin_esp8266_devuelve_503_con_mensaje`).
  - Obs. 7: se quitó el `settings` sin uso de `controls.py` y el docstring de `water` ya no habla de
    MQTT ni ESP32. Quedan dos comentarios con ese texto en el mismo archivo (uno en `water`, otro en
    un endpoint que esta spec no toca), sin corregir.
  - Pruebas agregadas en `frontend/test/plant_detail_stop_watering_test.dart`, grupo «Revisión ·
    obs. 1 y 3».
  - **Sin corregir, a decisión de la responsable:** obs. 2 (un dato «bomba apagada» anterior al
    encendido puede contarse como confirmación) y obs. 4 («¡Riego completado exitosamente!» tras una
    detención no confirmada). Obs. 5 (`ApiService` sin tiempo límite) es anterior a la spec.
- **Decisiones del plan que la responsable no tomó expresamente** (se siguió la propuesta del
  planificador): el «completado» de «Regar» solo se suprime cuando la detención se confirma, así que
  tras un aviso de «no confirmó» todavía puede aparecer; tras aceptarse «Regar» se muestra «Detener
  riego» en lugar del spinner de 10 s; se agregó un fixture `autouse` a
  `backend/tests/test_seguridad_hardware.py` sin cambiar ninguna aserción.
