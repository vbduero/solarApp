# Revisión · Spec 004

- **Revisado por:** agente `revisor`
- **Commit revisado:** ninguno propio. La rama `feat/004-calculo-unico-salud` no tiene commits y
  `HEAD` es `70f34fd`, igual que `main`. Se revisó el árbol de trabajo del 2026-11-12: `git diff main`
  más los archivos sin seguimiento de `git status --short`.
- **Veredicto:** APROBADA CON OBSERVACIONES

## Verificación ejecutada

| Comprobación | Resultado |
|---|---|
| `python -m pytest -q --cov --cov-config=.coveragerc` | **249 passed**, 9 warnings (las de siempre: `class Config` de Pydantic), 7,62 s. Cobertura total **72,63 %**; el umbral es 60 %. `health_service.py` tiene cobertura completa: es uno de los 23 archivos que se omiten del informe por estar al 100 %. `sensors.py` está al 98 %. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | Código de salida 0. **33 issues** en la rama frente a **38** en `main`, medido sobre una copia de `main` en el scratchpad. Se compararon las dos listas sin números de línea. **Ningún aviso nuevo.** Los 5 que desaparecen son todos de `lib/providers/plant_provider.dart`, en las líneas 163-169 de `main`: 1 `dead_code` y 4 `dead_null_aware_expression` (`plant.minHumidity ?? 25.0` y `plant.maxTemperature ?? 35.0`, cuando esos campos no pueden ser nulos). Estaban en el cálculo de salud propio de la app, que esta spec borra. |
| `flutter test` | **172 pruebas, «All tests passed!»**, código de salida 0. |
| Archivos cambiados dentro del alcance del plan | Sí. Los 7 archivos de código modificados y los 6 nuevos (servicio y 5 pruebas) están en la tabla «Archivos que se tocan». El único cambio que queda fuera es `frontend/lib/config/api_constants.dart` (`baseUrl` → `http://10.97.203.53:8000`): es un cambio local de la responsable, ajeno a la spec, y **no debe entrar en ningún commit** (ver obs. 6). `git diff main --name-only` no muestra nada en `esp8266_maceta_inteligente/`, `backend/seed_data.py`, `database/`, `backend/tests/` ni `frontend/test/`, así que **no se modificó ninguna prueba existente**. No hay `.env`, `venv/`, `build/` ni imágenes. |

## Criterios de aceptación

Se comprobó si las pruebas pueden fallar con mutantes, en copias de `backend/` y `frontend/` dentro del
scratchpad. Las copias sin cambios pasan: 122 pruebas en las 3 suites de backend que se usaron y 52
en las 3 suites nuevas de la app.

