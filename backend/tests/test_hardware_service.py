# ============================================================
# Solar-Grow - Pruebas del servicio de hardware
# ============================================================
import os

import pytest

from app.models.plant import Plant, PlantLocation
from app.models.recommendation import AIDiagnosis, HealthStatus
from app.services.hardware_service import (
    get_device_plant,
    parse_health_status,
    save_diagnosis,
)


def add_plant(db, owner, name="Aloe", is_active=True):
    new_plant = Plant(
        user_id=owner.id,
        common_name=name,
        location=PlantLocation.SALA,
        is_active=is_active,
    )
    db.add(new_plant)
    db.commit()
    db.refresh(new_plant)
    return new_plant


# --- get_device_plant ---

def test_sin_plantas_devuelve_none(db):
    assert get_device_plant(db) is None


def test_sin_id_configurado_usa_la_planta_activa_mas_antigua(db, user, plant):
    add_plant(db, user, "Segunda")
    assert get_device_plant(db).id == plant.id


def test_sin_id_configurado_ignora_plantas_inactivas(db, user):
    add_plant(db, user, "Borrada", is_active=False)
    active = add_plant(db, user, "Activa")
    assert get_device_plant(db).id == active.id


def test_con_id_configurado_usa_esa_planta(db, user, plant):
    second = add_plant(db, user, "Segunda")
    assert get_device_plant(db, second.id).id == second.id


def test_id_configurado_inexistente_no_cae_en_otra_planta(db, plant):
    assert get_device_plant(db, plant.id + 999) is None


def test_id_configurado_de_planta_inactiva_devuelve_none(db, user, plant):
    deleted = add_plant(db, user, "Borrada", is_active=False)
    assert get_device_plant(db, deleted.id) is None


# --- parse_health_status ---

@pytest.mark.parametrize(
    "text, expected",
    [
        pytest.param("ESTADO GENERAL: Saludable\nPLAGAS DETECTADAS: Ninguna", HealthStatus.BUENA, id="saludable"),
        pytest.param("ESTADO GENERAL: Estrés leve por falta de riego", HealthStatus.REGULAR, id="estres-leve"),
        pytest.param("ESTADO GENERAL: Estrés moderado", HealthStatus.MALA, id="estres-moderado"),
        pytest.param("ESTADO GENERAL: Crítico, hojas secas", HealthStatus.CRITICA, id="critico-con-tilde"),
        pytest.param("**ESTADO GENERAL:** critico", HealthStatus.CRITICA, id="markdown-y-sin-tilde"),
        pytest.param(
            "ESTADO GENERAL: Saludable. No hay señales de estado crítico.",
            HealthStatus.BUENA,
            id="gana-la-primera-palabra-clave",
        ),
        pytest.param(
            "ESTADO GENERAL: Saludable\nPLAGAS DETECTADAS: infestación crítica",
            HealthStatus.BUENA,
            id="ignora-otras-secciones",
        ),
        pytest.param("La imagen no muestra una planta.", HealthStatus.REGULAR, id="sin-encabezado"),
        pytest.param("ESTADO GENERAL: no se puede determinar", HealthStatus.REGULAR, id="sin-palabra-clave"),
        pytest.param("", HealthStatus.REGULAR, id="vacio"),
    ],
)
def test_parse_health_status(text, expected):
    assert parse_health_status(text) == expected


# --- save_diagnosis ---

def test_save_diagnosis_guarda_fila_e_imagen(db, plant, tmp_path):
    images_dir = str(tmp_path / "diagnosticos")
    text = "ESTADO GENERAL: Estrés moderado\nRECOMENDACIONES: regar"

    saved = save_diagnosis(db, plant, text, b"jpeg-bytes", images_dir=images_dir)

    stored = db.query(AIDiagnosis).filter(AIDiagnosis.id == saved.id).one()
    assert stored.plant_id == plant.id
    assert stored.health_status == HealthStatus.MALA
    assert stored.diagnosis == text

    filename = os.path.basename(stored.image_url)
    with open(os.path.join(images_dir, filename), "rb") as image_file:
        assert image_file.read() == b"jpeg-bytes"


def test_save_diagnosis_cada_diagnostico_conserva_su_imagen(db, plant, tmp_path):
    images_dir = str(tmp_path / "diagnosticos")

    first = save_diagnosis(db, plant, "ESTADO GENERAL: Saludable", b"uno", images_dir=images_dir)
    second = save_diagnosis(db, plant, "ESTADO GENERAL: Crítico", b"dos", images_dir=images_dir)

    assert first.image_url != second.image_url
    assert len(os.listdir(images_dir)) == 2


def test_save_diagnosis_sin_imagen(db, plant):
    saved = save_diagnosis(db, plant, "ESTADO GENERAL: Saludable")
    assert saved.image_url is None
    assert saved.health_status == HealthStatus.BUENA


# --- get_device_plant_for_user (spec 002, CA-8) ---
# La función se importa dentro de cada prueba: si aún no existe, solo fallan estas
# y no el resto del archivo.

def test_device_plant_for_user_devuelve_la_planta_si_es_del_usuario(db, user, plant):
    from app.services.hardware_service import get_device_plant_for_user

    assert get_device_plant_for_user(db, plant.id, user.id).id == plant.id


def test_device_plant_for_user_devuelve_none_si_es_de_otro_usuario(db, user, other_plant):
    from app.services.hardware_service import get_device_plant_for_user

    assert get_device_plant_for_user(db, other_plant.id, user.id) is None


def test_device_plant_for_user_devuelve_none_sin_planta(db, user):
    from app.services.hardware_service import get_device_plant_for_user

    assert get_device_plant_for_user(db, None, user.id) is None
