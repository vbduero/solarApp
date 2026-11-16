# Solar-Grow

Maceta inteligente: un ESP8266 mide la humedad del suelo, la temperatura y la humedad del aire y
controla una bomba de riego; un backend FastAPI lee esos datos por USB serial y pide diagnósticos a
Google Gemini con una foto de la webcam; una app Flutter muestra plantas, lecturas, tareas, riego y
diagnósticos.

- **Equipo:** Valentina Bermeo, Sergio Narvaez y Juan Esteban Cuchimba.
- **Herramienta de IA:** Claude Code.
- **Repositorio:** monorepo (`backend/`, `frontend/`, `esp8266_maceta_inteligente/`, `database/`).

Para instalar y ejecutar cada parte, ver `backend/CLAUDE.md` y `frontend/CLAUDE.md`.

# El arnés del proyecto

El arnés es todo lo que rodea al modelo para que trabaje bien en este proyecto: lo que lee al
iniciar, lo que carga cuando lo necesita, los roles que ejecutan el trabajo, el flujo que siguen y
los controles que verifican lo que producen.

## 1. Piezas y dónde está cada una

| Pieza | Dónde | Para qué |
|---|---|---|
| Memoria | [`CLAUDE.md`](CLAUDE.md), [`backend/CLAUDE.md`](backend/CLAUDE.md), [`frontend/CLAUDE.md`](frontend/CLAUDE.md) | Lo que el agente lee al iniciar: qué es el proyecto, comandos, organización, convenciones y lo que no debe hacer. La de cada carpeta se carga solo al trabajar en ella. |
| Rules | [`.claude/rules/`](.claude/rules) | Normas que se cargan según el archivo que se toca (ver tabla abajo). |
| Skills | [`.claude/skills/`](.claude/skills) | Procedimientos que el agente carga cuando la tarea los necesita. |
| Agentes | [`.claude/agents/`](.claude/agents) | Cinco roles con herramientas y modelo propios. |
| Flujo SDD | [`specs/`](specs) | Una carpeta por spec: `spec.md`, `plan.md`, `tasks.md`, `revision.md`. |
| Calidad | [`.github/workflows/ci.yml`](.github/workflows/ci.yml), [`backend/.coveragerc`](backend/.coveragerc), `specs/*/revision.md` | CI con pruebas y umbral de cobertura; revisión por un agente distinto del que programó. |

No usamos Spec Kit, así que no hay `constitution.md`. Los principios no negociables están en la
sección «Lo que el agente NO debe hacer» de `CLAUDE.md`.

### Rules

| Archivo | Se aplica a | Qué norma |
|---|---|---|
| `pruebas.md` | `backend/tests/**`, `frontend/test/**` | Una prueba debe poder fallar; nada real (BD, hardware, HTTP); no debilitar pruebas. |
| `backend-routers.md` | `backend/app/routers/**` | Sesión obligatoria, filtro por dueño, validación en el schema, 503 real si el ESP8266 no recibió el comando. |
| `frontend-pantallas.md` | `frontend/lib/screens/**`, `frontend/lib/widgets/**` | Las pantallas usan providers; no mostrar datos inventados ni ocultar errores. |
| `specs.md` | `specs/**` | Estructura de una spec y cómo se escriben los criterios de aceptación. |

## 2. Para qué usamos cada skill

| Skill | Problema que resuelve en este proyecto | Cuándo se invoca |
|---|---|---|
| [`nueva-spec`](.claude/skills/nueva-spec/SKILL.md) | La IA empezaba a programar sin acordar qué se iba a construir. La skill obliga a leer el código real, escribir criterios verificables (caso normal, sin datos y de error) y detenerse si hay preguntas. | Al empezar una funcionalidad, antes de cualquier código. |
| [`fastapi-endpoint`](.claude/skills/fastapi-endpoint/SKILL.md) | Los endpoints quedaban sin filtro por usuario o sin prueba. La skill da la plantilla del endpoint, el schema y la prueba con SQLite en memoria. | Al agregar o cambiar una ruta `/api/...`. |
| [`flutter-feature`](.claude/skills/flutter-feature/SKILL.md) | Pantallas que llamaban al API directamente o inventaban campos del JSON. La skill fija el orden contrato → modelo → provider → pantalla → prueba. | Al tocar `frontend/lib/`. |
| [`revisar-cambios`](.claude/skills/revisar-cambios/SKILL.md) | Código que compila y pruebas que pasan sin probar nada. La skill es la lista de comprobación del revisor: alcance, criterios, pruebas vacías, cosas inventadas, contrato, seguridad y datos falsos. | Antes de abrir el pull request de una spec. |

