# ============================================================
# Solar-Grow - Pruebas de los controles de riego (spec 003, CA-1 a CA-6)
# ============================================================
# Sin serial, ESP8266 ni red: el envío serial se reemplaza con monkeypatch.
# ============================================================
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.config import get_settings
from app.database import get_db
from app.models.plant import Plant, PlantLocation
from app.routers import controls
from app.utils import hardware_helper
from app.utils.auth import get_current_user

riego_app = FastAPI()
riego_app.include_router(controls.router)

STOP_503 = (
    "No se pudo detener el riego: el ESP8266 no está conectado "
    "al puerto serial del servidor."
)
SIN_ESP8266 = "Esta planta no tiene el ESP8266 conectado."


@pytest.fixture
def auth_client(db, user):
    riego_app.dependency_overrides[get_db] = lambda: db
    riego_app.dependency_overrides[get_current_user] = lambda: user
    yield TestClient(riego_app)
    riego_app.dependency_overrides.clear()


@pytest.fixture
def anonymous_client(db):
    riego_app.dependency_overrides[get_db] = lambda: db
    yield TestClient(riego_app)
    riego_app.dependency_overrides.clear()


@pytest.fixture
def serial_commands(monkeypatch):
    """ESP8266 conectado: registra los comandos enviados."""
    sent = []

    def fake_send(command):
        sent.append(command)
        return True

    monkeypatch.setattr(controls, "enviar_comando_serial", fake_send)
    return sent


@pytest.fixture
def sin_serial(monkeypatch):
    """ESP8266 desconectado: no se puede enviar; registra los intentos."""
    attempts = []

    def fake_send(command):
        attempts.append(command)
        return False

    monkeypatch.setattr(controls, "enviar_comando_serial", fake_send)
    return attempts


def configurar_esp8266(monkeypatch, plant_id):
    monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", plant_id)


def crear_segunda_planta(db, user):
    second = Plant(user_id=user.id, common_name="Otra", location=PlantLocation.BALCON)
    db.add(second)
    db.commit()
    db.refresh(second)
    return second


def detener(client, plant_id):
    return client.post("/api/controls/stop-water", json={"plant_id": plant_id})


def regar(client, plant_id, seconds=10):
    return client.post(
        "/api/controls/water", json={"plant_id": plant_id, "duration_seconds": seconds}
    )


# --- CA-1 a CA-3: detener en la planta del ESP8266 ---

def test_detener_en_la_planta_del_esp8266_envia_stop_una_vez(auth_client, plant, serial_commands, monkeypatch):
    configurar_esp8266(monkeypatch, plant.id)

    response = detener(auth_client, plant.id)

    assert response.status_code == 200
    body = response.json()
    assert body["success"] is True
    assert plant.common_name in body["message"]
    assert serial_commands == ["STOP"]


def test_detener_con_la_bomba_apagada_igual_envia_stop(auth_client, plant, serial_commands, monkeypatch):
    configurar_esp8266(monkeypatch, plant.id)
    monkeypatch.setitem(hardware_helper.LATEST_DATA, "led_encendido", False)
    monkeypatch.setitem(hardware_helper.LATEST_DATA, "status_conexion", "En línea")

    response = detener(auth_client, plant.id)

    assert response.status_code == 200
    assert serial_commands == ["STOP"]


def test_detener_sin_esp8266_devuelve_503_con_mensaje(auth_client, plant, sin_serial, monkeypatch):
    configurar_esp8266(monkeypatch, plant.id)

    response = detener(auth_client, plant.id)

    assert response.status_code == 503
    assert response.json()["detail"] == STOP_503


# --- CA-4: planta ajena, inexistente, borrada o sin sesión ---

def test_detener_planta_ajena_devuelve_404_sin_enviar(auth_client, plant, other_plant, serial_commands, monkeypatch):
    configurar_esp8266(monkeypatch, plant.id)

    response = detener(auth_client, other_plant.id)

    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"
    assert serial_commands == []


def test_detener_planta_inexistente_devuelve_404_sin_enviar(auth_client, plant, serial_commands, monkeypatch):
    configurar_esp8266(monkeypatch, plant.id)

    response = detener(auth_client, plant.id + 999)

    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"
    assert serial_commands == []


