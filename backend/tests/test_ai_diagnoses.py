# ============================================================
# Solar-Grow - Pruebas del listado de diagnósticos de IA (spec 002, CA-1 a CA-5)
# ============================================================
from datetime import datetime, timedelta, timezone

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.database import get_db
from app.models.recommendation import AIDiagnosis, HealthStatus
from app.routers import ai
from app.utils.auth import get_current_user

ai_app = FastAPI()
ai_app.include_router(ai.router)

NOW = datetime.now(timezone.utc)


@pytest.fixture
def auth_client(db, user):
    ai_app.dependency_overrides[get_db] = lambda: db
    ai_app.dependency_overrides[get_current_user] = lambda: user
    yield TestClient(ai_app)
    ai_app.dependency_overrides.clear()


@pytest.fixture
def anonymous_client(db):
    """Cliente sin token: get_current_user NO se sobreescribe."""
    ai_app.dependency_overrides[get_db] = lambda: db
    yield TestClient(ai_app)
    ai_app.dependency_overrides.clear()


def add_diagnosis(db, plant, minutes_ago=0, status=HealthStatus.BUENA, text="texto", created_at=None):
    row = AIDiagnosis(
        plant_id=plant.id,
        health_status=status,
        diagnosis=text,
        image_url=f"/static/diagnosticos/diag_{plant.id}_{minutes_ago}.jpg",
        created_at=created_at or (NOW - timedelta(minutes=minutes_ago)),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


# --- CA-1 ---

def test_listado_devuelve_solo_los_diagnosticos_de_la_planta_del_mas_reciente_al_mas_antiguo(
    auth_client, db, user, plant, other_plant
):
    oldest = add_diagnosis(db, plant, minutes_ago=30)
    newest = add_diagnosis(db, plant, minutes_ago=1)
    middle = add_diagnosis(db, plant, minutes_ago=10)
    add_diagnosis(db, other_plant, minutes_ago=0)

    response = auth_client.get(f"/api/ai/diagnosis/{plant.id}")

    assert response.status_code == 200
    assert [d["id"] for d in response.json()] == [newest.id, middle.id, oldest.id]
    assert {d["plant_id"] for d in response.json()} == {plant.id}


def test_listado_devuelve_como_maximo_los_10_mas_recientes(auth_client, db, plant):
    rows = [add_diagnosis(db, plant, minutes_ago=m) for m in range(12)]

    response = auth_client.get(f"/api/ai/diagnosis/{plant.id}")

    assert response.status_code == 200
    ids = [d["id"] for d in response.json()]
    assert ids == [r.id for r in rows[:10]]


def test_listado_con_la_misma_fecha_desempata_por_id_descendente(auth_client, db, plant):
    same_time = NOW - timedelta(minutes=5)
    first = add_diagnosis(db, plant, created_at=same_time)
    second = add_diagnosis(db, plant, created_at=same_time)
    third = add_diagnosis(db, plant, created_at=same_time)

    response = auth_client.get(f"/api/ai/diagnosis/{plant.id}")

    assert response.status_code == 200
    assert [d["id"] for d in response.json()] == [third.id, second.id, first.id]


def test_listado_trae_los_campos_del_contrato(auth_client, db, plant):
    row = add_diagnosis(db, plant, text="ESTADO GENERAL: Saludable")

    item = auth_client.get(f"/api/ai/diagnosis/{plant.id}").json()[0]

    assert item["id"] == row.id
    assert item["plant_id"] == plant.id
    assert item["health_status"] == "Buena"
    assert item["diagnosis"] == "ESTADO GENERAL: Saludable"
    assert item["image_url"] == row.image_url
    assert item["created_at"]


# --- CA-2 ---

@pytest.mark.parametrize(
    "status, expected",
    [
        pytest.param(HealthStatus.EXCELENTE, "Excelente", id="excelente"),
        pytest.param(HealthStatus.BUENA, "Buena", id="buena"),
        pytest.param(HealthStatus.REGULAR, "Regular", id="regular"),
        pytest.param(HealthStatus.MALA, "Mala", id="mala"),
        pytest.param(HealthStatus.CRITICA, "Critica", id="critica"),
    ],
)
def test_listado_envia_health_status_en_espanol(auth_client, db, plant, status, expected):
    add_diagnosis(db, plant, status=status)

    response = auth_client.get(f"/api/ai/diagnosis/{plant.id}")

    assert response.status_code == 200
    assert response.json()[0]["health_status"] == expected


# --- CA-3 ---

def test_listado_sin_diagnosticos_devuelve_lista_vacia(auth_client, plant):
    response = auth_client.get(f"/api/ai/diagnosis/{plant.id}")
    assert response.status_code == 200
    assert response.json() == []


# --- CA-4 ---

def test_listado_de_planta_ajena_devuelve_404(auth_client, db, other_plant):
    add_diagnosis(db, other_plant)

    response = auth_client.get(f"/api/ai/diagnosis/{other_plant.id}")

    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"


def test_listado_de_planta_inexistente_devuelve_404(auth_client, plant):
    response = auth_client.get(f"/api/ai/diagnosis/{plant.id + 999}")
    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"


def test_listado_sin_token_devuelve_401(anonymous_client, plant):
    response = anonymous_client.get(f"/api/ai/diagnosis/{plant.id}")
    assert response.status_code == 401


# --- CA-5 ---

def test_listado_de_planta_borrada_devuelve_404(auth_client, db, plant):
    add_diagnosis(db, plant)
    plant.is_active = False
    db.commit()

    response = auth_client.get(f"/api/ai/diagnosis/{plant.id}")

    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"
