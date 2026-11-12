# Spec 004 · Cálculo único de salud

- **Estado:** aprobada
- **Rama:** `feat/004-calculo-unico-salud`
- **Responsable:** Valentina Bermeo

## Qué se construye

La planta tiene un solo «estado según sensores». Sale de una sola regla, que usa la humedad del suelo
y la temperatura con los umbrales de esa planta, y la calcula siempre el backend. La app lo muestra
igual venga la lectura en vivo del ESP8266 o de la última lectura guardada: con una etiqueta en el
detalle, con la cara de la planta animada y con el resaltado del botón «Regar». El diagnóstico IA de
la foto (spec 002) sigue siendo otra cosa, con otro nombre, y no se mezcla con este estado.

## Por qué

**Hallazgo principal: la sospecha es cierta.** Hoy la salud según sensores se calcula en **dos**
sitios con reglas distintas: el backend y el `PlantProvider` de la app. Además, la app aplica umbrales
propios sobre el puntaje para dibujar la cara. Por eso la misma lectura de la misma planta se ve
distinta según de dónde venga, y a veces se contradice dentro de una misma pantalla. No hay ninguna
prueba sobre esa salud.

### Dónde se calcula o se asigna hoy

| # | Sitio | Entradas | Reglas | Salida y formato |
|---|---|---|---|---|
| 1 | `backend/app/routers/sensors.py` 22-64 (`calculate_health`, dentro del router y no en `services/`), usado en `GET /api/sensors/latest/{plant_id}` (98-111) | humedad del suelo, temperatura y **luz** de la última lectura guardada, y los umbrales de la planta `min_humidity`, `max_temperature` y `min_light` (`backend/app/models/plant.py` 50-53) | resta `min(2×déficit de suelo, 40)`, `min(3×exceso de temperatura, 30)` y `min(1,5×déficit de luz, 30)`. El estado sale por tramos: ≥70 `healthy`; 40-69 `needs_water`, `needs_light` o `stressed`; <40 `critical` | `health_status` en **inglés y minúsculas** (`"healthy"`, `"needs_water"`, `"needs_light"`, `"stressed"`, `"critical"`) y `health_score` de 0 a 100 |
| 2 | `sensors.py` 90-96, cuando la planta no tiene lecturas | ninguna | valor fijo | `"unknown"` y `50.0`. Ese 50 es inventado |
| 3 | `backend/app/schemas/sensor_data.py` 64-66 (`SensorLatestResponse`) | — | valores por defecto | `"healthy"` y `100.0`. El comentario dice «saludable, necesita_agua, necesita_luz, critico», que no son los valores que viajan |
| 4 | `frontend/lib/providers/plant_provider.dart` 160-190, cuando el ESP8266 está «En línea» en esa planta (`GET /api/hardware/clima-actual`) | humedad del suelo y temperatura en vivo, `minHumidity` y `maxTemperature`. No usa la luz | resta `2×déficit` y `3×exceso` **sin tope**. Pone `needs_water` en cuanto el suelo baja del mínimo, sea cual sea el puntaje; `stressed` si solo hay calor; `critical` si el puntaje es <40 | mismas cadenas en inglés y puntaje propio. La luz (85), el voltaje (12,4) y la batería (98) son constantes escritas en 183-185 |
| 5 | `plant_provider.dart` 157 | si falta `humedad_suelo`, usa `humAire` | trata la humedad del **aire** como si fuera la del suelo | — |
| 6 | `plant_provider.dart` 215 y `frontend/lib/screens/plant/plant_detail_screen.dart` 214-216 → `SensorDataModel.demo` (`frontend/lib/models/sensor_data_model.dart` 65-80) | ninguna | valor fijo cuando falla el API y antes de la primera carga | `"healthy"` y `85.0`, inventados |
| 7 | `sensor_data_model.dart` 30-31 y 56-57 | — | valores por defecto del modelo y de `fromJson` | `'healthy'`/`100` y `'unknown'`/`50` |
| 8 | `sensor_data_model.dart` 36 (`isHealthy`: puntaje ≥ 60) y `frontend/lib/widgets/animated_plant.dart` 133-134 (`_isHealthy` ≥ 60 y `_isCritical` < 30) | puntaje | **umbrales propios de la app (60 y 30)**, distintos de los del backend (70 y 40) | cara feliz, triste o crítica, color de las hojas y caída (`animated_plant.dart` 182-188, 397-409). El widget recibe `healthStatus` (21-22) pero no lo usa |
| 9 | `sensor_data_model.dart` 39-43 (`needsWater`, `needsLight`) | estado | `needsWater` = `needs_water` o `critical`. `needsLight` no se usa en ninguna parte | resalta en rojo el botón «Regar» (`plant_detail_screen.dart` 520, 547-548) |
| 10 | `plant_detail_screen.dart` 233-239 | `isHealthy` | elige el texto del clima según la salud | «Parcialmente nublado» / «Parcialmente soleado». Es un clima inventado (le corresponde a la spec 005) |

