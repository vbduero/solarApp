# ============================================================
# Solar-Grow - Pruebas de GET /api/hardware/diagnostico-ia (spec 002, CA-6 a CA-8)
# ============================================================
# Sin webcam, Gemini, ESP8266 ni red: todo se sustituye con monkeypatch y
# la prueba corre en una carpeta temporal para no escribir en static/.
# ============================================================
import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.config import get_settings
from app.database import get_db
from app.models.recommendation import AIDiagnosis
from app.routers import ai, hardware
from app.utils.auth import get_current_user

diag_app = FastAPI()
diag_app.include_router(hardware.router)
diag_app.include_router(ai.router)

JPEG = b"\xff\xd8jpeg"
GEMINI_TEXT = "ESTADO GENERAL: Saludable\nPLAGAS DETECTADAS: Ninguna detectada"
READING = {
    "status_conexion": "En línea",
    "temperatura": 24.5,
    "humedad_aire": 60.0,
    "humedad_suelo": 45.0,
    "humedad_suelo_raw": 580,
    "led_encendido": False,
}


class FakeResponse:
    def __init__(self, text):
        self.text = text


def make_fake_client(behavior):
    """behavior: texto (éxito) o excepción a lanzar."""

    class FakeModels:
        def generate_content(self, model, contents):
            if isinstance(behavior, Exception):
                raise behavior
            return FakeResponse(behavior)

    class FakeClient:
        def __init__(self, api_key=None):
            self.models = FakeModels()

    return FakeClient


@pytest.fixture
def client(db, user, tmp_path, monkeypatch):
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(hardware, "capturar_foto_webcam", lambda: JPEG)
    monkeypatch.setattr(hardware, "obtener_datos_actuales", lambda: READING)
    monkeypatch.setattr("time.sleep", lambda seconds: None)
    settings = get_settings()
    monkeypatch.setattr(settings, "GEMINI_API_KEY", "clave-de-prueba")
    monkeypatch.setattr(settings, "ESP8266_PLANT_ID", None)
    monkeypatch.setattr(hardware.genai, "Client", make_fake_client(GEMINI_TEXT))
    diag_app.dependency_overrides[get_db] = lambda: db
    diag_app.dependency_overrides[get_current_user] = lambda: user
    yield TestClient(diag_app)
    diag_app.dependency_overrides.clear()


# --- CA-6 ---

def test_diagnostico_exitoso_se_guarda_con_su_foto_y_sale_primero_en_el_listado(
    client, db, plant, tmp_path, monkeypatch
):
    monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", plant.id)

    response = client.get("/api/hardware/diagnostico-ia")

    assert response.status_code == 200
    body = response.json()
    assert body["diagnostico"] == GEMINI_TEXT
    assert body["diagnosis_id"] is not None
    assert body["plant_id"] == plant.id

    listing = client.get(f"/api/ai/diagnosis/{plant.id}").json()
    assert listing[0]["id"] == body["diagnosis_id"]
    assert listing[0]["image_url"].startswith("/static/diagnosticos/")
    assert (tmp_path / listing[0]["image_url"].lstrip("/")).read_bytes() == JPEG


# --- CA-7 ---

def test_si_falla_la_webcam_responde_500_y_no_guarda(client, db, plant, monkeypatch):
    def broken_webcam():
        raise RuntimeError("sin cámara")

    monkeypatch.setattr(hardware, "capturar_foto_webcam", broken_webcam)

    response = client.get("/api/hardware/diagnostico-ia")

    assert response.status_code == 500
    assert "cámara" in response.json()["detail"]
    assert db.query(AIDiagnosis).count() == 0


def test_si_gemini_falla_responde_500_y_no_guarda(client, db, plant, monkeypatch):
    monkeypatch.setattr(hardware.genai, "Client", make_fake_client(Exception("boom")))

    response = client.get("/api/hardware/diagnostico-ia")

    assert response.status_code == 500
    assert "Inteligencia Artificial" in response.json()["detail"]
    assert db.query(AIDiagnosis).count() == 0


