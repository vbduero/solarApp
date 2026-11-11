# Revisión · Spec 001

- **Revisado por:** agente `revisor` (segunda revisión, tras la vuelta 1 de corrección)
- **Commit revisado:** ninguno. La rama `feat/001-estadisticas-reales` sigue sin commits propios; se
  revisó el árbol de trabajo sobre `439f216` (`main`) con `git status --short`, `git diff main` y
  los archivos sin seguimiento. Revisión del 2026-11-11.
- **Veredicto:** **APROBADA CON OBSERVACIONES** (ninguna observación alta abierta; las
  verificaciones pasan).

## Verificación ejecutada

| Comprobación | Resultado |
|---|---|
| `python -m pytest -q --cov --cov-config=.coveragerc` | **108 passed**, 9 warnings (deprecaciones previas de Pydantic/SQLAlchemy), 4.89 s. Cobertura total **63.32 %** (umbral 60 %: «Required test coverage of 60.0% reached»). `app/services/sensor_service.py` al 100 % (entre los «22 files skipped due to complete coverage»). Primera revisión: 106 passed, 63.35 %; las 2 nuevas son las de empates. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | Código de salida 0. **38 issues** (7 warnings, 31 infos), los mismos que en la primera revisión y que en `main`. Ninguno en `stats_screen.dart`, `sensor_reading_model.dart` ni en las pruebas nuevas; los 6 de `plant_provider.dart` (líneas 19 y 148–154) son previos (`_isDemoMode`, `??` muertos en `loadSensorData`). Sin avisos nuevos. |
| `flutter test` | **All tests passed! (43 pruebas)**. Primera revisión: 37. Las 6 nuevas: 2 en `sensor_history_provider_test.dart` (ahora 7) y 4 en `stats_screen_test.dart` (ahora 14). |
| Archivos cambiados dentro del alcance del plan | Sí. Los mismos de la primera revisión, todos en la tabla «Archivos que se tocan»: `backend/app/routers/sensors.py`, `backend/app/services/sensor_service.py`, `backend/tests/test_sensors_history.py`, `backend/tests/test_sensor_service.py`, `frontend/lib/models/sensor_reading_model.dart`, `frontend/lib/providers/plant_provider.dart`, `frontend/lib/screens/stats/stats_screen.dart`, `frontend/test/sensor_history_provider_test.dart`, `frontend/test/stats_screen_test.dart`, `specs/001-estadisticas-reales/`. No se tocó `.env`, `venv/`, `build/`, `static/`, `init.sql`, `seed_data.py`, `main.dart`, schemas ni firmware. **Advertencia de commit (sin cambios):** `frontend/lib/config/api_constants.dart` línea 8 sigue con `baseUrl = 'http://10.97.203.53:8000'`; no debe entrar en ningún commit. |

Comprobaciones adicionales del revisor (fuera del repositorio, en el scratchpad de la sesión; nada
se agregó al proyecto):

- **Mutante backend:** se cargó con `pytest -p` un plugin que reemplaza en memoria
  `sensor_service.get_history` por la versión sin `desc(SensorData.id)`. Resultado: **2 failed, 18
  passed**; fallan justo `test_historial_con_el_mismo_recorded_at_desempata_por_id_descendente` y
  `test_historial_con_empates_y_mas_lecturas_que_limit_no_repite_ni_pierde_extremos`. Las pruebas de
  empates sí prueban el desempate.
