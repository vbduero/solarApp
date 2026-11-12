# ============================================================
# Solar-Grow - Pruebas de la salud según sensores en el API (spec 004)
# ============================================================
# GET /api/sensors/latest/{id} y GET /api/hardware/clima-actual.
# No se usa hardware real: obtener_datos_actuales se reemplaza con monkeypatch
# y ESP8266_PLANT_ID se fija en cada prueba.
# ============================================================
from datetime import datetime, timezone

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.config import get_settings
from app.database import get_db
from app.models.sensor_data import SensorData
from app.routers import hardware, sensors
from app.utils.auth import get_current_user

salud_app = FastAPI()
salud_app.include_router(sensors.router)
salud_app.include_router(hardware.router)

ESTADOS = {"Sana", "Necesita agua", "Exceso de calor", "Critica", "Sin datos"}
ESTADOS_VIEJOS = {"healthy", "needs_water", "needs_light", "stressed", "critical", "unknown"}

# (suelo, temperatura, estado, puntaje): tabla de CA-1 (Echeveria: 25 y 35)
TABLA_CA1 = [
    pytest.param(50, 28, "Sana", 100.0, id="normal"),
    pytest.param(25, 35, "Sana", 100.0, id="justo-en-ambos-umbrales"),
    pytest.param(20, 28, "Necesita agua", 90.0, id="suelo-bajo"),
    pytest.param(0, 28, "Necesita agua", 60.0, id="suelo-cero"),
    pytest.param(50, 40, "Exceso de calor", 85.0, id="calor"),
    pytest.param(15, 45, "Necesita agua", 50.0, id="suelo-bajo-y-calor"),
    pytest.param(0, 45, "Critica", 30.0, id="critica"),
]


@pytest.fixture(autouse=True)
def esp8266_plant_sin_configurar(monkeypatch):
    """Fija ESP8266_PLANT_ID en None: la planta del ESP8266 es la activa más antigua."""
    monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", None)


@pytest.fixture
def anonymous_client(db):
    salud_app.dependency_overrides[get_db] = lambda: db
    yield TestClient(salud_app)
    salud_app.dependency_overrides.clear()


@pytest.fixture
def auth_client(db, user):
    salud_app.dependency_overrides[get_db] = lambda: db
    salud_app.dependency_overrides[get_current_user] = lambda: user
    yield TestClient(salud_app)
    salud_app.dependency_overrides.clear()


@pytest.fixture
def echeveria(db, plant):
    """La planta del usuario con los umbrales de la spec: 25 % y 35 °C."""
    plant.min_humidity = 25
    plant.max_temperature = 35
    db.commit()
    return plant


def guardar_lectura(db, plant, **campos):
    campos.setdefault("recorded_at", datetime.now(timezone.utc))
    reading = SensorData(plant_id=plant.id, **campos)
    db.add(reading)
    db.commit()
    return reading


def pedir_latest(client, plant):
    response = client.get(f"/api/sensors/latest/{plant.id}")
    assert response.status_code == 200
    return response.json()


def lectura_en_vivo(monkeypatch, soil, temperature, conexion="En línea"):
    reading = {
        "status_conexion": conexion,
        "temperatura": temperature,
        "humedad_aire": 50.0,
        "humedad_suelo": soil,
        "humedad_suelo_raw": 500,
        "led_encendido": False,
    }
    monkeypatch.setattr(hardware, "obtener_datos_actuales", lambda: reading)


# --- CA-1: caso normal ---

@pytest.mark.parametrize("soil, temperature, status, score", TABLA_CA1)
def test_latest_devuelve_estado_y_puntaje_de_la_tabla(
    auth_client, db, echeveria, soil, temperature, status, score
):
    guardar_lectura(db, echeveria, soil_humidity=soil, temperature=temperature, light_level=85)
    body = pedir_latest(auth_client, echeveria)
    assert body["health_status"] == status
    assert body["health_score"] == score


