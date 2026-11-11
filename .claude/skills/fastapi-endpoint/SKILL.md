---
name: fastapi-endpoint
description: Crea o modifica endpoints del backend FastAPI de Solar-Grow (carpeta backend/) con su schema Pydantic, filtro por usuario dueño y prueba pytest. Úsala cuando la tarea pida agregar, cambiar o probar una ruta /api/... del backend.
---

# Endpoint FastAPI para Solar-Grow

Sigue estos pasos en orden cada vez que agregues o cambies un endpoint en `backend/`.

## 1. Ubicar el recurso
- Router: `backend/app/routers/<recurso>.py` (prefijo `/api/<recurso>`).
- Modelo: `backend/app/models/<recurso>.py`. Schemas: `backend/app/schemas/<recurso>.py`.
- Si el recurso es nuevo, crea los tres archivos, exporta el modelo en `models/__init__.py`,
  impórtalo en `main.py` (línea `from .models import ...`) y registra el router con
  `app.include_router(...)`.

## 2. Schemas (Pydantic v2)
- `XCreate` para el cuerpo de POST, `XUpdate` con todos los campos `Optional` para PATCH/PUT,
  `XResponse` con `class Config: from_attributes = True`.
- Valida enums con `Literal[...]` o el `Enum` del modelo; nunca aceptes `str` libre si el modelo
  usa un enum.

## 3. Endpoint
Plantilla:
```python
@router.patch("/{item_id}", response_model=XResponse)
async def update_x(
    item_id: int,
    data: XUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Docstring en español: qué hace y para qué pantalla."""
    item = db.query(X).filter(X.id == item_id, X.user_id == current_user.id).first()
    if not item:
        raise HTTPException(status_code=404, detail="X no encontrada")
    ...
    db.commit()
    db.refresh(item)
    return XResponse.model_validate(item)
```
Reglas:
- Siempre filtrar por `user_id == current_user.id` (un usuario nunca ve datos de otro).
- Errores con `HTTPException` y `detail` en español; 404 si no existe, 400 si el dato es inválido.
- Fechas con `datetime.now(timezone.utc)`.
- Si la lógica se repite en más de un endpoint, muévela a `backend/app/services/<recurso>_service.py`
  como función que recibe `db: Session`.

## 4. Prueba
Crea o amplía `backend/tests/test_<recurso>.py`. Si no existe `backend/tests/conftest.py`, créalo
con este fixture (SQLite en memoria, sin tocar PostgreSQL ni hardware):
```python
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401  registra todas las tablas en Base.metadata
from app.database import Base, get_db
from app.models.user import User
from app.routers import plants, tasks  # agrega aquí el router que pruebas
from app.utils.auth import get_current_user

# App mínima: NO importar app.main (crea tablas en PostgreSQL y carga hardware.py)
test_app = FastAPI()
test_app.include_router(plants.router)
test_app.include_router(tasks.router)

engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
TestingSession = sessionmaker(bind=engine, autoflush=False, autocommit=False)

@pytest.fixture
def db():
    Base.metadata.create_all(bind=engine)
    session = TestingSession()
    yield session
    session.close()
    Base.metadata.drop_all(bind=engine)

@pytest.fixture
def user(db):
    u = User(email="test@solargrow.com", hashed_password="x", full_name="Test")
    db.add(u); db.commit(); db.refresh(u)
    return u

@pytest.fixture
def client(db, user):
    test_app.dependency_overrides[get_db] = lambda: db
    test_app.dependency_overrides[get_current_user] = lambda: user
    yield TestClient(test_app)
    test_app.dependency_overrides.clear()
```
Cubre como mínimo: caso feliz, recurso de otro usuario → 404, dato inválido → 400/422.
Para crear datos de otro usuario, inserta un segundo `User` directamente con la sesión `db`.

Notas:
- `app/database.py` crea el engine de PostgreSQL al importarse (no conecta, pero necesita el driver
  `psycopg` instalado). Las pruebas no lo usan porque `get_db` queda sobreescrito.
- Ejecuta pytest desde `backend\` para que el paquete `app` se encuentre (o agrega
  `backend/pytest.ini` con `[pytest]` y `pythonpath = .`).

## 5. Verificar
```powershell
cd backend; .\venv\Scripts\Activate.ps1; python -m pytest -q
```
Si cambiaste rutas, agrega la constante en `frontend/lib/config/api_constants.dart`.
