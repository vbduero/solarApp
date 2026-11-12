# Revisión · Spec 002

- **Revisado por:** agente `revisor` (segunda revisión, después de la vuelta 1 de corrección)
- **Commit revisado:** ninguno propio de la rama. Se revisó el árbol de trabajo de
  `feat/002-historial-diagnosticos` sobre `aad1703` (`main`), con `git status --short`, `git diff main`
  y los archivos sin seguimiento, porque la rama sigue sin commits.
- **Veredicto:** **APROBADA CON OBSERVACIONES**. No hay observaciones altas: los nueve hallazgos de la
  primera revisión están corregidos o anotados en el plan. Quedan observaciones bajas, nuevas y
  antiguas.

## Verificación ejecutada

| Comprobación | Resultado |
|---|---|
| `python -m pytest -q --cov --cov-config=.coveragerc` | **134 passed**, 9 warnings (deprecaciones de Pydantic que ya existían). Cobertura total **69.16 %** (umbral 60 %: se cumple). `routers/ai.py` 71 %; `routers/hardware.py` 88 % (sin cubrir: 60-64, 93-94, 206-208). En la primera revisión eran 131: las 3 nuevas son las de regresión de `test_diagnostico_ia.py`. |
| `flutter analyze --no-fatal-infos --no-fatal-warnings` | Código de salida 0. **38 issues**, los mismos que en la primera revisión: 1 warning `unused_import` en `plant_detail_screen.dart:17` y el resto infos. Ninguno está en archivos nuevos ni en líneas agregadas por la spec. |
| `flutter test` | **81 pruebas, «All tests passed!»**. En la primera revisión eran 69: las 12 nuevas son 3 de `diagnosis_route_test.dart`, 3 de `diagnosis_provider_dispose_test.dart`, 4 de `diagnosis_history_review_test.dart` y 2 de `plant_detail_overflow_test.dart`. |
| `backend/static/` después de las pruebas | Sin imágenes nuevas. Antes y después de pytest el listado es igual: `avatars/`, `images/` y `ultimo_diagnostico.jpg`, este con fecha del 27 de mayo. No existe `static/diagnosticos/` y `git status --short backend/static` sale vacío. |
| Alcance | Los archivos de código son los de la tabla «Archivos que se tocan». Las 4 pruebas nuevas de frontend y las 3 de backend no están en esa tabla, pero sí en «Diferencias con lo planeado → Vuelta 1». No se tocó ninguno de estos: `.env`, `venv/`, `build/`, `database/init.sql`, `seed_data.py`, `SECRET_KEY`, archivos generados, schemas. **Advertencia de commit (no es un hallazgo):** `frontend/lib/config/api_constants.dart` sigue con `baseUrl = 'http://10.97.203.53:8000'`, la IP local de la responsable. No debe entrar en ningún commit: hay que agregar los archivos uno por uno. |
| Pruebas de la primera vuelta | No se borró ni se debilitó ninguna. Los conteos solo suben (backend 131 → 134, frontend 69 → 81). `test_ai_diagnoses.py`, `test_hardware_service.py`, `diagnosis_provider_test.dart`, `diagnosis_history_screen_test.dart` y `plant_detail_diagnoses_button_test.dart` tienen fecha de modificación anterior al primer informe (11-nov 16:59-17:01; el informe es de las 17:14). De `test_diagnostico_ia.py`, el único que se modificó, siguen las 6 pruebas originales, con las mismas aserciones que pide el plan, y se le agregaron 3. |

### Mutantes (copias en el scratchpad, fuera del repo)

- **Frontend: 13 mutantes; 11 hacen fallar alguna prueba.**
  - **F1** (fallan 2). Ruta con `arguments as PlantModel`.
  - **F2** (fallan 1). Ruta con `plantId: 0`.
  - **F3** (fallan las 2 de dispose). Quitar `if (_disposed) return;`.
  - **F4** (fallan 2). `imageUrlFor` sin `isEmpty`.
  - **F5**. «Regular» en `error`.
  - **F6**. Estado desconocido en `success`.
  - **F7**. `Text` en lugar de `SelectableText`.
  - **F8**. Miniatura de 72.
  - **F9** (fallan las 2 de desborde). Quitar el `Flexible` del botón.
  - **F11**. `case 'Critica'` sin tilde en el color.
  - **F12**. Otro texto en lugar de «Planta no encontrada».