def test_latest_usa_la_lectura_mas_reciente(auth_client, db, echeveria):
    guardar_lectura(
        db, echeveria, soil_humidity=0, temperature=45,
        recorded_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
    )
    guardar_lectura(db, echeveria, soil_humidity=50, temperature=28)
    body = pedir_latest(auth_client, echeveria)
    assert (body["health_status"], body["health_score"]) == ("Sana", 100.0)


def test_latest_usa_los_umbrales_de_la_planta(auth_client, db, echeveria):
    echeveria.min_humidity = 60
    db.commit()
    guardar_lectura(db, echeveria, soil_humidity=50, temperature=28)
    body = pedir_latest(auth_client, echeveria)
    assert (body["health_status"], body["health_score"]) == ("Necesita agua", 80.0)


def test_latest_con_umbrales_nulos_usa_30_y_35(auth_client, db, echeveria):
    echeveria.min_humidity = None
    echeveria.max_temperature = None
    db.commit()
    guardar_lectura(db, echeveria, soil_humidity=25, temperature=36)
    body = pedir_latest(auth_client, echeveria)
    assert (body["health_status"], body["health_score"]) == ("Necesita agua", 87.0)


# --- CA-2: luz, voltaje, batería y min_light no cuentan ---

@pytest.mark.parametrize("soil, temperature, status, score", TABLA_CA1)
@pytest.mark.parametrize(
    "light, voltage, battery, min_light",
    [
        pytest.param(0, 0, 0, 90, id="todo-en-cero-y-min_light-alto"),
        pytest.param(85, 18, 100, 0, id="todo-alto-y-min_light-cero"),
        pytest.param(0, 18, 0, 90, id="luz-cero-voltaje-alto"),
        pytest.param(85, 0, 100, 90, id="luz-85-con-min_light-90"),
    ],
)
def test_latest_ignora_luz_voltaje_bateria_y_min_light(
    auth_client, db, echeveria, soil, temperature, status, score,
    light, voltage, battery, min_light,
):
    echeveria.min_light = min_light
    db.commit()
    guardar_lectura(
        db, echeveria, soil_humidity=soil, temperature=temperature,
        light_level=light, solar_voltage=voltage, battery_level=battery,
    )
    body = pedir_latest(auth_client, echeveria)
    assert body["health_status"] == status
    assert body["health_score"] == score


# --- CA-3: formato ---

def test_latest_solo_envia_los_cinco_estados_en_espanol(auth_client, db, echeveria, plant):
    vistos = set()
    # Sin lecturas
    vistos.add(pedir_latest(auth_client, echeveria)["health_status"])
    for soil, temperature, _, _ in (p.values for p in TABLA_CA1):
        guardar_lectura(db, echeveria, soil_humidity=soil, temperature=temperature)
        vistos.add(pedir_latest(auth_client, echeveria)["health_status"])
    assert vistos == ESTADOS
    assert not (vistos & ESTADOS_VIEJOS)


# --- CA-4: sin lecturas ---

def test_latest_sin_lecturas_devuelve_sin_datos_y_puntaje_null(auth_client, echeveria):
    body = pedir_latest(auth_client, echeveria)
    assert body["health_status"] == "Sin datos"
    assert body["health_score"] is None
    for campo in ("temperature", "air_humidity", "soil_humidity", "light_level",
                  "solar_voltage", "battery_level"):
        assert body[campo] is None


# --- CA-5: lectura incompleta ---

@pytest.mark.parametrize("temperature", [None, 28, 45])
def test_latest_sin_humedad_del_suelo_devuelve_sin_datos(auth_client, db, echeveria, temperature):
    # La humedad del aire no sustituye a la del suelo
    guardar_lectura(db, echeveria, soil_humidity=None, temperature=temperature, air_humidity=10)
    body = pedir_latest(auth_client, echeveria)
    assert body["health_status"] == "Sin datos"
    assert body["health_score"] is None


def test_latest_sin_temperatura_evalua_solo_el_suelo(auth_client, db, echeveria):
    guardar_lectura(db, echeveria, soil_humidity=20, temperature=None)
    body = pedir_latest(auth_client, echeveria)
    assert (body["health_status"], body["health_score"]) == ("Necesita agua", 90.0)


