# ============================================================
# Solar-Grow - Pruebas de GET /api/sensors/history/{plant_id} (spec 001)
# ============================================================
# CA-10 a CA-13. Las lecturas se crean con recorded_at explícito y con zona.
# La temperatura se usa como identificador de cada lectura.
# ============================================================
from datetime import datetime, timedelta, timezone

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.database import get_db
from app.models.sensor_data import SensorData
from app.routers import sensors
from app.utils.auth import get_current_user

history_app = FastAPI()
history_app.include_router(sensors.router)


@pytest.fixture
def history_client(db, user):
    """Cliente con sesión (usuario de prueba)."""
    history_app.dependency_overrides[get_db] = lambda: db
    history_app.dependency_overrides[get_current_user] = lambda: user
    yield TestClient(history_app)
    history_app.dependency_overrides.clear()


@pytest.fixture
def history_anonymous_client(db):
    """Cliente sin token: get_current_user NO se sobreescribe."""
    history_app.dependency_overrides[get_db] = lambda: db
    yield TestClient(history_app)
    history_app.dependency_overrides.clear()


def _add_reading(db, plant_id, age, marker):
    """Inserta una lectura registrada hace `age` y con temperature=marker."""
    reading = SensorData(
        plant_id=plant_id,
        temperature=marker,
        air_humidity=50.0,
        soil_humidity=40.0,
        recorded_at=datetime.now(timezone.utc) - age,
    )
    db.add(reading)
    db.commit()
    return reading


def _markers(response):
    return [item["temperature"] for item in response.json()]


# ---------------- CA-10 ----------------

def test_historial_devuelve_solo_las_lecturas_del_periodo_y_de_la_planta(
    db, plant, other_plant, history_client
):
    _add_reading(db, plant.id, timedelta(hours=1), 1.0)
    _add_reading(db, plant.id, timedelta(hours=5), 5.0)
    _add_reading(db, plant.id, timedelta(hours=7), 7.0)   # fuera de 6 h
    _add_reading(db, plant.id, timedelta(days=3), 72.0)   # fuera de 6 h
    _add_reading(db, other_plant.id, timedelta(hours=2), 99.0)  # otra planta

    response = history_client.get(f"/api/sensors/history/{plant.id}?hours=6")

    assert response.status_code == 200
    assert sorted(_markers(response)) == [1.0, 5.0]


def test_historial_ordena_de_la_mas_reciente_a_la_mas_antigua(db, plant, history_client):
    # Se insertan desordenadas a propósito
    _add_reading(db, plant.id, timedelta(hours=10), 10.0)
    _add_reading(db, plant.id, timedelta(hours=1), 1.0)
    _add_reading(db, plant.id, timedelta(hours=20), 20.0)
    _add_reading(db, plant.id, timedelta(hours=5), 5.0)

    response = history_client.get(f"/api/sensors/history/{plant.id}?hours=24")

    assert response.status_code == 200
    assert _markers(response) == [1.0, 5.0, 10.0, 20.0]


def test_historial_sin_lecturas_devuelve_lista_vacia(db, plant, history_client):
    # Solo hay una lectura vieja, fuera del periodo
    _add_reading(db, plant.id, timedelta(days=10), 1.0)

    response = history_client.get(f"/api/sensors/history/{plant.id}?hours=24")

    assert response.status_code == 200
    assert response.json() == []


# ---------------- CA-11 ----------------

@pytest.mark.parametrize("hours", [0, -1, 721])
def test_historial_rechaza_hours_fuera_de_rango(db, plant, history_client, hours):
    _add_reading(db, plant.id, timedelta(hours=1), 1.0)

    response = history_client.get(f"/api/sensors/history/{plant.id}?hours={hours}")

    assert response.status_code == 422
    assert not isinstance(response.json(), list)


@pytest.mark.parametrize("limit", [0, -1, 501])
def test_historial_rechaza_limit_fuera_de_rango(db, plant, history_client, limit):
    _add_reading(db, plant.id, timedelta(hours=1), 1.0)

    response = history_client.get(f"/api/sensors/history/{plant.id}?limit={limit}")

    assert response.status_code == 422
    assert not isinstance(response.json(), list)


@pytest.mark.parametrize(
    "query",
    ["hours=1", "hours=720", "limit=1", "limit=500"],
)
def test_historial_acepta_los_limites(db, plant, history_client, query):
    _add_reading(db, plant.id, timedelta(minutes=10), 1.0)

    response = history_client.get(f"/api/sensors/history/{plant.id}?{query}")

    assert response.status_code == 200
    assert _markers(response) == [1.0]