- **Frontend: sobreviven 2.**
  - **F10**. Quitar el `FittedBox` de la etiqueta (obs. 10).
  - **F13**. Un `DiagnosisProvider` compartido a nivel de módulo con `.value` en vez del
    `create:` local (obs. 11).
- **Backend: 3 mutantes; los 3 hacen fallar alguna prueba.**
  - **B1.** Orden ascendente por fecha. Lo detecta solo la prueba nueva
    `test_el_diagnostico_nuevo_sale_primero_aunque_ya_haya_uno_anterior`; la de CA-6 original pasa,
    como ya decía el hallazgo 7.
  - **B2.** `get_device_plant_for_user` sin mirar `user_id`.
  - **B3.** El router vuelve a `get_device_plant`.
  - B2 y B3 los detecta la prueba nueva sin `ESP8266_PLANT_ID` y con la planta más antigua ajena.

### Desbordes del detalle de la planta (comprobado aparte, en el scratchpad)

Se montó `PlantDetailScreen` a 320, 360 y 412 px, con escala de texto 1.0, 1.3 y 2.0, y se anotó de
dónde viene cada error «overflowed»:

- Todos vienen de las filas `plant_detail_screen.dart:155`, `:292`, `:342` y `:393`. Ninguno de la
  fila de botones (`:430`).
- Esas cuatro filas no cambian respecto de `main` (el diff solo toca la línea 40, que es un espacio
  en blanco, y de la 446 en adelante). Por eso se confirma que el desborde ya existía y es ajeno a la
  spec, como dice el plan.

## Criterios de aceptación

| Criterio | ¿Tiene prueba? | ¿La prueba puede fallar? | Observación |
|---|---|---|---|
| CA-1 | Sí, 4 en `test_ai_diagnoses.py` | Sí | Sin cambios desde la primera revisión. |
| CA-2 | Sí, parametrizada con los 5 estados | Sí | D3 no hizo falta. |
| CA-3 | Sí | Sí | — |
| CA-4 | Sí: planta ajena, inexistente y sin token | Sí | — |
| CA-5 | Sí | Sí | — |
| CA-6 | Sí, 2: la original y la nueva con un diagnóstico anterior | Sí, la nueva (mutante B1) | Hallazgo 7 corregido. |
| CA-7 | Sí, 4 | Sí | — |
| CA-8 | Sí: 3 de endpoint (2 nuevas) y 3 de servicio | Sí (B2, B3) | Hallazgo 8 corregido. |
| CA-9 | Sí: botón y ruta real `/plant-diagnoses` montando `SolarGrowApp` | Sí (F1, F2, F12) | Hallazgo 3 corregido. |
| CA-10 | Sí: pantalla, modelo, provider y colores | Sí | La hora local sigue sin prueba en UTC (obs. 6, anotada en el plan). |
| CA-11 | Sí, ahora con `SelectableText` | Sí (F7) | — |
| CA-12 | Sí, ahora también con la cadena vacía (provider y pantalla) | Sí (F4) | Hallazgo 5 corregido. |
| CA-13 | Sí | Sí | — |
| CA-14 | Sí | Sí | — |
| CA-15 | Sí, ahora también con la pantalla cerrada mientras carga | Sí (F3) | Hallazgo 2 corregido. Que el provider se destruya al cerrar no se prueba (obs. 11). |

**La prueba más importante de esta vuelta** es `diagnosis_route_test.dart`. Falla si se rompe
`main.dart:86` (`if (args is! PlantModel)`) o se vuelve al cast directo: lo detecta el mutante F1.

## Observaciones

