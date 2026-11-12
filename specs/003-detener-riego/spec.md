# Spec 003 · Detener riego desde la app

- **Estado:** aprobada
- **Rama:** `feat/003-detener-riego`
- **Responsable:** Valentina Bermeo

## Qué se construye

Mientras la bomba de la maceta está regando, el detalle de la planta muestra «Detener riego» en
lugar de «Regar». Al tocarlo, la app manda apagar la bomba y solo dice «Riego detenido» cuando el
ESP8266 informa que la bomba se apagó de verdad. Si el ESP8266 no está conectado, si la orden no se
confirma o si la planta no es la de la maceta, la persona ve un mensaje claro en español y la app
no da el riego por detenido.

## Por qué

**Hallazgo principal: detener el riego no exige cambiar el firmware.** El firmware y el backend ya
saben apagar la bomba; lo que falta es la app y cerrar dos huecos de seguridad.

- **Firmware (solo lectura).** `esp8266_maceta_inteligente/esp8266_maceta_inteligente.ino` entiende
  dos comandos por serial: `WATER:<segundos>`, con un máximo de 60 s (`MAX_RIEGO_MANUAL_S`), y `STOP`.
  `STOP` apaga el riego manual y también el automático. El `loop` no se queda bloqueado mientras
  riega: el riego manual se apaga solo cuando pasa su tiempo, en cada vuelta se lee el serial (con
  espera máxima de 100 ms) y solo hay pausas cortas al leer el sensor (5 × 2 ms). Cada vez que la
  bomba cambia de estado, el firmware imprime enseguida «BOMBA ENCENDIDO» o «BOMBA APAGADO», y
  además repite el estado cada 2 s.
  - Detener un riego automático hace que el firmware espere 5 minutos (`PAUSA_ENTRE_RIEGOS_MS`) antes
    de volver a regar solo. Pasado ese tiempo, si la tierra sigue seca, la bomba puede volver a
    encenderse sin que nadie lo pida. Detener un riego manual no activa esa pausa.
  - El firmware no responde a la orden con un acuse propio. La única prueba de que la bomba se apagó
    es la línea «BOMBA APAGADO».
- **Backend.** `backend/app/routers/controls.py` ya tiene `POST /api/controls/stop-water`: exige
  sesión, comprueba que la planta sea del usuario (404 si no), manda `STOP` por serial y responde 503
  con un mensaje en español si el ESP8266 no está conectado. Los envíos por serial pasan por
  `enviar_comando_serial` (`backend/app/utils/hardware_helper.py`), que devuelve verdadero en cuanto
  escribe en el puerto, sin esperar respuesta. Hay pruebas en `backend/tests/test_seguridad_hardware.py`
  para el envío de `STOP`, el 503 y el 404 de una planta ajena. Faltan cosas:
  - Ni `stop-water` ni `water` comprueban que la planta sea la del ESP8266. Hay un solo ESP8266, y
    `get_device_plant_for_user` (`backend/app/services/hardware_service.py`) ya resuelve cuál es su
    planta. Hoy, con cualquier planta propia, alguien puede encender o apagar la bomba que está en la
    maceta de otra persona. Además, el botón «Regar» de una planta sin maceta riega la planta del
    ESP8266.
  - Ninguno de los dos filtra `is_active`, así que una planta borrada todavía puede mover la bomba.
  - El backend sabe si la bomba está encendida porque el hilo serial lee «BOMBA ENCENDIDO/APAGADO» y
    lo guarda en `LATEST_DATA["led_encendido"]`. Lo expone en `GET /api/hardware/clima-actual`
    (`led_encendido`, `estado_conexion`, `plant_id`). En cambio, no sabe cuánto falta para que termine
    el riego ni si lo inició la app o el riego automático.
  - `GET /api/controls/status/{plant_id}` devuelve `pump_active: false` fijo, con valores de batería y
    seguidor solar inventados. No sirve para saber el estado real.
  - No se guarda ningún evento de riego. Lo único que queda en la base es `pump_active` dentro de las
    lecturas de `sensor_data`, guardadas como mucho una vez por minuto (`_guardar_datos_en_db`).
