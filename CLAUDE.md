# SolarApp (Solar-Grow)

Maceta inteligente para el cuidado de plantas. Un **ESP8266 NodeMCU** lee la humedad del suelo, la
temperatura y la humedad del aire y controla una bomba de riego; se conecta por **USB serial** al PC
donde corre el backend **FastAPI**, que además toma una foto con la **webcam del PC** y la envía a
**Google Gemini** para diagnosticar la planta. Una app **Flutter** muestra plantas, lecturas, tareas
de cuidado, riego remoto y diagnósticos.

No hay ESP32, Raspberry Pi, MQTT, sensor de luz ni panel solar conectados: los valores de luz,
voltaje solar y batería son constantes de relleno. No los presentes como lecturas reales.

Este repositorio es un **monorepo**. Cada parte tiene su propia memoria, que se carga al trabajar
en esa carpeta:

| Carpeta | Qué es | Memoria |
|---|---|---|
| `backend/` | API REST · Python + FastAPI + SQLAlchemy | `backend/CLAUDE.md` |
| `frontend/` | App móvil/web · Flutter (Dart) + Provider | `frontend/CLAUDE.md` |
| `esp8266_maceta_inteligente/` | Firmware Arduino del ESP8266 | — |
| `database/` | `init.sql`: crea usuario y BD PostgreSQL | — |
| `specs/` | Una carpeta por spec (SDD) | `.claude/rules/specs.md` |

El arnés completo (rules, skills, agentes, flujo y calidad) está explicado en `README.md`.

## Entorno del equipo
- Todos desarrollamos en **Windows con PowerShell**. Escribe los comandos en sintaxis de PowerShell
  (`;` para encadenar, `.\venv\Scripts\Activate.ps1`, rutas con `\`).
- Base de datos local: PostgreSQL en `localhost:5432`, base `solar_grow_db`.
- El backend corre en `http://localhost:8000`; la app Flutter lo consume (web: `localhost`,
  emulador Android: `10.0.2.2`).
- El ESP8266 se conecta al puerto `SERIAL_PORT` de `backend/.env` (por defecto `COM3`, 115200).

## Comandos de verificación (los mismos que corre la CI)
```powershell
cd backend;  .\venv\Scripts\python.exe -m pytest -q --cov --cov-config=.coveragerc
cd frontend; flutter analyze --no-fatal-infos --no-fatal-warnings; flutter test
```

## Flujo de trabajo: desarrollo guiado por especificaciones
Toda funcionalidad sigue este orden. La sesión principal coordina; cada paso lo hace un agente de
`.claude/agents/`:

1. `planificador` → escribe `specs/NNN-nombre/spec.md`. **Una persona la aprueba.**
2. `planificador` → `plan.md` y `tasks.md`.
3. `pruebas` → pruebas desde los criterios de aceptación; deben fallar.
4. `backend-dev` y luego `frontend-dev` → código hasta que las pruebas pasen.
5. `revisor` → `revision.md`. Si rechaza, vuelve al paso 4 (máximo 2 vueltas; después decide una persona).
6. Una persona responde las observaciones, abre el pull request y espera la CI en verde.

No te saltes pasos ni escribas código de la app sin spec aprobada.

## Contrato entre backend y frontend
- Todas las rutas del API empiezan por `/api/...` y están listadas en
  `frontend/lib/config/api_constants.dart`. Si agregas o cambias un endpoint en `backend/app/routers/`,
  actualiza también ese archivo y el modelo Dart correspondiente en `frontend/lib/models/`.
- Los JSON usan `snake_case` (lo que devuelven los schemas Pydantic). Los modelos Dart los mapean a
  `camelCase` en `fromJson`.
- Los valores de enums viajan en español y con mayúscula inicial: `"Regar"`, `"Pendiente"`,
  `"Completada"`, `"Atrasada"`, `"Balcon"`… No los traduzcas ni cambies su formato.

## Convenciones del equipo
- Idioma: código (variables, funciones) en inglés; comentarios, docstrings, mensajes al usuario y
  textos de UI en **español**.
- Ramas: se trabaja siempre en una rama creada desde `main`: `feat/<descripcion>`, `fix/<descripcion>`,
  `chore/<descripcion>`. Las de una spec llevan su número: `feat/001-estadisticas-reales`.
  A `main` solo se llega por pull request.
- Commits: Conventional Commits en español: `feat: permite crear tareas desde el detalle de la planta`.
- Cada cambio de lógica va con su prueba (pytest en backend, `flutter test` en frontend).

## Lo que el agente NO debe hacer
- No hacer commit de `.env`, de `backend/venv/`, de `frontend/build/` ni de imágenes nuevas de
  `backend/static/` (son subidas de usuarios).
- No cambiar `SECRET_KEY`, `DATABASE_URL`, `GEMINI_API_KEY` ni `DEVICE_API_KEY` en el código: van en
  `backend/.env`. Nunca escribas claves reales en archivos versionados.
- No borrar ni reescribir `database/init.sql` ni `backend/seed_data.py` sin que se pida.
- No hacer `git push` a `main` ni fusionar pull requests: eso lo hace el equipo.
- No modificar el firmware (`esp8266_maceta_inteligente/`) dentro de una spec de software: controla
  una bomba real y no se puede probar sin la placa. Si hace falta, avisa.
- No debilitar ni saltar pruebas, ni bajar el umbral de cobertura de `backend/.coveragerc`.