Las cuatro son propias del proyecto; ninguna viene de terceros.

## 3. Sistema de agentes

Un solo sistema para todo el monorepo: una funcionalidad casi siempre cruza backend y frontend, así
que planear, probar y revisar se hace una vez; solo la implementación se separa por stack.

La **sesión principal de Claude Code** es el orquestador: invoca a cada agente, le pasa la ruta de
la spec y recibe su informe. Los agentes no se llaman entre sí.

| Agente | Rol | Carpetas | Herramientas | Modelo | Skill |
|---|---|---|---|---|---|
| [`planificador`](.claude/agents/planificador.md) | Escribe spec, plan y tareas. No programa. | `specs/**` | Read, Grep, Glob, Write, Edit (sin terminal) | opus: es trabajo de juicio | `nueva-spec` |
| [`pruebas`](.claude/agents/pruebas.md) | Escribe las pruebas desde los criterios de aceptación, antes del código. | `backend/tests/**`, `frontend/test/**` | Read, Grep, Glob, Write, Edit, Bash | sonnet | — |
| [`backend-dev`](.claude/agents/backend-dev.md) | Implementa el backend hasta que las pruebas pasen. | `backend/app/**` | Read, Grep, Glob, Write, Edit, Bash | sonnet: ejecución guiada por el plan | `fastapi-endpoint` |
| [`frontend-dev`](.claude/agents/frontend-dev.md) | Implementa la app Flutter hasta que las pruebas pasen. | `frontend/lib/**` | Read, Grep, Glob, Write, Edit, Bash | sonnet | `flutter-feature` |
| [`revisor`](.claude/agents/revisor.md) | Ejecuta las pruebas por su cuenta y escribe el informe. No corrige. | solo `specs/*/revision.md` | Read, Grep, Glob, Bash, Write (sin Edit) | opus: debe encontrar lo que el implementador no vio | `revisar-cambios` |

Límite conocido: en Claude Code la lista `tools` restringe **qué herramientas** tiene un agente,
no **en qué carpetas** las usa. Que `backend-dev` no toque `frontend/` es una instrucción, no un
permiso; lo que sí lo detecta es el revisor, que compara `git diff --name-only` con la tabla de
archivos del plan.

## 4. Cómo se usa

En Claude Code, cada paso se pide a la sesión principal nombrando al agente, por ejemplo:
«Usa el agente planificador para especificar el historial de diagnósticos».

```text
1. planificador           "Especifica <idea>"            → specs/NNN-nombre/spec.md
2. Una persona lee la spec, responde las preguntas y la aprueba.
3. planificador           "Plan y tareas de specs/NNN"   → plan.md, tasks.md
4. git checkout -b feat/NNN-nombre
5. pruebas                "Pruebas de specs/NNN"         → pruebas en rojo
6. backend-dev            "Tareas backend de specs/NNN"  → pytest en verde
7. frontend-dev           "Tareas frontend de specs/NNN" → flutter test en verde
8. revisor                "Revisa specs/NNN"             → revision.md
   Si rechaza: vuelve al paso 6 o 7. Máximo 2 vueltas; después decide una persona.
9. Una persona marca cada observación como aceptada o descartada, abre el pull request
   (plantilla en .github/) y lo fusiona cuando la CI está en verde.
```

Estructura de una spec (propia, sin Spec Kit; plantilla en [`specs/_plantilla/`](specs/_plantilla)):