- **App.** `frontend/lib/screens/plant/plant_detail_screen.dart` tiene el botón «Regar» en la fila
  Info / Regar / Diagnósticos. `_handleWatering` llama a `PlantProvider.activateWatering`
  (`frontend/lib/providers/plant_provider.dart`), espera 10 s fijos y muestra «¡Riego completado
  exitosamente!» sin mirar lo que hizo la bomba. No existe ningún método del provider ni ningún botón
  para detener el riego. La ruta ya está declarada en `main` como `controlStopWater`
  (`frontend/lib/config/api_constants.dart`), pero nadie la usa.
  - La pantalla refresca cada 3 s con `loadSensorData`. Usa el `led_encendido` real solo si el
    ESP8266 está «En línea» y es la planta del ESP8266. Si no, usa la última lectura guardada, que
    puede tener hasta un minuto de antigüedad o ser vieja si el ESP8266 se desconectó. Si el API falla,
    usa `SensorDataModel.demo`, que trae `pumpActive: 0`.
  - Las pruebas `frontend/test/plant_detail_overflow_test.dart` y
    `frontend/test/plant_detail_diagnoses_button_test.dart` exigen que la fila Info / Regar /
    Diagnósticos quepa en pantallas de 320 y 360 px de ancho.

## Fuera de alcance

- Modificar el firmware. No hace falta, y `CLAUDE.md` lo prohíbe dentro de una spec de software. La
  pausa de 5 minutos tras detener un riego automático y la falta de acuse propio de `STOP` quedan
  como están.
- Mostrar el tiempo que falta de riego o una cuenta regresiva: el backend no lo sabe.
- Guardar un historial de riegos y detenciones en la base: no hay tabla para eso y no hay migraciones.
- Arreglar `GET /api/controls/status/{plant_id}` y sus valores fijos de batería y seguidor solar
  (corresponde a la spec 005), al igual que el aviso de modo demo.
- Calcular la salud de la planta y el color del botón «Regar» según la salud (spec 004).
- Cambiar la duración del riego (10 s desde la app, de 1 a 60 s en el API) o volver «Regar»
  configurable.
- Detener el riego desde otra pantalla que no sea el detalle de la planta (por ejemplo, la tarjeta
  «Bomba de Riego» de `home_screen.dart`).
- Cambiar `GET /api/hardware/clima-actual`, `backend/seed_data.py` o `database/init.sql`.

## Criterios de aceptación

En las pruebas automáticas no se usa un ESP8266, un puerto serial ni HTTP reales. El envío por serial
y la lectura del ESP8266 se simulan. «La planta del ESP8266» es la que da el backend según
`ESP8266_PLANT_ID`, o la planta activa más antigua si esa variable no está definida.

API (`POST /api/controls/stop-water`):

- **CA-1. Detener.** Dado un usuario con sesión, dueño de la planta activa del ESP8266, y un ESP8266
  conectado, cuando pide detener el riego de esa planta, entonces recibe 200 con `success: true` y un
  mensaje en español, y se envía `STOP` por serial una sola vez. (Ya funciona así; se fija con
  pruebas.)
- **CA-2. Detener sin riego en curso.** Dado el caso de CA-1, pero con la bomba reportada como
  apagada, cuando pide detener, entonces recibe igualmente 200 y se envía `STOP`. Para el firmware,
  `STOP` no hace nada si la bomba ya está apagada.
- **CA-3. ESP8266 desconectado.** Dado que el comando no se puede enviar por serial, cuando pide
  detener, entonces recibe 503 con el mensaje «No se pudo detener el riego: el ESP8266 no está
  conectado al puerto serial del servidor.». Nunca recibe 200. (Ya funciona así; se fija con pruebas.)
- **CA-4. Planta ajena, inexistente o borrada.** Dado un usuario con sesión, cuando pide detener el
  riego de una planta de otro usuario, de un id que no existe o de una planta suya borrada
  (inactiva), entonces recibe 404 «Planta no encontrada» y no se envía nada por serial. Sin sesión
  recibe 401.
- **CA-5. Planta sin ESP8266.** Dada una planta activa del usuario que no es la planta del ESP8266
  (o la planta configurada no existe), cuando pide detener, entonces recibe 409 con el mensaje «Esta
  planta no tiene el ESP8266 conectado.» y no se envía nada por serial.

API (`POST /api/controls/water`, el mismo control, para que la app no pueda encender una bomba que
luego no puede apagar):

- **CA-6. Iniciar el riego con las mismas reglas.** Dado un usuario con sesión, cuando pide regar una
  planta ajena, inexistente o borrada, entonces recibe 404 «Planta no encontrada». Si pide regar una
  planta suya que no es la del ESP8266, recibe 409 con el mensaje «Esta planta no tiene el ESP8266
  conectado.». En ninguno de los dos casos se envía nada por serial. Con la planta del ESP8266 sigue
  funcionando como hoy, con el límite de 1 a 60 s y 503 si está desconectado.

Pantalla de detalle de la planta (app):

