# Spec 001 · Estadísticas con datos reales

- **Estado:** aprobada
- **Rama:** `feat/001-estadisticas-reales`
- **Responsable:** Valentina Bermeo

## Qué se construye

Quien abre «Estadísticas» ve el historial real de temperatura, humedad del suelo y humedad del aire
de una de sus plantas, y puede cambiar el periodo (6h, 24h, 7d, 30d) y la planta. Si no hay lecturas
o el servidor falla, la pantalla lo dice en español en vez de dibujar datos inventados.

## Por qué

- `frontend/lib/screens/stats/stats_screen.dart` dibuja las tres gráficas con puntos generados por
  una fórmula (`_generateDemoSpots`): no son lecturas de ninguna planta y son iguales para todos los
  usuarios.
- En la misma pantalla, la gráfica «Luz Solar» y el bloque «Sistema Solar» (15.2V, 85%, 12.8W,
  Tracker «Activo») muestran valores fijos. El proyecto no tiene sensor de luz, panel solar ni
  batería (`CLAUDE.md`); el propio backend guarda esas columnas como constantes
  (`backend/app/utils/hardware_helper.py`, `_guardar_datos_en_db`: `light_level=85.0`,
  `solar_voltage=12.4`…). Mostrarlos como mediciones incumple `.claude/rules/frontend-pantallas.md`.
- El selector de periodo solo cambia el botón resaltado: no vuelve a pedir datos.
- La pantalla no sabe de qué planta mostrar datos: la ruta `/stats` de `frontend/lib/main.dart` se
  abre desde la barra inferior y desde el menú lateral de `frontend/lib/screens/home/home_screen.dart`
  sin indicar ninguna planta.
- El historial real ya existe en `GET /api/sensors/history/{plant_id}`
  (`backend/app/routers/sensors.py`), con sesión y filtro por dueño, pero nadie lo usa en la app.
  Además acepta cualquier valor de `hours` y `limit` (negativos o enormes) y, cuando hay más lecturas
  que `limit`, devuelve solo las más recientes: con una lectura por minuto, pedir 30 días devolvería
  apenas los últimos minutos.

## Fuera de alcance

- Sensor de luz, panel solar, batería y tracker: no se grafican ni se muestran en esta pantalla. No
  se borran las columnas de la base de datos ni se cambia lo que guarda el backend.
- Los valores de luz, voltaje y batería que aparecen en otras pantallas (inicio, detalle de planta)
  y los datos demo de `PlantProvider` cuando el API no responde al listar plantas.
- Las lecturas aleatorias que inserta `backend/seed_data.py` en una base de desarrollo: el API no las
  distingue de las del ESP8266 y esta spec no las filtra ni cambia ese script.
- El firmware (`esp8266_maceta_inteligente/`) y la frecuencia con que se guardan lecturas.
- Promedios, mínimos/máximos, exportar datos o comparar plantas.
- Actualización automática mientras la pantalla está abierta: los datos se cargan al entrar, al
  cambiar de periodo o de planta y al reintentar.
- El elemento «Panel Solar» del menú lateral (hoy no hace nada) y el resaltado de la barra inferior
  al volver de Estadísticas.

## Criterios de aceptación

Pantalla (app):

- **CA-1. Caso normal.** Dado un usuario con sesión y una planta con lecturas en las últimas 24
  horas, cuando abre Estadísticas, entonces ve tres gráficas —«Temperatura» (°C), «Humedad del Suelo»
  (%) y «Humedad del Aire» (%)— dibujadas con esas lecturas en orden cronológico (la más antigua a la
  izquierda), y cada gráfica muestra como valor destacado el de la lectura más reciente.
- **CA-2. Sin valores de relleno.** Dado cualquier estado de la pantalla (con datos, vacía, con error
  o cargando), cuando se muestra, entonces no aparecen la gráfica «Luz Solar» ni el bloque «Sistema
  Solar» (Panel Solar, Batería, Potencia, Tracker).
- **CA-3. Selector de periodo.** Dado que la pantalla abre con «24h» seleccionado, cuando el usuario
  toca «6h», «7d» o «30d», entonces se vuelve a pedir el historial de la misma planta para 6, 168 o
  720 horas respectivamente («24h» pide 24), se ve un indicador de carga mientras llega la respuesta
  y las gráficas pasan a mostrar las lecturas de ese periodo.
