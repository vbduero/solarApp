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

| # | Spec | Pull request | Estado |
|---|---|---|---|
| 001 | Estadísticas con datos reales | — | pendiente |
| 002 | Historial de diagnósticos de IA por planta | — | pendiente |
| 003 | Detener el riego desde la app | — | pendiente |
| 004 | Un solo cálculo de salud de la planta | — | pendiente |
| 005 | Aviso de modo demo y errores visibles | — | pendiente |

## 6. Qué cambió del sistema de agentes respecto del taller

El diseño inicial está en [`docs/agentes-diseno-inicial.md`](docs/agentes-diseno-inicial.md).
Esta sección se actualiza con cada spec: qué cambió y qué se observó al ejecutarla.

| Cambio | Qué se observó | Spec |
|---|---|---|
| — | Todavía no se ha ejecutado ninguna spec. | — |

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