### Segunda revisión: hallazgos nuevos

No hay hallazgos nuevos bloqueantes.

| # | Gravedad | Observación | Decisión del equipo | Motivo |
|---|---|---|---|---|
| 10 | baja | `frontend/lib/screens/plant/plant_detail_screen.dart:509-518`. El `FittedBox(fit: BoxFit.scaleDown)` reduce la etiqueta hasta que cabe. **(a) Tamaño.** Con la fuente de pruebas, «Diagnósticos» se dibuja al 51 % a 320 px (unos 7,6 px de letra), al 58 % a 360 px y al 68 % a 412 px; «Info» y «Regar» no se reducen a escala 1.0. Con la fuente real la palabra es más estrecha, así que probablemente se vea a más del 90 %, pero no se pudo comprobar. **(b) Accesibilidad.** El `FittedBox` anula el texto grande: con escala 2.0 las tres etiquetas vuelven a dibujarse más o menos al tamaño normal. **(c) Prueba.** `plant_detail_overflow_test.dart` no detecta una etiqueta cortada: si se quita el `FittedBox`, el `Text` con `maxLines: 1` se recorta sin error de desborde y la prueba sigue pasando (mutante F10). Revisar a mano en T8, a 320-360 px y con texto ampliado. | | |
| 11 | baja | `frontend/test/diagnosis_route_test.dart:113-120`. La prueba de D6 solo comprueba que el `DiagnosisProvider` está debajo de la pantalla y no en el `MultiProvider` global. No comprueba que se destruya al cerrar la ruta ni que una segunda apertura cree uno nuevo. Un provider compartido a nivel de módulo con `ChangeNotifierProvider.value` pasa la prueba (mutante F13). Hoy el código está bien (`create:` local en `main.dart:93-94`). | | |
| 12 | baja | `frontend/lib/providers/diagnosis_provider.dart:21-33`. Sobrescribir `notifyListeners()` con `if (_disposed) return;` resuelve el hallazgo 2 y no deja estado inconsistente visible: después de `dispose` nadie escucha, y `loadDiagnoses` solo actualiza campos privados del objeto ya destruido. Tiene dos costes menores. Uno: silencia cualquier uso futuro después de `dispose`, no solo esta carrera (`addListener` sí sigue fallando, porque no está sobrescrito). Otro: una carga lanzada sobre un provider destruido sigue haciendo la petición HTTP. Es aceptable; es informativo. | | |

### Primera revisión (historial)

Veredicto de la primera revisión: **RECHAZADA** (observación 1, alta). Resultados de entonces:

- backend: 131 passed, 69.16 %;
- `flutter analyze`: 38 issues;
- `flutter test`: 69 pruebas.