- **CA-4. Sin lecturas.** Dada una planta sin lecturas en el periodo seleccionado, cuando termina la
  carga, entonces se muestra el texto «Esta planta no tiene lecturas en este periodo.» y ninguna
  gráfica; el selector de periodo sigue disponible.
- **CA-5. Error del API.** Dado que el servidor no responde o responde con error, cuando termina la
  carga, entonces se muestra el mensaje «No se pudieron cargar las estadísticas.» con un botón
  «Reintentar», y no se dibuja ninguna gráfica ni quedan a la vista las lecturas del periodo o la
  planta anteriores. Cuando el usuario toca «Reintentar», se vuelve a pedir el historial de la misma
  planta y periodo; si esta vez responde bien, se ven las gráficas.
- **CA-6. Qué planta se muestra.** Dado un usuario con plantas, cuando abre Estadísticas, entonces se
  muestran los datos de la última planta cuyo detalle abrió en esta sesión o, si no abrió ninguna, de
  la primera de su lista; el nombre de esa planta está visible en la pantalla. Cuando tiene más de
  una planta y elige otra en la pantalla, se cargan las lecturas de la planta elegida conservando el
  periodo seleccionado.
- **CA-7. Usuario sin plantas.** Dado un usuario sin plantas, cuando abre Estadísticas, entonces ve
  el texto «Aún no tienes plantas registradas.» y no se pide ningún historial.
- **CA-8. Cambios rápidos.** Dado que el usuario cambia de periodo (o de planta) antes de que llegue
  la respuesta anterior, cuando llegan las respuestas en cualquier orden, entonces la pantalla
  muestra los datos de la última selección, no los de una anterior.
- **CA-9. Lecturas incompletas.** Dado que algunas lecturas no traen valor para una de las tres
  variables, cuando se dibujan las gráficas, entonces esas lecturas no aparecen como cero en la
  gráfica de esa variable; y si ninguna lectura del periodo trae esa variable, su tarjeta muestra
  «Sin datos» en vez de una línea.

API (`GET /api/sensors/history/{plant_id}`):

- **CA-10. Historial del periodo.** Dado un usuario con sesión y una planta suya con lecturas, cuando
  pide el historial con `hours=N`, entonces recibe solo las lecturas de esa planta registradas en las
  últimas N horas, ordenadas de la más reciente a la más antigua; si no hay ninguna, recibe una lista
  vacía con código 200.
- **CA-11. Límites de los parámetros.** Dado un usuario con sesión, cuando pide el historial con
  `hours` menor que 1 o mayor que 720, o con `limit` menor que 1 o mayor que 500, entonces recibe 422
  y ninguna lectura. Los valores 1 y 720 (`hours`) y 1 y 500 (`limit`) se aceptan. Sin parámetros
  siguen valiendo `hours=24` y `limit=100`.
- **CA-12. El periodo no se recorta.** Dada una planta con más lecturas en el periodo que `limit`,
  cuando se pide el historial, entonces se reciben exactamente `limit` lecturas repartidas de forma
  pareja por todo el periodo —incluyen la más reciente y la más antigua del periodo— y no solo las
  `limit` más recientes; el orden sigue siendo de la más reciente a la más antigua.
- **CA-13. Sesión y dueño.** Dado un usuario con sesión, cuando pide el historial de una planta de
  otro usuario o inexistente, entonces recibe 404 «Planta no encontrada»; y sin sesión recibe 401.
  (Comportamiento actual: se fija con pruebas para que no se pierda.)

## Preguntas abiertas

- Ninguna. Las decisiones de alcance (qué variables se grafican, quitar luz y «Sistema Solar»,
  equivalencia de periodos, estados vacío y de error, límites del endpoint) las tomó la responsable.
  La elección de planta de CA-6, los topes 720/500 de CA-11 y el muestreo parejo de CA-12 eran
  propuestas del plan (decisiones D1, D5 y D6); la responsable las aprobó el 2026-11-11, junto con
  dejar fuera de alcance las lecturas aleatorias de `seed_data.py`.