- **Widget tests temporales** (paquete aparte con dependencia `path` a `frontend/`) sobre
  `_scheduleFallbackReload`, con un `PlantProvider` falso que registra `planta/horas`:
  - planta mostrada (2) desaparece y luego hay dos `notifyListeners` más: llamadas `[2/24, 1/24]`,
    **una sola recarga, sin bucle**, sin excepción;
  - la planta desaparece y la pantalla se desmonta en el mismo frame: llamadas `[2/24]`, **nada
    tras `dispose`**, sin excepción (el callback comprueba `mounted` y `_fallbackScheduled` se
    pone en `false` antes de esa comprobación, así que no queda pegado);
  - desaparecen dos plantas seguidas: `[1/24, 2/24, 3/24]` (el flag se rearma bien);
  - la lista se vacía (se ve «Aún no tienes plantas registradas.») y vuelve otra: `[2/24, 5/24]`,
    se muestra la planta nueva;
  - `selectedPlant` cambia con la pantalla abierta: no recarga (correcto: manda la elección local).

## Criterios de aceptación

| Criterio | ¿Tiene prueba? | ¿La prueba puede fallar? | Observación |
|---|---|---|---|
| CA-1 | Sí: `con lecturas muestra las tres gráficas…` (widget) y `loadSensorHistory deja las lecturas en orden ascendente…` (provider) | Sí: sin el `..sort(...)` de `plant_provider.dart` la del provider da `[3,2,1]`. | Sin cambios. Correcto. |
| CA-2 | Sí: `no muestra Luz Solar ni Sistema Solar en ningún estado` + CA-7 | Sí. | Sin cambios. Correcto. |
| CA-3 | Sí: `abre en 24h y cada periodo pide…`, `mientras carga muestra el indicador…`, `envía GET a /api/sensors/history/7…` | Sí. | Sin cambios. Correcto. |
| CA-4 | Sí: `sin lecturas muestra el estado vacío…` | Sí. | Correcto. |
| CA-5 | Sí: dos de widget + `si el API falla devuelve false…` + **nueva** `tras un fallo historyError es exactamente el mensaje de CA-5` | Sí: ahora el provider real se compara con el texto exacto (500 y `ClientException`). | Corregida la obs. 5. |
| CA-6 | Sí: `usa la planta seleccionada…`, `al elegir otra planta…` + **nuevas** `CA-6 con selectedPlant que no está en la lista (2 plantas)…`, `(1 planta)…`, `si la planta mostrada desaparece…` | Sí: con el `_currentPlant` anterior la de 2 plantas da la aserción de `DropdownButton` y la de 1 planta pide la 99 y muestra «DeOtroUsuario»; sin `_scheduleFallbackReload` la de «desaparece» queda con `calls.last.plantId == 7`. | Corregida la obs. 1 (bloqueante) y la 2. |
| CA-7 | Sí: `sin plantas muestra el aviso…` + **nueva** `D12 con plantas vacías e isLoading…` | Sí. | Corregida la obs. 3. |
| CA-8 | Sí: `si una respuesta anterior llega tarde…`, `si las respuestas llegan en orden…` + **nueva** `…llega tarde y falla no pisa…` | Sí: sin `if (requestId != _historyRequestId) return false;` en la rama `catch` el error viejo vacía la lista y la prueba falla. | Corregida la obs. 6. El cambio de planta usa el mismo contador; no tiene prueba propia (aceptable). |
| CA-9 | Sí: `una lectura sin valor no se dibuja como cero…` | Sí. | Correcto. |
| CA-10 | Sí: 3 pruebas + **nueva** de empates (`…desempata_por_id_descendente`) | Sí (mutante comprobado). | Correcto. |
| CA-11 | Sí: `rechaza_hours…`, `rechaza_limit…`, `acepta_los_limites`, `sin_parametros_usa_24_horas_y_limite_100` | Sí. | Correcto. |
| CA-12 | Sí: `…cubre_todo_el_periodo`, 8 de `pick_evenly` + **nueva** `…con_empates_y_mas_lecturas_que_limit…` | Sí (mutante comprobado). | Correcto. |
| CA-13 | Sí: ajena 404, inexistente 404, sin token 401 | Sí. | Correcto. |