| # | Gravedad | Observación original (resumen) | Estado en la segunda revisión | Decisión del equipo | Motivo |
|---|---|---|---|---|---|
| 1 | **alta** | `main.dart:85-86`: `arguments as PlantModel` lanzaba `_TypeError` sin argumentos o con otro tipo; D7 y D10 pedían «Planta no encontrada». | **Corregido.** `main.dart:85-91`: `args is! PlantModel` muestra un `Scaffold` con `AppBar` «Diagnósticos» y «Planta no encontrada», sin crear el provider. `diagnosis_route_test.dart` monta la `SolarGrowApp` real y empuja la ruta sin argumentos y con un `String`: comprueba que no hay excepción, que aparece el texto y que no se piden diagnósticos (F1 y F12 mueren). Está anotado en «Diferencias con lo planeado». | | |
| 2 | media | `notifyListeners()` sobre un provider destruido si se cerraba la pantalla mientras cargaba. | **Corregido.** `_disposed` y `notifyListeners()` sobrescrito (`diagnosis_provider.dart:21-33`). Las dos pruebas de `diagnosis_provider_dispose_test.dart` (respuesta buena y con error) fallan sin la guarda (F3). Ver la obs. 12 sobre el patrón. | | |
| 3 | media | Ninguna prueba montaba la ruta real `/plant-diagnoses`. | **Corregido.** `diagnosis_route_test.dart` usa la ruta real de `main.dart`: sin argumentos, con otro tipo y con un `PlantModel`. En este último caso comprueba que pide `/api/ai/diagnosis/7` una sola vez y que el provider no es global. Queda sin probar la destrucción del provider (obs. 11). | | |
| 4 | baja | Colores por estado, `SelectableText` y miniatura de 64 no seguían D8 y D9. | **Corregido.** `_statusColor` (`diagnosis_history_screen.dart:39-52`) con `success`, `warning`, `error` y `textSecondary`; `SelectableText` (`:252`); miniatura de 64 (`:178`). `diagnosis_history_review_test.dart` lo fija (F5, F6, F7, F8 y F11 mueren). | | |
| 5 | baja | Ninguna prueba cubría la `image_url` vacía. | **Corregido.** Hay pruebas en el provider y en la pantalla (con `imageUrlFor` real); F4 muere. | | |
| 6 | baja | La hora local solo se comprobaba en máquinas fuera de UTC. | **Pendiente, anotado.** El plan lo deja como comprobación manual en T8 («Sin prueba, por no haber forma fiable»). | | |
| 7 | baja | CA-6 «sale primero» con un único diagnóstico. | **Corregido.** `test_el_diagnostico_nuevo_sale_primero_aunque_ya_haya_uno_anterior` siembra uno del día anterior y exige `[nuevo, anterior]`. B1 solo lo detecta esta prueba. | | |
| 8 | baja | Log engañoso en `hardware.py:205` y CA-8 sin probar en el endpoint sin `ESP8266_PLANT_ID`. | **Corregido.** El mensaje dice ahora «no hay planta del ESP8266 que pertenezca al usuario» (`hardware.py:205`), cierto en los dos casos. Hay dos pruebas nuevas de endpoint: sin id configurado con la planta más antigua ajena (mata B2 y B3) y sin ninguna planta. | | |
| 9 | baja | La fila de tres botones se desbordaba 14 px a 360 y 54 px a 320 en `flutter_test`. | **Corregido, con un resto en la obs. 10.** `Flexible` + `FittedBox` en `_buildCircleButton` (`plant_detail_screen.dart:484-523`). Comprobé que la fila `:430` ya no produce ningún error de desborde a 320, 360 y 412 px, ni con escala 1.3 o 2.0. **Sobre la prueba acotada:** puede fallar, porque F9 (sin `Flexible`) hace fallar las dos. Tolerar los «overflowed» ajenos es aceptable: comprobé que vienen de cuatro filas que no cambian respecto de `main`, y cualquier otro tipo de error sigue fallando. La tolerancia también aceptaría un desborde de la propia fila, pero las aserciones de geometría (botones dentro de la fila y de la pantalla, sin solaparse) lo detectan. Lo que no detecta es una etiqueta recortada (F10, obs. 10). | | |

## Lo que esta revisión no pudo comprobar

- Webcam, Gemini y ESP8266 reales: pedir un diagnóstico real y verlo primero en el historial (T8).
- PostgreSQL: el orden por `created_at` con zona y el formato real de la fecha (las pruebas usan
  SQLite).
- La hora local (obs. 6): esta máquina está en UTC-5, pero en una CI en UTC nada lo comprueba.
- El aspecto visual en Chrome y en el emulador:
  - la carga de fotos de `/static` (CORS en web);
  - el tamaño real de la etiqueta «Diagnósticos» con la fuente de verdad, a 320-360 px y con texto
    ampliado (obs. 10).
  - las otras cuatro filas del detalle que ya se desbordaban en `main`: es ajeno a esta spec, pero
    conviene abrir un aviso aparte.
- La recarga en web sobre `/#/plant-diagnoses`: lo deduje del código y lo cubre la prueba de la ruta,
  pero no lo abrí en un navegador.
- Que `api_constants.dart` quede fuera de los commits: la rama todavía no tiene commits.
