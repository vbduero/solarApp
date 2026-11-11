# SolarApp (Solar-Grow)

Estación ambiental inteligente para el cuidado de plantas: un backend FastAPI recibe datos de sensores
(ESP32 / Raspberry Pi 4: DHT22, humedad de suelo, LDR, cámara) y una app Flutter los muestra, genera
tareas de cuidado (regar, fertilizar, trasplantar…) y pide diagnósticos de IA (Google Gemini).

Este repositorio es un **monorepo**. Cada parte tiene su propio archivo de memoria, que se carga
cuando se trabaja en esa carpeta:

| Carpeta     | Qué es                                  | Memoria               |
|-------------|-----------------------------------------|-----------------------|
| `backend/`  | API REST · Python + FastAPI + SQLAlchemy | `backend/CLAUDE.md`   |
| `frontend/` | App móvil/web · Flutter (Dart) + Provider | `frontend/CLAUDE.md` |
| `database/` | `init.sql`: crea usuario y BD PostgreSQL | —                     |

## Entorno del equipo
- Todos desarrollamos en **Windows con PowerShell**. Escribe los comandos en sintaxis de PowerShell
  (`;` para encadenar, `.\venv\Scripts\Activate.ps1`, rutas con `\`).
- Base de datos local: PostgreSQL en `localhost:5432`, base `solar_grow_db`.
- El backend corre en `http://localhost:8000`; la app Flutter lo consume (web: `localhost`,
  emulador Android: `10.0.2.2`).

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
  `chore/<descripcion>`. A `main` solo se llega por pull request.
- Commits: Conventional Commits en español: `feat: permite crear tareas desde el detalle de la planta`.
- Cada cambio de lógica va con su prueba (pytest en backend, `flutter test` en frontend).

## Lo que el agente NO debe hacer
- No hacer commit de `.env`, de `backend/venv/`, de `frontend/build/` ni de imágenes nuevas de
  `backend/static/` (son subidas de usuarios).
- No cambiar `SECRET_KEY`, `DATABASE_URL`, `GEMINI_API_KEY` ni IPs de la Raspberry en el código: van en
  `backend/.env`. Nunca escribas claves reales en archivos versionados.
- No borrar ni reescribir `database/init.sql` ni `backend/seed_data.py` sin que se pida.
- No hacer `git push` a `main` ni fusionar pull requests: eso lo hace el equipo.