- **CA-7. Riego en curso.** Dado el detalle de la planta del ESP8266, con el ESP8266 «En línea» y la
  bomba reportada encendida (por un riego pedido desde la app o por el riego automático), cuando se
  muestra la pantalla, entonces en el lugar de «Regar» aparece el botón «Detener riego». La fila
  Info / Detener riego / Diagnósticos no se desborda a 320 ni a 360 px de ancho. Lo mismo pasa
  justo después de que el API acepta un «Regar», aunque el ESP8266 todavía no haya informado que
  encendió la bomba.
- **CA-8. Sin datos en vivo, no hay «Detener».** Dada una planta que no es la del ESP8266, o el
  ESP8266 desconectado, o datos de sensores sacados de la última lectura guardada o de datos demo,
  cuando se muestra el detalle, entonces no aparece «Detener riego» y el riego en curso no se deduce
  de lecturas guardadas ni de datos demo.
- **CA-9. Detener con confirmación.** Dado un riego en curso, cuando la persona toca «Detener riego»
  y el API responde 200, entonces el botón muestra un indicador de carga y el texto «Deteniendo…».
  Cuando el ESP8266 informa que la bomba está apagada, aparece el SnackBar de CA-13 (empieza por
  «Riego detenido.») y vuelve el botón «Regar», ya habilitado. En ningún momento se muestra
  «¡Riego completado exitosamente!» por ese riego.
- **CA-10. Sin confirmación del ESP8266.** Dado que el API respondió 200, cuando pasan 10 s y el
  ESP8266 sigue informando que la bomba está encendida (o deja de estar «En línea»), entonces aparece
  el SnackBar «Se envió la orden, pero el ESP8266 no confirmó que la bomba se apagó. Revisa la
  maceta.», sigue visible «Detener riego» y nunca se muestra «Riego detenido.».
- **CA-11. Error del API.** Dado un riego en curso, cuando la persona toca «Detener riego» y el API
  responde con error (503, 404 o 409), entonces aparece un SnackBar con el mensaje del servidor. Si
  el servidor no responde, el SnackBar dice «No se pudo conectar con el servidor para detener el
  riego.». En los dos casos «Detener riego» sigue visible y habilitado, y no se muestra «Riego
  detenido.».
- **CA-12. Doble toque.** Dado que la persona tocó «Detener riego» y la orden todavía no se ha
  confirmado ni ha fallado, cuando vuelve a tocar el botón, entonces no se envía una segunda petición
  y no se puede tocar ningún botón para regar o detener.
- **CA-13. Aviso sobre el riego automático.** Dado que se confirmó la detención (CA-9), cuando aparece
  el SnackBar, entonces dice «Riego detenido. El riego automático puede volver a encender la bomba si
  la tierra sigue seca.», porque la app no puede saber si el riego que se detuvo era manual o
  automático.

Verificación manual con la placa (las pruebas automáticas no usan hardware):

- **CA-14. Bomba real.** Con el ESP8266 conectado por USB, la planta del ESP8266 del usuario abierta y
  `WATER` limitado a 10 s desde la app, al tocar «Regar» y luego «Detener riego» antes de que pasen
  5 s, la bomba se apaga físicamente en 3 s o menos, el monitor del backend registra «BOMBA APAGADO»
  y la app muestra el mensaje de CA-13. Con el cable USB desconectado, el mismo intento muestra el
  mensaje de CA-3.

## Preguntas abiertas

- Ninguna. La responsable (Valentina Bermeo) aprobó la spec el 2026-11-12 con estas decisiones:
  1. **Solo la planta del ESP8266 del propio usuario.** Regar y detener funcionan únicamente sobre
     esa planta (CA-5, CA-6).
  2. **Códigos de error.** Planta propia sin ESP8266 → 409 «Esta planta no tiene el ESP8266
     conectado.». Planta ajena, inexistente o borrada → 404 «Planta no encontrada» (CA-4 a CA-6).
  3. **Riego automático.** También se puede detener, con el aviso de que puede volver a encenderse
     (CA-7, CA-13).
  4. **Confirmación.** «Riego detenido» solo se muestra cuando el ESP8266 informa que la bomba se
     apagó, con un límite de 10 s (CA-9, CA-10).
  5. **Botón.** «Detener riego» ocupa el lugar de «Regar»; no se añade un cuarto botón (CA-7).
  6. **Detener sin riego en curso** no es un error: siempre se envía `STOP` y se responde 200 (CA-2).
  7. **Historial de riegos.** No se guarda en la base.
  8. **«¡Riego completado exitosamente!».** Lo único que cambia es que no aparece cuando el riego se
     detuvo (CA-9). El resto del flujo de «Regar» queda igual y no se ata al estado real de la bomba.
  9. **Aviso a hardware.** El acuse propio de `STOP` y la pausa de 5 minutos tras detener un riego
     automático quedan para una tarea de firmware aparte, probada con la placa. No bloquean esta
     spec.