def test_si_todos_los_modelos_estan_ocupados_responde_429_y_no_guarda(
    client, db, plant, monkeypatch
):
    monkeypatch.setattr(
        hardware.genai, "Client", make_fake_client(Exception("429 RESOURCE_EXHAUSTED"))
    )

    response = client.get("/api/hardware/diagnostico-ia")

    assert response.status_code == 429
    assert "ocupados" in response.json()["detail"]
    assert db.query(AIDiagnosis).count() == 0


def test_sin_api_key_de_gemini_responde_500_y_no_guarda(client, db, plant, monkeypatch):
    monkeypatch.setattr(get_settings(), "GEMINI_API_KEY", None)

    response = client.get("/api/hardware/diagnostico-ia")

    assert response.status_code == 500
    assert "GEMINI_API_KEY" in response.json()["detail"]
    assert db.query(AIDiagnosis).count() == 0


# --- CA-8 ---

def test_si_la_planta_del_esp8266_es_de_otro_usuario_devuelve_el_diagnostico_sin_guardarlo(
    client, db, user, other_plant, tmp_path, monkeypatch
):
    monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", other_plant.id)

    response = client.get("/api/hardware/diagnostico-ia")

    assert response.status_code == 200
    body = response.json()
    assert body["diagnostico"] == GEMINI_TEXT
    assert body["diagnosis_id"] is None
    assert body["plant_id"] is None
    assert db.query(AIDiagnosis).count() == 0
    assert not (tmp_path / "static" / "diagnosticos").exists()


def test_sin_planta_configurada_y_la_mas_antigua_de_otro_usuario_devuelve_el_diagnostico_sin_guardarlo(
    client, db, user, other_plant, plant, tmp_path
):
    # other_plant se crea antes que plant, así que es la planta activa más antigua
    assert other_plant.id < plant.id

    response = client.get("/api/hardware/diagnostico-ia")

    assert response.status_code == 200
    body = response.json()
    assert body["diagnostico"] == GEMINI_TEXT
    assert body["diagnosis_id"] is None
    assert body["plant_id"] is None
    assert db.query(AIDiagnosis).count() == 0
    assert not (tmp_path / "static" / "diagnosticos").exists()


def test_sin_ninguna_planta_de_dispositivo_devuelve_el_diagnostico_sin_guardar_nada(
    client, db, user, tmp_path
):
    response = client.get("/api/hardware/diagnostico-ia")

    assert response.status_code == 200
    body = response.json()
    assert body["diagnostico"] == GEMINI_TEXT
    assert body["diagnosis_id"] is None
    assert body["plant_id"] is None
    assert db.query(AIDiagnosis).count() == 0
    assert not (tmp_path / "static" / "diagnosticos").exists()


# --- CA-6 (con un diagnóstico anterior ya guardado) ---

def test_el_diagnostico_nuevo_sale_primero_aunque_ya_haya_uno_anterior(
    client, db, plant, monkeypatch
):
    from datetime import datetime, timedelta, timezone

    from app.models.recommendation import HealthStatus

    monkeypatch.setattr(get_settings(), "ESP8266_PLANT_ID", plant.id)
    anterior = AIDiagnosis(
        plant_id=plant.id,
        health_status=HealthStatus.REGULAR,
        diagnosis="diagnóstico anterior",
        created_at=datetime.now(timezone.utc) - timedelta(days=1),
    )
    db.add(anterior)
    db.commit()
    db.refresh(anterior)

    response = client.get("/api/hardware/diagnostico-ia")

    assert response.status_code == 200
    nuevo_id = response.json()["diagnosis_id"]
    assert nuevo_id is not None and nuevo_id != anterior.id

    listing = client.get(f"/api/ai/diagnosis/{plant.id}").json()
    assert [item["id"] for item in listing] == [nuevo_id, anterior.id]