| Criterio | ¿Tiene prueba? | ¿La prueba puede fallar? | Observación |
|---|---|---|---|
| CA-1 | Sí. `test_regla_de_salud_da_estado_y_puntaje_de_la_tabla` (7 filas de la tabla y 4 bordes), redondeo, umbrales nulos y uno solo nulo en `test_health_service.py`. `test_latest_devuelve_estado_y_puntaje_de_la_tabla` y la de umbrales en `test_salud_sensores.py`. | Sí. Fallan con `<=` en el suelo (9 pruebas), `>=` en la temperatura (8), `score <= 40` (1), tope del suelo 50 (18), sin `round` (2), valor por defecto 25 (3) y el orden de los estados cambiado (11). **No falla nada si se quita el tope de 30 de la temperatura** (obs. 1). | La regla coincide con la tabla de la spec. Las comparaciones son estrictas; con puntaje 40 no es `Critica` y con 39 sí. `min_humidity = 0` no se confunde con nulo (`is None`). |
| CA-2 | Sí. `test_latest_ignora_luz_voltaje_bateria_y_min_light` (7 filas × 4 combinaciones, con `min_light` 90 y luz 0). | Sí. Con luz 0 y `min_light` 90, cualquier resta por luz cambia el puntaje. | El servicio no recibe luz, voltaje ni batería. |
| CA-3 | Sí. `test_latest_solo_envia_los_cinco_estados_en_espanol` exige que salgan los cinco estados y ninguno viejo. En el servicio, `test_regla_de_salud_solo_devuelve_estados_en_espanol`. En la app, las de `fromJson` y `parseHealthStatus`. | Sí. Si `parseHealthStatus` deja pasar cualquier texto, fallan 6 pruebas. | — |
| CA-4 | Sí. `test_latest_sin_lecturas_devuelve_sin_datos_y_puntaje_null` comprueba también que las seis lecturas son `null`. | Sí. Fallan 4 pruebas si el puntaje vuelve a 50 cuando no hay lecturas. | — |
| CA-5 | Sí. Servicio y API: sin suelo (con temperatura `None`, 28 y 45) y sin temperatura. Provider: `en vivo sin humedad del suelo no usa la humedad del aire` y la variante con valor nulo. | Sí. Fallan 7 si se evalúa la temperatura sin suelo. En la app fallan 2 si se vuelve a usar el aire en lugar del suelo. | — |
| CA-6 | Sí. `test_latest_de_planta_ajena_o_inexistente_devuelve_404` y `test_latest_sin_token_devuelve_401`. | Ya pasaban antes de la spec (fijan el comportamiento de antes), como dice el plan. | El filtro por dueño de `sensors.py` no cambió. |
| CA-7 | Sí. `test_clima_actual_en_linea_da_la_misma_salud_que_latest` (7 filas, compara en vivo, desde la base y la tabla) y la de umbrales de la planta. | Sí. | `clima-actual` y `latest` llaman a la misma función, `calculate_sensor_health`. |
| CA-8 | Sí. Desconectado, planta del ESP8266 de otro usuario (con `min_humidity` 90, que daría otro resultado) y planta inexistente. Las tres comprueban que las claves existen y valen `null`. | Sí. Fallan 4 si se ignora el estado de conexión, y 1 si `get_device_plant_for_user` se cambia por `get_device_plant`, es decir, si se calcula con la planta ajena. | La salud en vivo nunca usa los umbrales de una planta ajena ni añade datos suyos. `plant_id` sigue saliendo de `get_device_plant`, como pide D4 (spec 003). |
| CA-9 | Sí. `plant_detail_health_test.dart`: 5 filas de la tabla, la cara según el estado y no el puntaje (65, 90, 20, 95 y `null`), y el ancho de 320 y 360 px. | La etiqueta, la cara y «Regar» sí fallan: 3 pruebas si `Sin datos` pone la cara triste, 3 si `Critica` deja de ser crítica, 3 si `needsWater` incluye `Exceso de calor` y 4 si falta la tilde de «Crítica». **La prueba de ancho no falla aunque la etiqueta se corte** (obs. 2). | — |
| CA-10 | Sí. En el provider, el mismo estado en vivo y desde la base con otros números, y el estado `Sana` del backend con suelo 0 y 45 °C. En la pantalla, el cambio de lectura con el mismo estado. | Sí. Si el provider recalcula con el suelo, fallan 3 pruebas, entre ellas `en vivo usa el estado que manda clima-actual sin recalcularlo`. | — |
| CA-11 | Sí. El provider con `ClientException` y con un 500, la pantalla antes de la primera carga, `demo()` y `Sin datos` con puntaje nulo. | Sí. Si `demo()` vuelve a `Sana`, fallan 5 pruebas. | — |
| CA-12 | Sí. Las pruebas de la spec 002 no cambiaron y pasan: `test_hardware_service.py`, `test_ai_diagnoses.py`, `diagnosis_provider_test.dart` y `diagnosis_history_screen_test.dart`. Además, `el detalle muestra el estado según sensores y no el del diagnóstico IA`. | Las de la spec 002 sí. La nueva comprueba poco (obs. 4). | `DiagnosisModel.healthLabel` y `parse_health_status` no se tocaron. |
| CA-13 | Manual (T8). | — | No se pudo comprobar aquí. |

## Comprobaciones adicionales

- **Una sola regla.** Se buscaron `health`, `healthy`, `needs_water`, `needs_light`, `stressed`,
  `critical`, `unknown`, `score`, `isHealthy` y `needsLight` en `backend/app/` y `frontend/lib/`.
  - Backend: solo queda `health_service.py`. Los demás resultados son del diagnóstico IA
    (`HealthStatus`, `parse_health_status`) o el `/health` de `main.py`.
  - App: no queda ningún umbral por puntaje (60/30/70/40). `AnimatedPlantWidget` y `needsWater` solo
    miran el estado.
  - `controls.py` no tiene nada de salud. Inicio no usa ni la salud ni `healthScore`.
  - No queda ningún uso de `healthScore` que no admita nulos. Inicio usa `?.toStringAsFixed(...) ??`
    y el detalle `?.round() ?? 0`, así que no hay `!` ni `toStringAsFixed` sobre un nulo.
- **Contrato.**
  - `health_status` y `health_score` en `snake_case`. Coinciden el schema, el diccionario de
    `clima-actual` y `fromJson`, y el provider lee las mismas claves.
  - Los enums viajan en español tal cual. No hay rutas nuevas, así que `api_constants.dart` no
    necesitaba cambios.
- **Spec 003.** La condición de la rama en vivo, `_livePumpPlantId`/`_livePumpOn` y el contador de
  petición no cambiaron. `plant_provider_health_test.dart` comprueba `livePumpOn(7) == true` con
  `led_encendido`. Las pruebas de detener riego pasan sin cambios.
- **Reglas del repositorio.**
  - La lógica está en `services/` y es una función pura.
  - Comentarios en español y colores desde `SolarColors`.
  - Las constantes de luz, voltaje y batería del provider y `demo()` se dejaron para la spec 005,
    como dice el plan.