Luz, voltaje solar y batería no son lecturas reales. En el backend, `_guardar_datos_en_db` guarda luz
85, voltaje 12,4 y batería 95 fijos (`backend/app/utils/hardware_helper.py` 280-283). En
`backend/seed_data.py` 147-153 son números al azar (luz entre 10 y 90). La regla 1 **resta puntos por
esa luz**. Con el ESP8266 no se nota, porque 85 supera el `min_light` de todas las plantas. Con los
datos de `seed_data.py`, en cambio, la luz al azar cambia el estado.

Ninguna pantalla muestra hoy el estado según sensores como texto. Solo se ve en la cara de la planta
animada y en el color de «Regar». Inicio (`frontend/lib/screens/home/home_screen.dart` 589-656), Mis
plantas y Estadísticas no muestran salud. La caja de lecturas de Inicio usa valores de relleno
(«25.0», «50.0») cuando falta un dato, pero eso le toca a la spec 005.

### Lo que hoy también se llama «salud» y es otra cosa: el diagnóstico IA

- `backend/app/services/hardware_service.py` 17-26 y 77-98 (`parse_health_status`) deducen un estado
  del apartado «ESTADO GENERAL» del texto de Gemini. «Saludable» se guarda como `Buena`, «leve» como
  `Regular`, «moderado» como `Mala` y «crítico» como `Critica`; si no lo reconoce, guarda `Regular`.
  Se guarda en `AIDiagnosis.health_status` (`save_diagnosis`, 122) con el enum `HealthStatus`
  (`backend/app/models/recommendation.py` 11-17: `Excelente`, `Buena`, `Regular`, `Mala`, `Critica`).
  `Excelente` nunca sale de Gemini; solo puede venir de datos sembrados.
- La app lo muestra en el historial de diagnósticos (`frontend/lib/screens/plant/diagnosis_history_screen.dart`
  39-52, 194, 242), con `DiagnosisModel.healthLabel` (`frontend/lib/models/diagnosis_model.dart` 53,
  que pone la tilde en «Crítica»).
- `backend/seed_data.py` 252-254 siembra un diagnóstico `Buena` para la primera planta.
- `frontend/lib/screens/recommendations/recommendations_screen.dart` 59-69 tiene un texto fijo,
  «Estado general: Bueno (87% confianza)», que no viene de ningún dato.
- `GET /api/hardware/clima-actual` (`backend/app/routers/hardware.py` 21-52) no calcula salud. Solo
  devuelve lecturas. Cuando el ESP8266 está desconectado, esas lecturas son los valores iniciales de
  `LATEST_DATA` (25 °C, 50 %, 50 %; `hardware_helper.py` 17-25).

Este diagnóstico mira una foto en un momento dado. El estado según sensores mira la última lectura.
Pueden no coincidir sin que haya error: una planta con hojas sanas puede tener la tierra seca. El
problema es que hoy ninguno de los dos se presenta con su nombre.

### Ejemplo concreto de inconsistencia

Se usa la Echeveria de `seed_data.py` (`min_humidity` 25, `max_temperature` 35, `min_light` 30). Es
la planta activa más antigua y, por tanto, la del ESP8266 si no se define `ESP8266_PLANT_ID`. El
detalle se refresca cada 3 s. Mientras el ESP8266 está «En línea» calcula la regla 4; si se
desconecta, toma la lectura guardada (de hace como mucho un minuto) y calcula la regla 1.