def test_detener_planta_borrada_devuelve_404_sin_enviar(auth_client, db, plant, serial_commands, monkeypatch):
    configurar_esp8266(monkeypatch, None)
    plant.is_active = False
    db.commit()

    response = detener(auth_client, plant.id)

    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"
    assert serial_commands == []


def test_detener_sin_token_devuelve_401(anonymous_client, plant, serial_commands, monkeypatch):
    configurar_esp8266(monkeypatch, plant.id)

    response = detener(anonymous_client, plant.id)

    assert response.status_code == 401
    assert serial_commands == []


# --- CA-5: planta sin ESP8266 ---

def test_detener_planta_propia_sin_esp8266_devuelve_409_sin_enviar(
    auth_client, db, user, plant, serial_commands, monkeypatch
):
    configurar_esp8266(monkeypatch, plant.id)
    second = crear_segunda_planta(db, user)

    response = detener(auth_client, second.id)

    assert response.status_code == 409
    assert response.json()["detail"] == SIN_ESP8266
    assert serial_commands == []


def test_detener_con_planta_configurada_inexistente_devuelve_409(auth_client, plant, serial_commands, monkeypatch):
    configurar_esp8266(monkeypatch, plant.id + 999)

    response = detener(auth_client, plant.id)

    assert response.status_code == 409
    assert response.json()["detail"] == SIN_ESP8266
    assert serial_commands == []


def test_detener_si_la_planta_del_esp8266_es_de_otro_usuario_devuelve_409(
    auth_client, plant, other_plant, serial_commands, monkeypatch
):
    configurar_esp8266(monkeypatch, other_plant.id)

    response = detener(auth_client, plant.id)

    assert response.status_code == 409
    assert response.json()["detail"] == SIN_ESP8266
    assert serial_commands == []


# --- CA-6: regar con las mismas reglas ---

def test_regar_planta_propia_sin_esp8266_devuelve_409_sin_enviar(
    auth_client, db, user, plant, serial_commands, monkeypatch
):
    configurar_esp8266(monkeypatch, plant.id)
    second = crear_segunda_planta(db, user)

    response = regar(auth_client, second.id)

    assert response.status_code == 409
    assert response.json()["detail"] == SIN_ESP8266
    assert serial_commands == []


def test_regar_planta_borrada_devuelve_404_sin_enviar(auth_client, db, plant, serial_commands, monkeypatch):
    configurar_esp8266(monkeypatch, None)
    plant.is_active = False
    db.commit()

    response = regar(auth_client, plant.id)

    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"
    assert serial_commands == []


@pytest.mark.parametrize("target", ["ajena", "inexistente"])
def test_regar_planta_ajena_o_inexistente_devuelve_404_sin_enviar(
    auth_client, plant, other_plant, serial_commands, monkeypatch, target
):
    configurar_esp8266(monkeypatch, plant.id)
    plant_id = other_plant.id if target == "ajena" else plant.id + 999

    response = regar(auth_client, plant_id)

    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"
    assert serial_commands == []


def test_regar_en_la_planta_del_esp8266_envia_water(auth_client, plant, serial_commands, monkeypatch):
    configurar_esp8266(monkeypatch, plant.id)

    response = regar(auth_client, plant.id, seconds=10)

    assert response.status_code == 200
    assert response.json()["success"] is True
    assert serial_commands == ["WATER:10"]


def test_regar_sin_esp8266_devuelve_503(auth_client, plant, sin_serial, monkeypatch):
    configurar_esp8266(monkeypatch, plant.id)

    response = regar(auth_client, plant.id)

    assert response.status_code == 503


def test_regar_sin_esp8266_devuelve_503_con_mensaje(auth_client, plant, sin_serial, monkeypatch):
    configurar_esp8266(monkeypatch, plant.id)

    response = regar(auth_client, plant.id)

    assert response.status_code == 503
    assert response.json()["detail"] == (
        "No se pudo activar el riego: el ESP8266 no está conectado "
        "al puerto serial del servidor."
    )
