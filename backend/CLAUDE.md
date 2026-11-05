# Backend · Solar-Grow API

API REST en **Python 3.13 + FastAPI 0.115 + SQLAlchemy 2.0 (ORM síncrono) + PostgreSQL**.
Autenticación JWT (python-jose + passlib/bcrypt). Pydantic v2 para validación.

## Comandos (PowerShell, desde `backend\`)
```powershell
# Primera vez
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
pip install "psycopg[binary]" requests google-genai   # faltan en requirements.txt (ver Trampas)

# Base de datos (una vez): ejecutar ..\database\init.sql en PostgreSQL y luego datos demo
python seed_data.py            # usuario demo: demo@solargrow.com / solar123

# Ejecutar el API (docs en http://localhost:8000/docs)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

# Pruebas
pip install pytest
python -m pytest -q
```
Siempre activa el `venv` antes de ejecutar algo. Las rutas relativas (`static/images`) asumen que el
proceso se lanza desde `backend\`.

## Organización y dependencias permitidas
```
app/
  main.py       crea la app, CORS, monta /static y registra los routers
  config.py     Settings (pydantic-settings) leídas de backend/.env
  database.py   engine, SessionLocal, Base y la dependencia get_db()
  models/       tablas SQLAlchemy (User, Plant, SensorData, Task, Recommendation, AIDiagnosis)
  schemas/      modelos Pydantic de entrada/salida: XCreate, XUpdate, XResponse
  routers/      un APIRouter por recurso, prefijo /api/<recurso>
  utils/auth.py hash de contraseñas, JWT y la dependencia get_current_user
```
- `routers` → puede usar `models`, `schemas`, `utils`, `database`. `models` y `schemas` **no**
  importan routers. `models` no importa `schemas`.
- La carpeta `services/` existe pero está vacía: la lógica que se repita entre routers va ahí como
  funciones puras que reciben la `Session`.
- No hay Alembic: las tablas se crean con `Base.metadata.create_all()` al arrancar. Agregar una columna
  a una tabla existente **no** la crea en una BD ya creada; avisa al equipo si un cambio lo requiere.

## Patrón de un endpoint
- Firma: `db: Session = Depends(get_db)` y `current_user: User = Depends(get_current_user)`.
- **Toda consulta filtra por el dueño**: `Model.user_id == current_user.id`. Si no existe → `HTTPException(404, "<Recurso> no encontrada")` (mensajes en español).
- Borrado de plantas es lógico (`is_active = False`); los listados filtran `is_active == True`.
- Los enums SQLAlchemy (`TaskType`, `TaskStatus`, `PlantLocation`) se devuelven con `.value`.
- Fechas siempre con zona horaria: `datetime.now(timezone.utc)`, columnas `DateTime(timezone=True)`.
- Al crear un router nuevo, regístralo en `app/main.py` y agrega la ruta a
  `frontend/lib/config/api_constants.dart`.

## Pruebas
- Aún no hay pruebas. Ubícalas en `backend/tests/` (`test_<router>.py`) con `pytest` y
  `fastapi.testclient.TestClient`.
- No usar la BD real: sobreescribir `get_db` con `app.dependency_overrides` apuntando a SQLite en
  memoria (`sqlite://` + `StaticPool`) y `get_current_user` con un usuario de prueba.

## Trampas conocidas
- `DATABASE_URL` usa el driver `postgresql+psycopg` (psycopg 3) pero `requirements.txt` trae
  `psycopg2-binary`. Si agregas dependencias, añádelas a `requirements.txt` con versión fija.
- `routers/hardware.py` usa `requests` y `google.genai`, que no están en `requirements.txt`, y tiene
  la IP de la Raspberry fija en `URL_RASPBERRY`. Requiere hardware real: no lo toques ni lo
  ejecutes en pruebas.
- `Task.days_overdue` y el estado `Atrasada` no se calculan en ningún lado (se guardan como vienen).
- `error.txt` y `../analyze_output.txt` son salidas de consola viejas, no documentación.

## No hacer
- No escribir secretos en `config.py`: los valores por defecto son solo para desarrollo local;
  los reales van en `backend/.env` (ignorado por git).
- No cambiar `allow_origins=["*"]` ni el tiempo de expiración del token sin que se pida.
- No borrar archivos de `static/` (son imágenes subidas por usuarios).
