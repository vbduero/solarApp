# Revisión · Spec 003

- **Revisado por:** agente `revisor`
- **Commit revisado:** ninguno propio de la rama. Base `85faabf` (`main`) más el árbol de trabajo de
  `feat/003-detener-riego` (7 archivos modificados y 3 sin seguimiento más `specs/003-detener-riego/`),
  revisado el 2026-11-12.
- **Veredicto de la primera revisión:** APROBADA CON OBSERVACIONES (sin observaciones de gravedad
  alta; dos medias).
- **Veredicto final (tras la comprobación de la corrección, ver el último apartado):** APROBADA CON
  OBSERVACIONES.

## Verificación ejecutada

| Comprobación | Resultado |
|---|---|
| `python -m pytest -q --cov --cov-config=.coveragerc` (desde `backend\`, con el `venv`) | **154 passed**, 9 warnings (deprecaciones de Pydantic, previas). Cobertura total **69,55 %** (umbral 60 %). `app\routers\controls.py` 83 %: sin cubrir 61-62 y 94-95 (los 500 por excepción) y 121-130 (`/status`, fuera de alcance). `hardware_service.py` al 100 %. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **38 issues**, igual que `main`. Comparé la lista con una copia de `main` hecha con `git archive`: la única diferencia son 2 avisos `asset_directory_does_not_exist` de la copia, que no tenía `assets/`. **No hay avisos nuevos.** |
| `flutter test` | **118 pruebas, «All tests passed!»**. Las 37 nuevas de la spec (`plant_detail_stop_watering_test.dart` y `plant_provider_stop_watering_test.dart`) también pasan solas. |
| Archivos cambiados dentro del alcance del plan | Sí. `git status --short` y `git diff main`: los 9 archivos de código y pruebas están en la tabla «Archivos que se tocan». `frontend/lib/config/api_constants.dart` tiene un cambio local de `baseUrl` (IP de la responsable): es ajeno a la spec y **no debe entrar en ningún commit**. No hay cambios en `esp8266_maceta_inteligente/`, `database/`, `backend/seed_data.py`, `.env`, `static/`, `build/`, los schemas ni las pruebas `plant_detail_overflow_test.dart` y `plant_detail_diagnoses_button_test.dart`. |
| `test_seguridad_hardware.py`: solo el fixture de D8 | Sí. El diff solo **agrega** el fixture `autouse` `esp8266_plant_sin_configurar` (líneas 30-37). No cambia ni quita ninguna aserción. `get_settings` ya estaba importado. |
| Afirmaciones del plan sobre el firmware (lectura) | Se cumplen. En `esp8266_maceta_inteligente.ino`, `STOP` (160-164) apaga el riego manual y llama a `detenerRiegoAuto`, que activa la pausa de 5 min (`PAUSA_ENTRE_RIEGOS_MS`). `WATER` tiene un tope de 60 s (147-159). `aplicarEstadoBomba` imprime «BOMBA ENCENDIDO/APAGADO» en cuanto cambia el estado (134-141) y el estado se repite cada 2 s (265-266). El `loop` no se bloquea (`setTimeout(100)`, 5 × 2 ms). En el backend, `hardware_helper.py` (210-216) pasa esas líneas a `LATEST_DATA["led_encendido"]`. |
| Otros caminos que mandan `WATER`/`STOP` | Ninguno. `enviar_comando_serial` solo se llama en `controls.py` (líneas 60 y 93), y las dos rutas pasan antes por `_get_controllable_plant`. |

### Mutantes (en copias dentro del scratchpad; el repositorio no se tocó)

| Mutante | Resultado |
|---|---|
| B1 · `find_active_user_plant` sin `is_active` | Muere: 3 pruebas (planta borrada en `stop-water` y `water`, más la del servicio). |
| B2 · `_get_controllable_plant` sin la comprobación 409 | Muere: 4 pruebas. |
| B3 · `water` vuelve a la consulta antigua (sin `is_active` ni planta del ESP8266) | Muere: 2 pruebas. |
| B4 · `STOP` se envía antes de las comprobaciones | Muere: 8 pruebas. |
| B5 · `is_device_plant` con `get_device_plant` (sin filtrar por dueño) | **Sobrevive, pero es equivalente.** `find_active_user_plant` ya exige el dueño y se compara el id, así que no hay hueco. |
| F1 · «Detener riego» también con `pumpActive == 1` guardado | Muere. |
| F2 · sin `run == _waterRun` (vuelve «completado») | Muere. |
| F3 · `null` cuenta como confirmado | Muere. |
| F4 · no se corta con `null` | Muere. |
| F5 · «Deteniendo…» tocable | Muere. |
| F6 · sin `_waterRun++` al confirmar | Muere. |
| F7 · 3 consultas en vez de 10 | Muere. |
| F8 · sin el contador de petición en la rama de hardware | Muere. |
| F9 · la lectura de base o demo no limpia el dato en vivo | Muere. |
| F10 · `selectPlant` no limpia el dato en vivo | Muere. |
| F11 · `livePumpOn` ignora el id de la planta | Muere. |
| F12 · sin spinner mientras se detiene | Muere. |

Prueba más importante: `test_detener_planta_propia_sin_esp8266_devuelve_409_sin_enviar`. Falla si se
quita la línea 30 de `backend/app/routers/controls.py`
(`if not is_device_plant(db, plant, get_settings().ESP8266_PLANT_ID):`).

## Criterios de aceptación

| Criterio | ¿Tiene prueba? | ¿La prueba puede fallar? | Observación |
|---|---|---|---|
| CA-1 | Sí: `test_detener_en_la_planta_del_esp8266_envia_stop_una_vez` | Sí (B4) | Comprueba 200, `success`, el nombre de la planta y `["STOP"]` una sola vez. |
| CA-2 | Sí: `test_detener_con_la_bomba_apagada_igual_envia_stop` | Sí (B4) | Pone `led_encendido=False` en `LATEST_DATA`. El router no lee `LATEST_DATA`. |
| CA-3 | Sí: `test_detener_sin_esp8266_devuelve_503_con_mensaje`, más la previa de `test_seguridad_hardware.py` | Sí | Mensaje exacto. |
| CA-4 | Sí: ajena, inexistente, borrada y sin token (401) | Sí (B1, B4) | En todas, la lista de comandos queda vacía. |
| CA-5 | Sí: planta propia sin ESP8266, id configurado inexistente, ESP8266 en la planta de otro usuario | Sí (B2) | Mensaje exacto y nada enviado. |
| CA-6 | Sí: 409, borrada, ajena o inexistente (parametrizada), `WATER:10` y 503 | Sí (B1, B2, B3) | Los límites de 1 a 60 s siguen cubiertos en `test_seguridad_hardware.py`. La prueba de 503 no mira el mensaje (obs. 6). |
| CA-7 | Sí: bomba en vivo, después de aceptar «Regar» y desborde a 320 y 360 px | Sí (F1, F11) | Mide la fila y que no se solapen los botones. |
| CA-8 | Sí: pantalla (sin dato en vivo, lectura guardada con `pump_active: 1`) y provider (desconectado, otra planta, demo, limpieza, `selectPlant`, respuesta vieja) | Sí (F1, F8, F9, F10, F11) | — |
| CA-9 | Sí: «Deteniendo…» con spinner, confirmación, confirmación en la segunda consulta y que no aparezca «completado» | Sí (F2, F3, F6, F12) | No cubre una detención confirmada mientras `activateWatering` sigue en vuelo (obs. 1). |
| CA-10 | Sí: a los 10 s con la bomba encendida y al dejar de estar en línea | Sí (F3, F4, F7) | — |
| CA-11 | Sí: pantalla (mensaje del servidor, mensaje fijo, reintento) y provider (200, 503, 409, sin servidor, limpieza de `error`) | Sí | — |
| CA-12 | Sí: doble toque antes y después de que el API acepte, y cierre de la pantalla en tres momentos | Sí (F5) | La guarda `if (_isStopping) return;` es redundante con `onTap: null` y ninguna prueba la aísla. Es aceptable. |
| CA-13 | Sí: texto exacto en las pruebas de confirmación | Sí | — |
| CA-14 | Manual (T8) | — | Sin hacer: requiere la placa. |

## Observaciones

| # | Gravedad | Observación | Decisión del equipo | Motivo |
|---|---|---|---|---|
| 1 | media | **«Detener riego» se queda pegado con la bomba apagada.** `frontend/lib/screens/plant/plant_detail_screen.dart:92-93`: al volver `activateWatering`, se pone `_waterAccepted = true` sin comprobar `run == _waterRun`. Ocurre si la detención se confirma mientras la petición de «Regar» sigue en vuelo: el refresco de 3 s vio la bomba encendida, la persona tocó «Detener riego» y se confirmó. Entonces `_waterAccepted` pasa a `true` después de la confirmación, y a los 10 s no se limpia porque `run != _waterRun` (línea 98). La pantalla muestra «Detener riego» indefinidamente con la bomba apagada en vivo y oculta «Regar», hasta que se toca otra vez o se sale. Lo reproduje con una prueba de widget propia en el scratchpad (R1): a los 15 s, «Detener riego» visible: `true`; «Regar» visible: `false`. Pasa con una red lenta (POST y GET de `activateWatering` de más de ~1 s). No enciende la bomba, pero contradice CA-9 («vuelve el botón Regar»). | | |
| 2 | media | **La confirmación no comprueba que el «apagado» sea posterior al `STOP`.** `plant_detail_screen.dart:151-163` da por confirmada la detención con cualquier `livePumpOn == false`. En el camino de CA-7 «después de aceptar Regar, aunque el ESP8266 aún no haya informado», ese `false` puede ser el valor de `LATEST_DATA["led_encendido"]` de **antes** del `WATER`. Pasa si el firmware no procesó los comandos, por ejemplo si está colgado con el puerto abierto: entonces la app dice «Riego detenido» sin que el ESP8266 haya informado nada. Eso choca con la frase de la spec «solo dice “Riego detenido” cuando el ESP8266 informa que la bomba se apagó de verdad». Riesgo físico bajo: si el firmware no procesó `WATER`, la bomba no se encendió. Se podría exigir ver primero `true` y luego `false`, o una marca de tiempo posterior al `STOP`. Si se acepta, conviene anotarlo en «Riesgos» del plan. | | |
| 3 | baja | **«Deteniendo…» se queda para siempre si `loadSensorData` lanza.** `_handleStopWatering` (`plant_detail_screen.dart:134-182`) no tiene `try/finally`. Si `loadSensorData` lanza (línea 154), `_isStopping` queda en `true` y no hay botón para regar ni para detener hasta salir de la pantalla. Lo reproduje con un fake que lanza (R2). Con el provider real solo puede pasar en la rama demo con `_plants` vacía (`plant_provider.dart:211-214`, `_plants.first`), que no es el flujo normal porque se entra desde la lista de plantas. Queda como robustez. | | |
| 4 | baja | **«¡Riego completado exitosamente!» después de «no confirmó».** Si la detención no se confirma (CA-10), `_waterRun` no cambia y a los 10 s de «Regar» aparece «completado» (lo reproduje en R3), justo después de avisar que el ESP8266 no confirmó el apagado. La spec (decisión 8) solo lo quita cuando se confirma, y el plan lo anota en «Riesgos» y en «Diferencias» como una decisión que la responsable no tomó expresamente. Conviene que la responsable lo confirme. | | |
| 5 | baja | **La petición de detener no tiene tiempo límite.** `ApiService` no fija un `timeout` (es previo a la spec). Si el servidor no responde, «Deteniendo…» dura lo que tarde el sistema operativo en cortar la conexión. CA-11 cubre que el servidor no responda solo cuando hay una excepción. | | |
| 6 | baja | `backend/tests/test_controles_riego.py:255-260` (`test_regar_sin_esp8266_devuelve_503`) solo mira el código 503: no comprueba el mensaje ni que se intentara enviar `WATER:10`. Es menor: CA-6 solo pide «503 si está desconectado». | | |
| 7 | baja | En `backend/app/routers/controls.py`, `settings = get_settings()` (línea 19) quedó sin uso, como dice «Diferencias con lo planeado». Además, el docstring y los comentarios de `activate_watering` (líneas 43-50) todavía hablan de «comando MQTT al ESP32», contra `CLAUDE.md`, que dice que no hay ESP32 ni MQTT. Ambas cosas son previas a la spec y la función se tocó. | | |
| 8 | baja | **Aviso de commit (no es un hallazgo del código):** `frontend/lib/config/api_constants.dart` tiene un `baseUrl` local (`10.97.203.53`). No debe entrar en ningún commit: hay que añadir los archivos uno por uno, como dice `tasks.md`. Además, todavía no hay ningún commit en la rama: T1-T6 están marcadas `[x]` y sus pruebas pasan, pero los mensajes de commit sugeridos quedan pendientes. | | |

Seguridad (sin hallazgos):
- Cada ruta exige sesión: el 401 está probado.
- Planta ajena, inexistente o borrada: 404 antes de enviar nada.
- Planta propia que no es la del ESP8266: 409.
- ESP8266 de otro usuario: 409, porque `get_device_plant_for_user` exige el dueño.
- Con `ESP8266_PLANT_ID` sin configurar, solo controla la bomba el dueño de la planta activa más antigua (de cualquier usuario). Las plantas de otros usuarios reciben 409.
- `ESP8266_PLANT_ID` se lee en cada petición.
- No se envía nada por serial antes de las comprobaciones (B4).

Veracidad en la app:
- «Detener riego» solo sale de `livePumpOn`, que la rama de base y la de demo dejan en `null`.
- «Riego detenido» solo sale con `livePumpOn == false` (ver obs. 2).
- Los SnackBars de error muestran el `detail` del servidor.

`context` y `setState` después de un `await`: cada `await` va seguido de `if (!mounted) return;`, y las
tres pruebas de cierre de la pantalla pasan sin excepciones.

## Lo que esta revisión no pudo comprobar

- **Bomba real (CA-14, T8):**
  - si la bomba se apaga físicamente en 3 s o menos;
  - el retraso real entre `STOP` y «BOMBA APAGADO» en `LATEST_DATA` (el hilo lee una línea cada 100 ms);
  - el comportamiento con el USB desconectado;
  - la pausa de 5 minutos tras detener un riego automático.
- **Concurrencia real con el refresco de 3 s:** las pruebas de widget corren sin sesión, así que el `Timer.periodic` no arranca. Los escenarios R1-R3 se probaron con un provider falso y tiempo falso, no con red real.
- **Aspecto visual:** cómo se ve «Detener riego» y «Deteniendo…» y los colores de los SnackBars en Chrome y en el emulador. Las pruebas solo miden el desborde a 320 y 360 px.
- Webcam y Gemini: no aplican a esta spec.
- No ejecuté la CI de GitHub: solo los comandos locales de `CLAUDE.md`.

## Comprobación de la corrección (segunda vuelta, 2026-11-12)

Revisé otra vez el árbol de trabajo de `feat/003-detener-riego`, que sigue sin commits. No di por
cierto el resumen de «Corrección tras la revisión» del plan: lo comprobé.

### Verificación ejecutada

| Comprobación | Resultado |
|---|---|
| `python -m pytest -q --cov --cov-config=.coveragerc` | **155 passed**, 9 warnings (las mismas deprecaciones de Pydantic). Cobertura total **69,52 %** (umbral 60 %). `controls.py` queda en 83 %: sin cubrir 59-60 y 92-93 (los 500 por excepción) y 119-128 (`/status`). |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | **38 issues**. La lista es idéntica a la de la primera revisión, que a su vez era la de `main`: **no hay avisos nuevos**. |
| `flutter test` | **120 pruebas, «All tests passed!»** (118 más las 2 nuevas). |
| Cambios en `esp8266_maceta_inteligente/` | Ninguno: `git diff --quiet main` y `git status` salen limpios en esa carpeta. Tampoco hay cambios en `database/` ni en `seed_data.py`. |
| ¿Se debilitó alguna prueba anterior? | No. Comparé con la copia de las pruebas guardada en la primera revisión. En `plant_detail_stop_watering_test.dart` solo se agregaron dos campos opcionales al fake (`activateCompleter` y `sensorLoadError`, nulos por defecto, sin efecto en las pruebas anteriores) y el grupo «Revisión · obs. 1 y 3» (línea 726). En `test_controles_riego.py` solo se agregó `test_regar_sin_esp8266_devuelve_503_con_mensaje`. `plant_provider_stop_watering_test.dart`, `test_hardware_service.py`, `test_seguridad_hardware.py`, `plant_provider.dart` y `hardware_service.py` no cambiaron. |

### Mutantes que deshacen cada corrección (copias en el scratchpad)

| Mutante | Resultado |
|---|---|
| M1 · quitar `if (run != _waterRun) return;` (`plant_detail_screen.dart:78`) | Muere: falla `si Regar termina con éxito después de confirmar la detención no vuelve Detener riego ni Riego completado`. |
| M2 · quitar el `try/catch` de `loadSensorData` (`plant_detail_screen.dart:156-163`) | Muere: falla `si loadSensorData lanza una excepción durante la confirmación sale de Deteniendo y avisa que no se confirmó`. |
| M3 · en el `catch`, seguir esperando (`continue`) en vez de cortar | Muere: falla la misma prueba. |
| M4 · cambiar el texto del 503 de `water` en `controls.py` | Muere: falla `test_regar_sin_esp8266_devuelve_503_con_mensaje`. |

### Regresiones buscadas (pruebas de widget propias, solo en el scratchpad)

- **G1 · «Regar» obsoleto que termina con error.** Se confirma la detención mientras «Regar» sigue en
  vuelo, y después el API rechaza ese «Regar».
  - Resultado: «Regar» visible y habilitado, sin spinner. `_isWatering` **no** queda en `true`, porque
    la detención confirmada ya lo había puesto en `false`.
  - Un `run` solo queda obsoleto por una detención confirmada (que limpia `_isWatering`) o por un
    «Regar» más nuevo (que maneja su propio estado).
  - Efecto lateral: el SnackBar de error de ese «Regar» viejo no se muestra (obs. 9).
- **G2 · regar → detener → regar seguido.**
  - Tras vencer el plazo de 10 s del primer «Regar», «Detener riego» sigue visible por el segundo.
  - «¡Riego completado exitosamente!» aparece una sola vez, a los 10 s del segundo «Regar».
  - Al final vuelve «Regar».
- **G3 · segundo «Regar» con el primero (obsoleto) todavía en vuelo.** El primero se ignora y el
  segundo sigue su flujo normal: un «completado» y vuelve «Regar».
- **R1 y R2 de la primera revisión** quedan cubiertos por las dos pruebas nuevas del grupo
  «Revisión · obs. 1 y 3».

**`_isStopping` sin `try/finally`.** Revisé los caminos de `_handleStopWatering`:
- con la pantalla montada, todos terminan en `_isStopping = false`: error del API, confirmado, no
  confirmado, `null` y excepción de `loadSensorData`;
- los `return` con `!mounted` no importan, porque el `State` ya no existe;
- el único camino sin cubrir sería una excepción de `stopWatering` (línea 138), pero el provider real
  captura todas las excepciones y devuelve `false`.

No lo considero un hallazgo.

### Estado de las observaciones

| # | Gravedad | Estado | Comprobación |
|---|---|---|---|
| 1 | media | **Corregida** | `plant_detail_screen.dart:76-78`: `mounted` y `run != _waterRun` justo después de `await activateWatering`, antes de `!ok` y de `_waterAccepted = true`. Prueba nueva verificada con el mutante M1; sin regresiones (G1-G3). |
| 2 | media | **Pendiente por decisión de la responsable** | Sin cambios. Una lectura «bomba apagada» anterior al `WATER` puede contar como confirmación. Queda anotado en «Diferencias con lo planeado». |
| 3 | baja | **Corregida** | `plant_detail_screen.dart:156-163`: `try/catch` y `break`, así que se avisa «no confirmó» y se sale de «Deteniendo…». Verificada con M2 y M3. |
| 4 | baja | **Pendiente por decisión de la responsable** | Sin cambios: tras «no confirmó» todavía puede salir «completado» a los 10 s. |
| 5 | baja | **Pendiente (anterior a la spec)** | `ApiService` sigue sin tiempo límite. |
| 6 | baja | **Corregida** | `test_regar_sin_esp8266_devuelve_503_con_mensaje` (`test_controles_riego.py:263-272`) comprueba el mensaje exacto; verificada con M4. |
| 7 | baja | **Corregida en parte** | Se quitó `settings` sin uso y se corrigió el docstring de `water`. Quedan `# Construir comando MQTT` (`controls.py:48`, dentro de `water`, junto a un diccionario `command` que no se usa) y `# En producción, se consulta al ESP32 vía MQTT` (`controls.py:127`, `/status`, fuera de alcance). El plan lo declara. |
| 8 | baja | **Pendiente (aviso de commit)** | `api_constants.dart` sigue con la IP local y la rama sigue sin commits: hay que añadir los archivos uno por uno. |

### Hallazgos nuevos

| # | Gravedad | Observación | Decisión del equipo | Motivo |
|---|---|---|---|---|
| 9 | baja | `plant_detail_screen.dart:78`: si un «Regar» obsoleto termina con error, el `return` evita mostrar el error del API. Lo reproduje en G1. Es coherente con el estado real (la detención se confirmó y la bomba está apagada), pero roza la regla «un fallo del API se le muestra al usuario». Opcional: mostrar el SnackBar de error aunque `run` esté obsoleto, sin tocar el estado. | | |

### Veredicto final

**APROBADA CON OBSERVACIONES.**
- No hay observaciones de gravedad alta y todas las verificaciones dan verde.
- Quedan abiertas a decisión de una persona la obs. 2 (media) y las obs. 4, 5, 7 (en parte), 8 y 9
  (bajas).
- Sigue sin comprobarse lo mismo que en la primera revisión: la bomba real (CA-14 y T8), el refresco de
  3 s con red real, el aspecto visual y la CI de GitHub.