| Lectura | En vivo (regla 4) | Lectura guardada (regla 1, luz 85) | Qué ve la persona |
|---|---|---|---|
| suelo 20 %, 28 °C | `needs_water`, 90 | `healthy`, 90 | Con el USB conectado, «Regar» sale en rojo. Al desconectarlo, la misma lectura deja «Regar» normal |
| suelo 0 %, 28 °C | `needs_water`, **50** (sin tope) | `needs_water`, **60** (tope 40) | En vivo, la cara está **triste** (50 < 60). Desde la base, **feliz** (60 ≥ 60) |
| suelo 7,5 %, 28 °C | `needs_water`, 65 | `needs_water`, 65 | Con cualquiera de las dos fuentes, la **misma pantalla** muestra «Regar» en rojo («necesita agua») y la cara **feliz** (65 ≥ 60, el umbral de la app) |
| sin lecturas | — | `unknown`, 50 | Cara triste y clima «Parcialmente soleado». Si en cambio falla el API: `healthy`, 85, cara feliz |

Otro caso, el de la luz de relleno: Geranios (`min_humidity` 35, `max_temperature` 30, `min_light`
50), con una lectura sembrada de suelo 25 %, 25 °C y luz 15. Da `needs_water` con 50 y cara triste.
Sin la luz, que no es real, daría 80 y cara feliz.

### Pruebas que existen sobre «salud»

- Diagnóstico IA: `backend/tests/test_hardware_service.py` 61-121 (`parse_health_status` y el estado
  que guarda `save_diagnosis`), `backend/tests/test_ai_diagnoses.py` 105-121 (el estado viaja en
  español), `frontend/test/diagnosis_provider_test.dart` y `frontend/test/diagnosis_history_screen_test.dart`.
- Estado según sensores: **ninguna**. No hay pruebas de `calculate_health` ni de `health_status` en
  `GET /api/sensors/latest`. Las de `clima-actual` (`backend/tests/test_seguridad_hardware.py` 83-101)
  solo prueban la sesión. En la app, `frontend/test/plant_provider_stop_watering_test.dart` 48 pone
  `health_score: 90` en un JSON de prueba, pero no comprueba nada de salud. Nada prueba la cara ni el
  resaltado de «Regar».

## Fuera de alcance

- **Los datos demo y su aviso (spec 005):** los valores de `SensorDataModel.demo`, los rellenos
  «25.0» y «50.0» de Inicio, la luz, el voltaje y la batería que se muestran, el texto del clima de
  `WeatherBar`, los textos fijos de Recomendaciones y Notificaciones, y
  `GET /api/controls/status/{plant_id}`. Esta spec solo dice qué estado de salud se muestra cuando no
  hay lecturas o falla el API (CA-9 a CA-11). No cambia los números demo de las lecturas.
- **El diagnóstico IA:** cómo se deduce `health_status` del texto de Gemini, el enum `HealthStatus`,
  el prompt y el historial de la spec 002 quedan igual.
- Combinar el diagnóstico IA y los sensores en una sola nota de salud.
- Mostrar el estado según sensores en Inicio, Mis plantas o Estadísticas. Hoy no aparece ahí y no se
  añade.
- Tener en cuenta la humedad del aire, la luz, el voltaje o la batería.
- Avisar de que la última lectura guardada es vieja (antigüedad de `recorded_at`).
- Cambiar los umbrales de las plantas o añadir una pantalla para editarlos. No hace falta ninguna
  columna nueva: `min_humidity` y `max_temperature` ya existen. `min_light` se queda en la tabla,
  pero deja de contar.
- Filtrar las plantas borradas en `GET /api/sensors/latest`. Que `clima-actual` devuelva el
  `plant_id` del ESP8266 aunque la planta sea de otro usuario.
- `backend/seed_data.py`, `database/init.sql` y el firmware.

## Criterios de aceptación

En las pruebas automáticas no se usan un ESP8266, un puerto serial, la webcam ni HTTP reales.
«Echeveria» es una planta con `min_humidity` 25 y `max_temperature` 35. Los valores, el formato y la
regla son los que decidió la responsable (ver «Preguntas abiertas»).

**La regla (backend).** El estado según sensores se calcula solo con la humedad del suelo y la
temperatura de la lectura, comparadas con `min_humidity` y `max_temperature` de esa planta.

- Puntaje: se parte de 100. Si el suelo está por debajo del mínimo, se resta `min(2 × déficit, 40)`.
  Si la temperatura supera el máximo, se resta `min(3 × exceso, 30)`. Se redondea a un decimal.
  Estar justo en el umbral no cuenta como problema.
- Estado: puntaje < 40 → `"Critica"`. Si no, suelo por debajo del mínimo → `"Necesita agua"`. Si no,
  temperatura por encima del máximo → `"Exceso de calor"`. Si no, `"Sana"`. Sin humedad del suelo →
  `"Sin datos"`.