def test_historial_sin_parametros_usa_24_horas_y_limite_100(db, plant, history_client):
    # 120 lecturas dentro de las últimas 24 h y una de hace 30 h
    for k in range(120):
        _add_reading(db, plant.id, timedelta(minutes=10 * k + 1), float(k))
    _add_reading(db, plant.id, timedelta(hours=30), 999.0)

    response = history_client.get(f"/api/sensors/history/{plant.id}")

    assert response.status_code == 200
    assert len(response.json()) == 100
    assert 999.0 not in _markers(response)


# ---------------- CA-12 ----------------

def test_historial_con_mas_lecturas_que_limit_cubre_todo_el_periodo(
    db, plant, history_client
):
    # 50 lecturas repartidas en 29 días; marker 0 = la más reciente, 49 = la más antigua
    total = 50
    span = timedelta(days=29)
    for k in range(total):
        _add_reading(db, plant.id, span * k / (total - 1) + timedelta(minutes=1), float(k))

    response = history_client.get(f"/api/sensors/history/{plant.id}?hours=720&limit=10")

    assert response.status_code == 200
    markers = _markers(response)
    assert len(markers) == 10
    assert markers[0] == 0.0       # la más reciente del periodo
    assert markers[-1] == 49.0     # la más antigua del periodo
    assert set(markers) != set(float(k) for k in range(10))  # no son las 10 más recientes
    assert markers == sorted(markers)  # orden de la más reciente a la más antigua
    assert len(set(markers)) == 10


# ---------------- Obs. 4 de la revisión: desempate determinista ----------------

def _add_reading_at(db, plant_id, recorded_at, marker):
    """Inserta una lectura con un recorded_at exacto (para provocar empates)."""
    reading = SensorData(
        plant_id=plant_id,
        temperature=marker,
        air_humidity=50.0,
        soil_humidity=40.0,
        recorded_at=recorded_at,
    )
    db.add(reading)
    db.commit()
    return reading


def test_historial_con_el_mismo_recorded_at_desempata_por_id_descendente(
    db, plant, history_client
):
    same_time = datetime.now(timezone.utc) - timedelta(hours=2)
    older = datetime.now(timezone.utc) - timedelta(hours=5)
    newer = datetime.now(timezone.utc) - timedelta(hours=1)
    # marker = orden de inserción, por tanto también el orden de id
    _add_reading_at(db, plant.id, same_time, 1.0)
    _add_reading_at(db, plant.id, same_time, 2.0)
    _add_reading_at(db, plant.id, older, 3.0)
    _add_reading_at(db, plant.id, same_time, 4.0)
    _add_reading_at(db, plant.id, newer, 5.0)
    _add_reading_at(db, plant.id, same_time, 6.0)

    response = history_client.get(f"/api/sensors/history/{plant.id}?hours=24")

    assert response.status_code == 200
    # Más reciente primero; a igual fecha, primero el de id mayor
    assert _markers(response) == [5.0, 6.0, 4.0, 2.0, 1.0, 3.0]


def test_historial_con_empates_y_mas_lecturas_que_limit_no_repite_ni_pierde_extremos(
    db, plant, history_client
):
    # 12 lecturas en 4 grupos de 3 con la misma fecha. marker k = orden de
    # inserción (= id). El grupo g es más reciente cuanto mayor es g, así que el
    # orden completo (fecha desc, id desc) es 11, 10, 9, ..., 0.
    now = datetime.now(timezone.utc)
    for k in range(12):
        group = k // 3
        _add_reading_at(db, plant.id, now - timedelta(hours=4 - group), float(k))

    response = history_client.get(f"/api/sensors/history/{plant.id}?hours=24&limit=5")

    assert response.status_code == 200
    markers = _markers(response)
    assert len(markers) == len(set(markers)) == 5
    assert markers[0] == 11.0   # la más reciente (id mayor del grupo más nuevo)
    assert markers[-1] == 0.0   # la más antigua (id menor del grupo más viejo)
    # Posiciones round(i * 11 / 4) = 0, 3, 6, 8, 11 sobre el orden determinista
    assert markers == [11.0, 8.0, 5.0, 3.0, 0.0]


# ---------------- CA-13 ----------------

def test_historial_de_planta_ajena_devuelve_404(db, other_plant, history_client):
    _add_reading(db, other_plant.id, timedelta(hours=1), 1.0)

    response = history_client.get(f"/api/sensors/history/{other_plant.id}")

    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"


def test_historial_de_planta_inexistente_devuelve_404(history_client):
    response = history_client.get("/api/sensors/history/99999")

    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"


def test_historial_sin_token_devuelve_401(db, plant, history_anonymous_client):
    response = history_anonymous_client.get(f"/api/sensors/history/{plant.id}")

    assert response.status_code == 401