- **Tareas.** T1-T6 marcadas `[x]`. Sus pruebas existen y pasan.

## Observaciones

| # | Gravedad | Observación | Decisión del equipo | Motivo |
|---|---|---|---|---|
| 1 | media | Ninguna prueba ejercita el **tope de 30 de la temperatura** (`backend/app/services/health_service.py:51`). El mutante `min(3 × exceso, 300)` pasa las 122 pruebas de `test_health_service.py`, `test_salud_sensores.py` y `test_seguridad_hardware.py`. Todas las filas tienen un exceso de 10 °C o menos (30 justo, en 0/45 y 15/45). Sin el tope, una lectura de 50 °C con suelo correcto daría `Critica` (55) en lugar de `Exceso de calor` (70), y con más calor el puntaje bajaría de 0. Falta un caso del estilo «suelo 50, 50 °C → `Exceso de calor`, 70.0». La regla está bien implementada; lo que falta es la prueba. | | |
| 2 | media | La prueba de ancho de CA-9 (`frontend/test/plant_detail_health_test.dart:256-330`) **no detecta que la etiqueta se corte**. Mide `tester.getRect` del `Text`. Un `RenderParagraph` sin salto de línea se ajusta al ancho que le dejan y recorta el texto, así que el rectángulo nunca supera la pantalla. Con `softWrap: false` y `fontSize: 30` (o `maxLines: 1`) en la etiqueta (`plant_detail_screen.dart:292-300`) pasan las 52 pruebas. Hoy el código no tiene `maxLines` y hace salto de línea, así que el comportamiento es correcto. Pero la prueba no protege la parte «cabe sin desbordarse» de CA-9. Debería comprobar, por ejemplo, que el texto no excede sus líneas (`didExceedMaxLines` del `TextPainter`) o que se ve completo. | | |
| 3 | baja | En el detalle, la tarjeta de humedad muestra **«0 %» cuando `soilHumidity` es nulo** (`frontend/lib/screens/plant/plant_detail_screen.dart:414`, `?.round() ?? 0`). A la vez, la etiqueta dice «sin lecturas». Esto ya pasaba con `latest` sin suelo. Con D6 también puede pasar en vivo si `clima-actual` no trae `humedad_suelo`. En la práctica no ocurre, porque `LATEST_DATA` siempre lo trae (`hardware_helper.py:21`). Un «0 %» se lee como tierra seca: es un valor de relleno presentado como lectura, y le toca a la spec 005. Se anota para que no se pierda. | | |
| 4 | baja | La prueba de CA-12 en el detalle (`plant_detail_health_test.dart:468-483`) comprueba que no aparece `find.text('Buena')`, pero el detalle nunca carga diagnósticos, así que esa parte no puede fallar. CA-12 queda cubierto de verdad por la etiqueta (que sí puede fallar) y por las pruebas de la spec 002, que no cambiaron. | | |
| 5 | baja | `obtener_clima` consulta la planta del ESP8266 dos veces: `get_device_plant` en `backend/app/routers/hardware.py:32` y `get_device_plant_for_user` en la línea 35, que vuelve a llamar a `get_device_plant`. El resultado es correcto y cumple D4. Es solo una consulta de más cada 3 s por cliente. | | |
| 6 | baja (aviso de commit) | `frontend/lib/config/api_constants.dart` está modificado en el árbol de trabajo (`baseUrl` = `http://10.97.203.53:8000`). Es ajeno a la spec, y `frontend/CLAUDE.md` prohíbe cambiar `baseUrl`. **No debe entrar en ningún commit**: se agregan los archivos uno por uno, como dice `tasks.md`. El revisor no lo revirtió. Además, «Diferencias con lo planeado» dice que ese archivo no se modificó. Es cierto para el código de la spec, pero no para el árbol de trabajo. | | |

No hay observaciones de gravedad alta.

## Lo que esta revisión no pudo comprobar

- **CA-13 con la placa real** (T8): el ESP8266 por USB, el sensor al aire, desconectar el cable y
  ver que el estado se mantiene con la lectura guardada.
- **El aspecto visual real** de la etiqueta «Según sensores: …» (tamaño 16, peso 700, sin cortes)
  y de la cara en Chrome y en el emulador Android. Solo se midió en pruebas de widget, y la de ancho
  tiene la limitación de la obs. 2.
- **PostgreSQL**: las pruebas usan SQLite en memoria. No se comprobó una planta con `min_humidity`
  o `max_temperature` en `NULL` en la base real, aunque el servicio lo admite.
- **La convivencia con un backend o una app de versión vieja** en un despliegue real. Las pruebas
  cubren que los valores en inglés se leen como `Sin datos`.
- **La webcam y Gemini**: no se usan en esta spec. Para CA-12 se confió en las pruebas de la spec
  002, que no cambiaron y pasan.