# --- CA-6: planta ajena o inexistente, y sin sesión (ya pasan: fijan el comportamiento actual) ---

@pytest.mark.parametrize("objetivo", ["ajena", "inexistente"])
def test_latest_de_planta_ajena_o_inexistente_devuelve_404(
    auth_client, db, other_plant, objetivo
):
    guardar_lectura(db, other_plant, soil_humidity=0, temperature=45)
    plant_id = other_plant.id if objetivo == "ajena" else 9999
    response = auth_client.get(f"/api/sensors/latest/{plant_id}")
    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"
    assert "health_status" not in response.json()


def test_latest_sin_token_devuelve_401(anonymous_client, plant):
    response = anonymous_client.get(f"/api/sensors/latest/{plant.id}")
    assert response.status_code == 401


# --- CA-7: en vivo, la misma regla ---

@pytest.mark.parametrize("soil, temperature, status, score", TABLA_CA1)
def test_clima_actual_en_linea_da_la_misma_salud_que_latest(
    auth_client, db, echeveria, monkeypatch, soil, temperature, status, score
):
    guardar_lectura(db, echeveria, soil_humidity=soil, temperature=temperature)
    desde_la_base = pedir_latest(auth_client, echeveria)

    lectura_en_vivo(monkeypatch, soil, temperature)
    response = auth_client.get("/api/hardware/clima-actual")
    assert response.status_code == 200
    en_vivo = response.json()

    assert en_vivo["plant_id"] == echeveria.id
    assert en_vivo["health_status"] == status
    assert en_vivo["health_score"] == score
    assert (en_vivo["health_status"], en_vivo["health_score"]) == (
        desde_la_base["health_status"], desde_la_base["health_score"],
    )


def test_clima_actual_en_linea_usa_los_umbrales_de_la_planta(auth_client, db, echeveria, monkeypatch):
    echeveria.min_humidity = 60
    db.commit()
    lectura_en_vivo(monkeypatch, 50, 28)
    body = auth_client.get("/api/hardware/clima-actual").json()
    assert (body["health_status"], body["health_score"]) == ("Necesita agua", 80.0)


def test_clima_actual_en_linea_sin_suelo_devuelve_sin_datos(auth_client, echeveria, monkeypatch):
    lectura_en_vivo(monkeypatch, None, 28)
    body = auth_client.get("/api/hardware/clima-actual").json()
    assert body["health_status"] == "Sin datos"
    assert body["health_score"] is None


# --- CA-8: en vivo sin datos válidos ---

def test_clima_actual_desconectado_no_devuelve_salud(auth_client, echeveria, monkeypatch):
    # Con el ESP8266 desconectado, 0 % de suelo sería "Necesita agua" si se calculara
    lectura_en_vivo(monkeypatch, 0, 25, conexion="Desconectado")
    body = auth_client.get("/api/hardware/clima-actual").json()
    assert "health_status" in body and "health_score" in body
    assert body["health_status"] is None
    assert body["health_score"] is None


def test_clima_actual_con_planta_del_esp8266_de_otro_usuario_no_devuelve_salud(
    auth_client, db, echeveria, other_plant, monkeypatch
):
    # Umbrales de la planta ajena que darían otro resultado si se usaran
    other_plant.min_humidity = 90
    db.commit()
    monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", other_plant.id)
    lectura_en_vivo(monkeypatch, 20, 28)

    body = auth_client.get("/api/hardware/clima-actual").json()

    assert "health_status" in body and "health_score" in body
    assert body["health_status"] is None
    assert body["health_score"] is None


def test_clima_actual_sin_planta_del_esp8266_no_devuelve_salud(auth_client, echeveria, monkeypatch):
    monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", 9999)
    lectura_en_vivo(monkeypatch, 20, 28)
    body = auth_client.get("/api/hardware/clima-actual").json()
    assert "health_status" in body and "health_score" in body
    assert body["health_status"] is None
    assert body["health_score"] is None