**Prueba más importante y qué romper para que falle:** `CA-6 con selectedPlant que no está en la
lista (2 plantas) usa la primera sin lanzar excepción`. Basta con volver a
`final chosen = _plantId ?? provider.selectedPlant?.id;` devolviendo `provider.selectedPlant` sin
buscarlo en `plants` (`stats_screen.dart` líneas 49–54) para que `DropdownButton.value` (línea 264)
reciba un id que no está en sus `items` y la prueba falle.

**Pruebas anteriores:** las 37 pruebas de frontend y las 106 de backend de la primera revisión
siguen presentes con los mismos nombres; la única aserción «débil» señalada
(`historyError isNotEmpty`) se conserva y se añadió otra prueba con el texto exacto. No hay `skip`,
`xfail` ni pruebas comentadas. No se debilitó ni borró ninguna prueba.

**Contrato backend ↔ frontend:** sin cambios respecto de la primera revisión:
`ApiConstants.sensorsHistory` (`/api/sensors/history`, línea 22) + `/$plantId` coincide con
`@router.get("/history/{plant_id}")` bajo `/api/sensors`; campos `snake_case` mapeados en
`SensorReadingModel.fromJson`. La pantalla no llama a `ApiService` ni a `http`.

**Seguridad:** `get_current_user` y filtro por dueño intactos antes de llamar al servicio; `hours`
1–720 y `limit` 1–500 declarativos (`sensors.py` líneas 120–121).

## Observaciones de esta segunda revisión

| # | Gravedad | Observación | Decisión del equipo | Motivo |
|---|---|---|---|---|
| 11 | baja | `frontend/lib/screens/stats/stats_screen.dart` líneas 90–96 (`_reload`): usa `_currentPlant` pero no actualiza `_plantId`. Si un toque (periodo o «Reintentar») llegara justo entre la notificación de una lista sin la planta mostrada y el siguiente `build`, `_reload` pediría `plants.first` y luego `_scheduleFallbackReload` pediría otra vez lo mismo: dos peticiones idénticas. Es inocuo (el contador de CA-8 deja la última, con los mismos datos) y en la práctica muy improbable; se anota solo para que, si se toca, `_reload` fije `_plantId = plant.id`. No se reprodujo. | | |
| 12 | baja | `specs/001-estadisticas-reales/plan.md`, tabla «Pruebas por criterio»: las 6 pruebas nuevas (y las 2 de empates del backend) solo aparecen descritas en «Diferencias con lo planeado», no en la tabla. Está explicado, pero conviene agregarlas a la tabla para que la trazabilidad CA → prueba quede en un solo sitio. | | |

## Historial · primera revisión (RECHAZADA)

Veredicto de la primera revisión (2026-11-11, mismo árbol de trabajo antes de la vuelta 1):
**RECHAZADA** por la observación 1 (alta). Verificación de entonces: 106 passed / 63.35 %,
`flutter analyze` 38 issues sin nuevos, `flutter test` 37 pruebas. Estado actual de cada hallazgo:

