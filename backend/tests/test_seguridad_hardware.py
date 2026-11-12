# ============================================================
# Solar-Grow - Pruebas de seguridad: hardware, sensores, riego y subidas
# ============================================================
# No se usa hardware real: el envío serial y la lectura del ESP8266
# se reemplazan con monkeypatch.
# ============================================================
import io
import os

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.config import get_settings
from app.database import get_db
from app.models.sensor_data import SensorData
from app.routers import auth, controls, hardware, plants, sensors
from app.services import upload_service
from app.utils.auth import get_current_user

secure_app = FastAPI()
for module in (auth, controls, hardware, plants, sensors):
    secure_app.include_router(module.router)

JPEG_BYTES = b"\xff\xd8\xff\xe0" + b"0" * 32
PNG_BYTES = b"\x89PNG\r\n\x1a\n" + b"0" * 32
WEBP_BYTES = b"RIFF\x00\x00\x00\x00WEBP" + b"0" * 32


@pytest.fixture(autouse=True)
def esp8266_plant_sin_configurar(monkeypatch):
    """Spec 003 (D8): fija ESP8266_PLANT_ID en None para no depender del .env local.

    Así la planta del ESP8266 es siempre la activa más antigua (`plant`).
    """
    monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", None)


@pytest.fixture
def anonymous_client(db):
    """Cliente sin token: get_current_user NO se sobreescribe."""
    secure_app.dependency_overrides[get_db] = lambda: db
    yield TestClient(secure_app)
    secure_app.dependency_overrides.clear()


@pytest.fixture
def auth_client(db, user):
    secure_app.dependency_overrides[get_db] = lambda: db
    secure_app.dependency_overrides[get_current_user] = lambda: user
    yield TestClient(secure_app)
    secure_app.dependency_overrides.clear()


@pytest.fixture
def serial_commands(monkeypatch):
    """Simula un ESP8266 conectado y registra los comandos enviados."""
    sent = []

    def fake_send(command):
        sent.append(command)
        return True

    monkeypatch.setattr(controls, "enviar_comando_serial", fake_send)
    return sent


@pytest.fixture
def device_key(monkeypatch):
    monkeypatch.setattr(get_settings(), "DEVICE_API_KEY", "clave-de-prueba")
    return "clave-de-prueba"


@pytest.fixture
def upload_dir(tmp_path, monkeypatch):
    """Ejecuta la prueba en una carpeta temporal para no escribir en static/."""
    monkeypatch.chdir(tmp_path)
    return tmp_path


# --- /api/hardware/* exige sesión ---

@pytest.mark.parametrize("path", ["clima-actual", "vista-cultivo", "diagnostico-ia"])
def test_hardware_sin_token_devuelve_401(anonymous_client, path):
    response = anonymous_client.get(f"/api/hardware/{path}")
    assert response.status_code == 401


def test_clima_actual_con_sesion_devuelve_lectura(auth_client, plant, monkeypatch):
    reading = {
        "status_conexion": "En línea",
        "temperatura": 24.5,
        "humedad_aire": 60.0,
        "humedad_suelo": 45.0,
        "humedad_suelo_raw": 580,
        "led_encendido": False,
    }
    monkeypatch.setattr(hardware, "obtener_datos_actuales", lambda: reading)
    monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", None)

    response = auth_client.get("/api/hardware/clima-actual")

    assert response.status_code == 200
    assert response.json()["plant_id"] == plant.id
    assert response.json()["humedad_suelo"] == 45.0


# --- POST /api/sensors/ exige la clave del dispositivo ---

def test_sensores_sin_clave_configurada_queda_deshabilitado(anonymous_client, plant, monkeypatch):
    monkeypatch.setattr(get_settings(), "DEVICE_API_KEY", None)
    response = anonymous_client.post(
        "/api/sensors/", json={"plant_id": plant.id}, headers={"X-Device-Key": "cualquiera"}
    )
    assert response.status_code == 503


def test_sensores_sin_cabecera_devuelve_401(anonymous_client, plant, device_key):
    response = anonymous_client.post("/api/sensors/", json={"plant_id": plant.id})
    assert response.status_code == 401


def test_sensores_con_clave_incorrecta_devuelve_401(anonymous_client, db, plant, device_key):
    response = anonymous_client.post(
        "/api/sensors/", json={"plant_id": plant.id}, headers={"X-Device-Key": "otra"}
    )
    assert response.status_code == 401
    assert db.query(SensorData).count() == 0


def test_sensores_con_clave_correcta_guarda_la_lectura(anonymous_client, db, plant, device_key):
    response = anonymous_client.post(
        "/api/sensors/",
        json={"plant_id": plant.id, "soil_humidity": 41.0},
        headers={"X-Device-Key": device_key},
    )
    assert response.status_code == 200
    assert db.query(SensorData).filter(SensorData.plant_id == plant.id).count() == 1