- **CA-1. Caso normal.** Dada la Echeveria con su última lectura guardada, cuando se pide
  `GET /api/sensors/latest/{id}`, entonces `health_status` y `health_score` son exactamente:

  | Suelo (%) | Temperatura (°C) | `health_status` | `health_score` |
  |---|---|---|---|
  | 50 | 28 | `"Sana"` | 100.0 |
  | 25 | 35 | `"Sana"` | 100.0 |
  | 20 | 28 | `"Necesita agua"` | 90.0 |
  | 0 | 28 | `"Necesita agua"` | 60.0 |
  | 50 | 40 | `"Exceso de calor"` | 85.0 |
  | 15 | 45 | `"Necesita agua"` | 50.0 |
  | 0 | 45 | `"Critica"` | 30.0 |

- **CA-2. La luz, el voltaje y la batería no cuentan.** Dada cualquier fila de CA-1, cuando la
  lectura guardada tiene luz 0 u 85, cualquier voltaje solar y cualquier batería, y la planta tiene
  cualquier `min_light`, entonces `health_status` y `health_score` son los mismos de CA-1.
- **CA-3. Formato.** Dada cualquier respuesta con estado según sensores, entonces `health_status` es
  uno de estos cinco valores en español con mayúscula inicial: `"Sana"`, `"Necesita agua"`,
  `"Exceso de calor"`, `"Critica"`, `"Sin datos"`. Nunca viaja `"healthy"`, `"needs_water"`,
  `"needs_light"`, `"stressed"`, `"critical"` ni `"unknown"`.
- **CA-4. Planta sin lecturas.** Dada una planta del usuario sin ninguna lectura, cuando se pide
  `GET /api/sensors/latest/{id}`, entonces responde 200 con `health_status: "Sin datos"`,
  `health_score: null` y las lecturas en `null`. No se devuelve un 50 ni un 100 inventados.
- **CA-5. Lectura incompleta.** Dada una última lectura sin humedad del suelo, entonces el estado es
  `"Sin datos"` con `health_score: null`. Dada una lectura con humedad del suelo y sin temperatura,
  entonces el estado se calcula solo con el suelo (suelo 20 → `"Necesita agua"`, 90.0).
- **CA-6. Planta ajena o inexistente.** Dado un usuario con sesión, cuando pide
  `GET /api/sensors/latest/{id}` de una planta de otro usuario o de un id que no existe, entonces
  recibe 404 «Planta no encontrada» y no se devuelve ningún estado. Sin sesión recibe 401.
- **CA-7. En vivo, la misma regla.** Dado el ESP8266 «En línea» en la planta del ESP8266 del usuario
  (la Echeveria), con suelo 20 % y 28 °C, cuando se pide `GET /api/hardware/clima-actual`, entonces
  la respuesta incluye el estado según sensores calculado por el backend: `"Necesita agua"` y 90.0,
  lo mismo que da CA-1 para esa lectura guardada. Para cada fila de CA-1, en vivo y desde la base se
  obtiene el mismo resultado.
- **CA-8. En vivo sin datos válidos.** Dado el ESP8266 desconectado (lecturas iniciales 25 °C y 50 %),
  o una planta del ESP8266 que no es del usuario, cuando se pide `clima-actual`, entonces el estado
  según sensores viene vacío (`null`) y no se calcula a partir de esos valores.

**La app.** La app no calcula el estado: muestra el que manda el backend.

- **CA-9. Lo que se ve según el estado.** Dado el detalle de una planta, cuando el estado según
  sensores recibido es el de la tabla, entonces se ve:

  | Estado | Etiqueta en el detalle | Planta animada | Botón «Regar» |
  |---|---|---|---|
  | `Sana` | «Según sensores: Sana» | feliz | normal |
  | `Necesita agua` | «Según sensores: Necesita agua» | triste | resaltado |
  | `Exceso de calor` | «Según sensores: Exceso de calor» | triste | normal |
  | `Critica` | «Según sensores: Crítica» | crítica | resaltado |
  | `Sin datos` | «Según sensores: sin lecturas» | ni triste ni crítica | normal |

  La cara no depende del puntaje: un `Necesita agua` con 65 se ve triste, y un `Sana` con 90 se ve
  feliz. El texto «Según sensores:» con su valor cabe en pantallas de 320 y 360 px de ancho sin
  desbordarse.
