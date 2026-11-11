# ============================================================
# Solar-Grow - Fixtures de pruebas (SQLite en memoria)
# ============================================================
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import app.models  # noqa: F401  registra todas las tablas en Base.metadata
from app.database import Base, get_db
from app.models.plant import Plant, PlantLocation
from app.models.user import User
from app.routers import tasks
from app.utils.auth import get_current_user

# App mínima: NO importar app.main (crea tablas en PostgreSQL y carga hardware.py)
test_app = FastAPI()
test_app.include_router(tasks.router)

engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
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
    test_user = User(email="test@solargrow.com", hashed_password="x", full_name="Test")
    db.add(test_user)
    db.commit()
    db.refresh(test_user)
    return test_user


@pytest.fixture
def other_user(db):
    second_user = User(email="otro@solargrow.com", hashed_password="x", full_name="Otro")
    db.add(second_user)
    db.commit()
    db.refresh(second_user)
    return second_user


def _create_plant(db, owner):
    plant = Plant(user_id=owner.id, common_name="Echeveria", location=PlantLocation.BALCON)
    db.add(plant)
    db.commit()
    db.refresh(plant)
    return plant


@pytest.fixture
def plant(db, user):
    return _create_plant(db, user)


@pytest.fixture
def other_plant(db, other_user):
    return _create_plant(db, other_user)


@pytest.fixture
def client(db, user):
    test_app.dependency_overrides[get_db] = lambda: db
    test_app.dependency_overrides[get_current_user] = lambda: user
    yield TestClient(test_app)
    test_app.dependency_overrides.clear()