| # | Gravedad | Hallazgo (resumen) | Estado en la segunda revisión |
|---|---|---|---|
| 1 | alta | `stats_screen.dart` `_currentPlant` y `DropdownButton.value` usaban `selectedPlant` sin comprobar que estuviera en `plants`: aserción del `DropdownButton` con 2+ plantas y planta ajena visible con 1 (incumplía CA-6). | **Corregido.** `_currentPlant` (líneas 45–56) solo acepta un id que esté en `plants`; si no, `plants.first`. `DropdownButton.value` (línea 264) recibe siempre el id de una planta de la lista. Dos pruebas nuevas (1 y 2 plantas) que fallarían con el código anterior. |
| 2 | baja | Si la planta elegida desaparecía con la pantalla abierta, cambiaba el nombre pero no se recargaba el historial. | **Corregido.** `_scheduleFallbackReload` (líneas 60–73) recarga `plants.first` con el periodo actual tras el frame. Comprobado: sin bucle, sin doble petición, el flag no queda pegado y no actúa tras `dispose` (ver «Comprobaciones adicionales»). Prueba nueva `si la planta mostrada desaparece…`. Queda la nota menor n.º 11. |
| 3 | media | D12 sin prueba (lista que llega tarde; lista vacía + `isLoading`). | **Corregido.** `FakePlantProvider` sobreescribe `isLoading` y la prueba `D12 con plantas vacías e isLoading…` cubre los dos casos. |
| 4 | baja | `sensor_service.py` ordenaba solo por `recorded_at`: orden no determinista en empates. | **Corregido.** Líneas 42 y 52 ordenan por `desc(recorded_at), desc(id)`. Dos pruebas de empates; el mutante sin desempate las hace fallar. |
| 5 | baja | La prueba del provider solo exigía `historyError` no vacío. | **Corregido.** Prueba nueva con el texto exacto «No se pudieron cargar las estadísticas.» para 500 y error de red. |
| 6 | baja | Rama «respuesta tardía que falla» de CA-8 sin prueba. | **Corregido.** Prueba nueva `si una respuesta anterior llega tarde y falla no pisa…`. |
| 7 | baja | Imports `datetime`, `timedelta`, `timezone` sin usar en `sensors.py`. | **Corregido.** Quitados (visible en `git diff main`). |
| 8 | baja | `isCurved: true` sin `preventCurveOverShooting`; tramo continuo entre lecturas lejanas. | **Corregido a medias.** `preventCurveOverShooting: true` en la línea 449. Entre dos lecturas lejanas se sigue dibujando un tramo continuo (no un hueco como sugiere D10); es aspecto visual, a revisar en T8. |
| 9 | baja | `sensor_reading_model.dart` línea 31: `DateTime.parse` toma como hora local una fecha sin zona (solo SQLite). | **Pendiente, por decisión anotada** en «Diferencias con lo planeado» (a decisión de la responsable). No afecta a PostgreSQL. |
| 10 | baja (advertencia) | `api_constants.dart` línea 8: `baseUrl` con IP local. | **Sigue igual** (no se revierte por indicación). No incluirlo en ningún commit: `git add` por archivo. |

Las columnas «Decisión del equipo» y «Motivo» de la primera revisión quedaron vacías; si el equipo
quiere dejar constancia, puede usar la tabla de abajo.

| # (1.ª revisión) | Decisión del equipo | Motivo |
|---|---|---|
| 1–8 | | |
| 9 | | |
| 10 | | |

## Tareas

T1–T6 marcadas `[x]` están hechas y sus pruebas pasan. T7 (esta revisión) y T8 (comprobación
manual de la responsable) siguen sin marcar, como corresponde. «Diferencias con lo planeado»
describe la vuelta 1 y coincide con lo que hay en el código (D1 precisada, desempate de D6,
`preventCurveOverShooting`, pruebas agregadas, obs. 9 pendiente).

## Lo que esta revisión no pudo comprobar

- **PostgreSQL real:** todas las pruebas usan SQLite. No se comprobó `recorded_at >= since` ni el
  formato de `recorded_at` en el JSON con la base real.
- **ESP8266, webcam y Gemini:** no intervienen en esta spec; no hubo lecturas reales de la placa.
- **Aspecto visual:** colores, curva con `preventCurveOverShooting`, tramos entre lecturas lejanas,
  tooltip, horas bajo cada gráfica y el selector de planta en pantallas angostas. Queda para T8 en
  Chrome o emulador.
- **Modo release:** la ausencia de la aserción del `DropdownButton` se comprobó en debug (pruebas);
  no se compiló en release.
- **Que las pruebas nuevas fallaran antes de la corrección:** sin commits intermedios no se puede
  ver; se razonó contra el código descrito en la primera revisión y, en backend, se comprobó con un
  mutante en memoria. En frontend no se ejecutó un mutante (no se puede editar el código).