| Archivo | Contenido |
|---|---|
| `spec.md` | Qué se construye y por qué; criterios de aceptación `CA-n`. |
| `plan.md` | Decisiones técnicas, archivos que se tocan, qué prueba cubre cada criterio y diferencias con lo planeado. |
| `tasks.md` | Pasos con su agente responsable, marcados al completarse. |
| `revision.md` | Informe del revisor y decisión del equipo sobre cada observación. |

## 5. Specs

| # | Spec | Pull request | Veredicto del revisor | Estado |
|---|---|---|---|---|
| 001 | [Estadísticas con datos reales](specs/001-estadisticas-reales) | [#7](https://github.com/vbduero/solarApp/pull/7) | Rechazada; aprobada con observaciones en la segunda vuelta | Fusionada |
| 002 | [Historial de diagnósticos de IA por planta](specs/002-historial-diagnosticos) | [#8](https://github.com/vbduero/solarApp/pull/8) | Rechazada; aprobada con observaciones en la segunda vuelta | Fusionada |
| 003 | [Detener el riego desde la app](specs/003-detener-riego) | [#9](https://github.com/vbduero/solarApp/pull/9) | Aprobada con observaciones | Fusionada |
| 004 | [Un solo cálculo de salud de la planta](specs/004-calculo-unico-salud) | [#10](https://github.com/vbduero/solarApp/pull/10) | Aprobada con observaciones | Fusionada |
| 005 | [Aviso de modo demo](specs/005-aviso-modo-demo) | [#11](https://github.com/vbduero/solarApp/pull/11) | Aprobada con observaciones | Fusionada |

En las cinco queda sin marcar la última tarea de `tasks.md`: la comprobación manual de una persona
(la de las specs 003 y 004 necesita la placa) y la respuesta del equipo a las observaciones de
`revision.md`.

## 6. Qué cambió del sistema de agentes respecto del taller

El diseño inicial está en [`docs/agentes-diseno-inicial.md`](docs/agentes-diseno-inicial.md).
Las definiciones de `.claude/agents/` no se modificaron después de escribirlo: los cinco agentes,
sus herramientas y sus modelos son los del diseño. Lo que cambió al ejecutar las cinco specs fue
**cómo se usaron**. Cada fila dice qué se hizo distinto y qué se observó.

### Cambios en el flujo

| Cambio respecto del diseño | Qué se observó | Spec |
|---|---|---|
| Los agentes solo existen si la sesión se abre en la carpeta del repositorio. | La spec, el plan y las tareas de la 001 las había escrito un agente genérico que imitaba al `planificador`, porque la sesión se abrió en la carpeta de arriba y `.claude/agents/` no se cargó. Desde la implementación de la 001, todo lo hicieron los agentes reales. | 001 |
| La aprobación de la spec se hace con preguntas cerradas, no leyendo el borrador entero. | El `planificador` deja cada decisión de producto como pregunta abierta con su recomendación, y la sesión principal se las presenta a la responsable una por una. Las decisiones quedan escritas en la spec con fecha. Lo que el plan decide por su cuenta se anota aparte, en «Diferencias con lo planeado», como «decisiones que la responsable no tomó expresamente». | 001–005 |
| Varios agentes trabajan a la vez, no en fila. | El diseño ponía `pruebas` → `backend-dev` → `frontend-dev`. En la práctica se lanzaron en paralelo las pruebas de backend y de frontend, y después los dos implementadores, porque escriben en carpetas distintas. Ahorra tiempo, pero tiene un costo: en la 005 se lanzó `frontend-dev` mientras otro agente aún escribía pruebas, la app dejó de compilar un rato y esas pruebas no se pudieron ver en rojo antes del código; se ejecutaron por primera vez contra la implementación. | 001–005 |
| Las tareas grandes se parten en tandas. | En la 005 la implementación del frontend se dividió en cinco encargos (modelos y providers, Inicio, detalle, pantallas vacías, caja de lecturas) y las pruebas en tres. Un encargo demasiado grande fue lo que dejó colgado a un agente en la 002. | 002, 005 |
| Hay una vuelta de corrección aunque el revisor apruebe. | En las specs 003, 004 y 005 el revisor aprobó con observaciones. La sesión principal mandó corregir las baratas y claras (dos estados atascados en la 003; pruebas que no protegían lo que decían en la 004 y la 005) con el mismo orden: primero la prueba, luego el código. Las que eran decisión de producto se dejaron a la responsable. | 003–005 |
| Las correcciones también empiezan por la prueba. | Cuando el revisor rechazó (001 y 002), el agente `pruebas` escribió primero una prueba que reprodujera el hallazgo y después corrigió el implementador. El revisor volvió a revisar y dejó en `revision.md` el historial de las dos vueltas. Nunca hizo falta la tercera. | 001, 002 |
| El revisor comprueba las pruebas con mutantes. | Sin que el diseño lo pidiera, el `revisor` copió el código a una carpeta temporal, lo rompió a propósito y miró si alguna prueba fallaba. Así aparecieron pruebas que pasaban con el código mal: el tope de temperatura sin ejercitar (004), una prueba de ancho que no detectaba texto recortado (004) y un filtro de desbordes demasiado permisivo (005). | 002–005 |
| El revisor revisa el árbol de trabajo, no los commits. | El diseño decía comparar `git diff --name-only main...HEAD` con la tabla del plan. Como los commits se hicieron al final, ese comando salía vacío y hubo que indicarle que usara `git status` y `git diff main`. | 001–005 |
| Los commits se hacen al final, uno por tarea. | El historial de cada rama tiene los commits de pruebas antes que los de código, pero se crearon después de la revisión y cada archivo entró en su versión final. El historial muestra el orden de las tareas, no el momento en que cada prueba estuvo en rojo ni las vueltas de corrección; eso consta en los informes de `pruebas` resumidos en `plan.md` y en `revision.md`. | 001–005 |
| La sesión principal abre el pull request. | El diseño dejaba a una persona abrir y fusionar. La responsable pidió en cada spec que la sesión hiciera los commits y abriera el PR desde su navegador; la fusión la hizo ella (la 001, la sesión, por encargo suyo y con la CI en verde). | 001–005 |

### Lo que el sistema encontró

| Qué | Cómo apareció | Spec |
|---|---|---|
| Fallos de seguridad que nadie había pedido buscar. | Al investigar el código antes de escribir cada spec, el `planificador` encontró que un diagnóstico podía guardarse en la planta de otro usuario (002), que cualquier usuario podía encender o apagar la bomba de la maceta de otro (003) y que regar una planta de ejemplo podía encender la bomba real (005). Los tres entraron en su spec con criterio y prueba. | 002, 003, 005 |
| Errores que pasaban todas las pruebas. | El `revisor` rechazó la 001 porque una planta seleccionada en otra sesión rompía Estadísticas, y la 002 porque la ruta nueva fallaba si llegaba sin planta. En los dos casos las pruebas estaban en verde y la cobertura por encima del umbral. | 001, 002 |
| Que una idea era más pequeña de lo que parecía. | Para «detener riego» el `planificador` leyó el firmware y vio que ya entendía la orden `STOP` y que el backend ya tenía el endpoint: faltaba solo la app. No hubo que tocar el firmware. | 003 |
| Que una sospecha era cierta, con un ejemplo. | Para «cálculo único de salud» encontró dos cálculos distintos (backend y app) y umbrales propios en la carita, y lo demostró con una lectura concreta que daba resultados distintos según el ESP8266 estuviera conectado. | 004 |

### Lo que no funcionó o tiene límites

| Qué | Qué se observó | Spec |
|---|---|---|
| Un agente se quedó colgado. | En la 002 el agente `pruebas` dejó de avanzar diez minutos sin escribir nada y falló; otro quedó a medias al cerrarse la sesión, con los archivos escritos pero sin informe. Se relanzaron con encargos más pequeños. Hay que mirar el disco, no solo el informe, para saber qué hizo un agente. | 002 |
| Los implementadores hacen cosas que nadie pidió. | En la 001 `frontend-dev` añadió horas bajo las gráficas y un tooltip sin criterio de aceptación. Desde entonces el encargo dice «no añadas nada que la spec no pida; propónlo en el informe». Aun así, pasar el formateador a un archivo entero ensució un diff en la 002 y hubo que deshacerlo a mano. | 001, 002 |
| Pruebas escritas a ciegas tienen defectos propios. | Varias pruebas se escribieron sin poder ejecutarse (el código aún no existía) y fallaron luego por un error de la prueba, no del código: datos de preparación incompletos (005) y comprobaciones de desborde que atrapaban filas ajenas a la spec (002, 005). Los implementadores no las tocaron, como exige el diseño; las corrigió el agente `pruebas`. | 002, 005 |
| «Decidir si una prueba está mal» no siempre lo decidió una persona. | El diseño lo reserva a una persona. En esos casos la sesión principal decidió acotar la prueba a lo que pedía su criterio y se lo informó a la responsable, en vez de preguntar antes. Fue más rápido, pero es una desviación del diseño. | 002, 005 |
| Las pruebas de ancho no equivalen a mirar la pantalla. | La fuente de las pruebas de Flutter es más ancha que la real: marca desbordes que quizá no ocurren en un teléfono y obliga a tolerar algunos. Tres pantallas (detalle de la planta, Inicio y el menú) tienen filas que se desbordan en pruebas a 320–360 px desde antes de estas specs; no se corrigieron por estar fuera de alcance. | 002, 004, 005 |
| El límite de carpetas es una instrucción, no un permiso. | Tal como avisaba la sección 3. No hubo ningún caso de un agente escribiendo fuera de su carpeta, pero lo que lo garantiza es el revisor comparando archivos, no la herramienta. | 001–005 |
| Nada de esto prueba el hardware. | Ninguna prueba usa la placa, la webcam, Gemini ni PostgreSQL. Todo lo que depende de ellos (que la bomba se apague de verdad, la hora local, las fotos) quedó como paso manual en la última tarea de cada spec. | 001–005 |
| La configuración del equipo importa. | `flutter` no estaba en el PATH de los agentes y hubo que indicarlo en cada encargo; `git push` y el navegador dependían de qué cuenta estuviera abierta, y una vez el PR tuvo que crearlo la responsable. | 001–005 |

### Decisiones que siguen en manos de una persona

Además de las del diseño inicial, al terminar quedan abiertas: responder las observaciones de cada
`revision.md`; en la 003, qué mostrar cuando la placa no confirma que la bomba se apagó; y las
comprobaciones manuales con la placa.

## 7. Mecanismos de calidad y su evidencia

| Mecanismo | Cómo funciona | Evidencia |
|---|---|---|
| Integración continua | Cada pull request hacia `main` ejecuta `pytest` con cobertura en el backend y `flutter analyze` + `flutter test` en el frontend. | [`.github/workflows/ci.yml`](.github/workflows/ci.yml) · pestaña [Actions](https://github.com/vbduero/solarApp/actions) · marca verde o roja en cada PR |
| Cobertura con umbral | La CI falla si la cobertura total del backend baja de 60 %. Es un piso: partimos de 62 % porque `hardware_helper.py` y `main.py` necesitan hardware o PostgreSQL reales. | [`backend/.coveragerc`](backend/.coveragerc) · informe en el log de cada ejecución |
| Pruebas antes del código | El agente `pruebas` escribe las pruebas desde los criterios de aceptación y comprueba que fallan; el commit de pruebas va antes que el de implementación. | Historial de commits de cada rama `feat/NNN-...` |
| Revisión por otro agente | El `revisor` (sin permiso de edición) vuelve a ejecutar todo y busca pruebas vacías, cosas inventadas y cambios fuera del plan. El equipo acepta o descarta cada observación. | `specs/NNN-nombre/revision.md` de cada spec |

Lo que estos mecanismos **no** detectan: errores del firmware o del hardware real (no hay placa en
la CI), problemas visuales de la app, la calidad del diagnóstico de Gemini y fallos de lógica en
código que las pruebas no ejercitan (la cobertura dice qué líneas se ejecutaron, no que estén bien).