- **CA-10. La misma planta, la misma cara.** Dada la planta del ESP8266, cuando la app recibe un
  estado del backend en vivo (`clima-actual`) y luego, al desconectarse el ESP8266, el de la última
  lectura guardada (`latest`), y los dos son `"Necesita agua"`, entonces la etiqueta, la cara y
  «Regar» no cambian. Si el backend en vivo manda `"Sana"` aunque las lecturas parezcan secas, la app
  muestra «Sana»: no recalcula nada.
- **CA-11. Sin lecturas o con error del API.** Dada una planta sin lecturas (CA-4), o un fallo de
  `GET /api/sensors/latest` (servidor caído o error), o la pantalla antes de que llegue la primera
  respuesta, cuando se muestra el detalle, entonces se ve la fila `Sin datos` de CA-9. Nunca se
  muestran «Sana», una cara feliz por un puntaje inventado ni «Regar» resaltado. El aviso de que las
  lecturas son demo es cosa de la spec 005.
- **CA-12. El diagnóstico IA es otra cosa.** Dada una planta con un último diagnóstico IA `Buena` y
  estado según sensores `Necesita agua`, cuando se abren el detalle y el historial de diagnósticos,
  entonces el detalle muestra «Según sensores: Necesita agua» y el historial sigue mostrando «Buena»
  con su color de siempre. El estado del diagnóstico no cambia la etiqueta, la cara ni «Regar», y el
  estado según sensores no cambia el historial. Las pruebas de la spec 002 siguen pasando sin
  cambios.

**Verificación manual con la placa:**

- **CA-13. Sensor real.** Con el ESP8266 conectado por USB en la planta del usuario y el sensor de
  humedad en el aire (suelo cercano a 0 %), el detalle muestra «Según sensores: Necesita agua», la
  cara triste y «Regar» resaltado. Al desconectar el USB, antes de que pase un minuto, el detalle
  sigue mostrando lo mismo, ahora sacado de la lectura guardada.

## Preguntas abiertas

- Ninguna. La responsable (Valentina Bermeo) aprobó la spec el 2026-11-12 con estas decisiones:
  1. **Dos conceptos, sin unificar.** El estado «Según sensores» (esta spec: `Sana`, `Necesita agua`,
     `Exceso de calor`, `Critica`, `Sin datos`) y el «Diagnóstico IA» (spec 002: `Excelente` …
     `Critica`, sin cambios) son cosas distintas, con nombres distintos (CA-12). Miden cosas
     distintas (la última lectura frente a una foto) y pueden no coincidir sin que haya error.
  2. **Variables.** Solo cuentan la humedad del suelo y la temperatura. La luz, el voltaje y la
     batería son de relleno y no deciden nada. La humedad del aire no tiene umbral por planta (CA-2).
  3. **Umbrales por planta**, con `min_humidity` y `max_temperature`, que ya existen. Sin columnas
     nuevas ni migraciones.
  4. **Regla.** El puntaje se calcula como hoy en el backend, pero sin la luz. El estado se decide
     por umbrales de la planta: `Critica` si el puntaje es menor que 40; si no, `Necesita agua` si el
     suelo está por debajo del mínimo; si no, `Exceso de calor` si la temperatura supera el máximo;
     si no, `Sana` (CA-1).
  5. **Formato.** El estado viaja en español con mayúscula inicial (`Sana`, `Necesita agua`,
     `Exceso de calor`, `Critica`, `Sin datos`). Es un cambio de contrato aceptado (CA-3).
  6. **Puntaje.** Se conserva en `health_score` (de 0 a 100, y `null` sin datos), pero la app no
     decide nada con él: la cara y «Regar» dependen solo del estado (CA-9).
  7. **Sin datos.** Se muestra `Sin datos` cuando no hay lecturas, cuando la lectura no trae humedad
     del suelo, cuando el API está caído y antes de la primera carga. Nunca se usa la humedad del
     aire en lugar de la del suelo (CA-4, CA-5, CA-11).
  8. **Cara con `Sin datos`.** Ni triste ni crítica (CA-9).
  9. **Etiqueta.** Se añade en el detalle la etiqueta «Según sensores: …», y solo ahí (CA-9).
  10. **Estado en vivo.** Lo calcula el backend en `clima-actual`, solo con el ESP8266 «En línea» y
      su planta perteneciente al usuario (CA-7, CA-8).