# --- Riego: límite de duración ---

@pytest.mark.parametrize("seconds", [0, -5, 61, 3600])
def test_riego_rechaza_duracion_fuera_de_rango(auth_client, plant, serial_commands, seconds):
    response = auth_client.post(
        "/api/controls/water", json={"plant_id": plant.id, "duration_seconds": seconds}
    )
    assert response.status_code == 422
    assert serial_commands == []


@pytest.mark.parametrize("seconds", [1, 60])
def test_riego_acepta_los_limites(auth_client, plant, serial_commands, seconds):
    response = auth_client.post(
        "/api/controls/water", json={"plant_id": plant.id, "duration_seconds": seconds}
    )
    assert response.status_code == 200
    assert serial_commands == [f"WATER:{seconds}"]


# --- Riego: detener ---

def test_stop_water_envia_stop_al_esp8266(auth_client, plant, serial_commands):
    response = auth_client.post("/api/controls/stop-water", json={"plant_id": plant.id})
    assert response.status_code == 200
    assert response.json()["success"] is True
    assert serial_commands == ["STOP"]


def test_stop_water_sin_esp8266_devuelve_503(auth_client, plant, monkeypatch):
    monkeypatch.setattr(controls, "enviar_comando_serial", lambda command: False)
    response = auth_client.post("/api/controls/stop-water", json={"plant_id": plant.id})
    assert response.status_code == 503


def test_stop_water_de_planta_ajena_devuelve_404(auth_client, other_plant, serial_commands):
    response = auth_client.post("/api/controls/stop-water", json={"plant_id": other_plant.id})
    assert response.status_code == 404
    assert serial_commands == []


# --- Subida de imágenes ---

@pytest.mark.parametrize(
    "content, expected",
    [
        pytest.param(JPEG_BYTES, "jpg", id="jpeg"),
        pytest.param(PNG_BYTES, "png", id="png"),
        pytest.param(WEBP_BYTES, "webp", id="webp"),
        pytest.param(b"<html><script>alert(1)</script></html>", None, id="html"),
        pytest.param(b"MZ\x90\x00", None, id="ejecutable"),
        pytest.param(b"", None, id="vacio"),
    ],
)
def test_detect_image_extension(content, expected):
    assert upload_service.detect_image_extension(content) == expected


def test_subir_imagen_valida_usa_la_extension_real(auth_client, upload_dir):
    # El nombre dice .html, pero el contenido es PNG: se guarda como .png
    response = auth_client.post(
        "/api/plants/upload-image",
        files={"file": ("foto.html", io.BytesIO(PNG_BYTES), "text/html")},
    )
    assert response.status_code == 200
    image_url = response.json()["image_url"]
    assert image_url.startswith("/static/images/plant_")
    assert image_url.endswith(".png")
    assert os.path.isfile(upload_dir / image_url.lstrip("/"))


def test_subir_archivo_que_no_es_imagen_devuelve_400(auth_client, upload_dir):
    response = auth_client.post(
        "/api/plants/upload-image",
        files={"file": ("foto.jpg", io.BytesIO(b"<script>alert(1)</script>"), "image/jpeg")},
    )
    assert response.status_code == 400
    assert not (upload_dir / "static").exists()


def test_subir_archivo_vacio_devuelve_400(auth_client, upload_dir):
    response = auth_client.post(
        "/api/plants/upload-image",
        files={"file": ("foto.jpg", io.BytesIO(b""), "image/jpeg")},
    )
    assert response.status_code == 400


def test_subir_imagen_demasiado_grande_devuelve_413(auth_client, upload_dir, monkeypatch):
    monkeypatch.setattr(upload_service, "MAX_IMAGE_BYTES", 16)
    response = auth_client.post(
        "/api/plants/upload-image",
        files={"file": ("foto.jpg", io.BytesIO(JPEG_BYTES), "image/jpeg")},
    )
    assert response.status_code == 413
    assert not (upload_dir / "static").exists()


def test_subir_avatar_valida_el_formato(auth_client, upload_dir):
    rejected = auth_client.post(
        "/api/auth/upload-avatar",
        files={"file": ("avatar.png", io.BytesIO(b"no es una imagen"), "image/png")},
    )
    accepted = auth_client.post(
        "/api/auth/upload-avatar",
        files={"file": ("avatar.png", io.BytesIO(JPEG_BYTES), "image/png")},
    )
    assert rejected.status_code == 400
    assert accepted.status_code == 200
    assert accepted.json()["avatar_url"].endswith(".jpg")
