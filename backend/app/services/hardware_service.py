# ============================================================
# Solar-Grow - Servicio de Hardware (planta del dispositivo y diagnósticos)
# ============================================================
# No importa serial, cv2 ni google.genai: así se puede probar sin hardware.
import os
import unicodedata
import uuid
from typing import Optional

from sqlalchemy.orm import Session

from ..models.plant import Plant
from ..models.recommendation import AIDiagnosis, HealthStatus

DIAGNOSIS_IMAGES_DIR = "static/diagnosticos"

# Palabras clave del "ESTADO GENERAL" que devuelve Gemini → estado guardado en BD
_STATUS_KEYWORDS = (
    ("critic", HealthStatus.CRITICA),
    ("moderado", HealthStatus.MALA),
    ("leve", HealthStatus.REGULAR),
    ("saludable", HealthStatus.BUENA),
)

# Estado que se guarda cuando la respuesta no trae un "ESTADO GENERAL" reconocible
DEFAULT_HEALTH_STATUS = HealthStatus.REGULAR


def get_device_plant(db: Session, configured_plant_id: Optional[int] = None) -> Optional[Plant]:
    """Devuelve la planta a la que está conectado el ESP8266.

    Si hay un id configurado (ESP8266_PLANT_ID) se usa solo esa planta: cuando no
    existe o está inactiva devuelve None en vez de escribir en otra planta.
    Sin id configurado se usa la planta activa más antigua.
    """
    query = db.query(Plant).filter(Plant.is_active == True)  # noqa: E712
    if configured_plant_id is not None:
        return query.filter(Plant.id == configured_plant_id).first()
    return query.order_by(Plant.id.asc()).first()


def get_device_plant_for_user(
    db: Session, configured_plant_id: Optional[int], user_id: int
) -> Optional[Plant]:
    """Devuelve la planta del ESP8266 solo si pertenece al usuario; si no, None."""
    plant = get_device_plant(db, configured_plant_id)
    if plant is None or plant.user_id != user_id:
        return None
    return plant


def _normalize(text: str) -> str:
    """Minúsculas y sin tildes, para comparar sin depender de la ortografía."""
    decomposed = unicodedata.normalize("NFD", text.lower())
    return "".join(char for char in decomposed if unicodedata.category(char) != "Mn")


def parse_health_status(diagnosis_text: str) -> HealthStatus:
    """Extrae el estado de salud de la sección "ESTADO GENERAL" del diagnóstico.

    Gemini responde Saludable / Estrés leve / Estrés moderado / Crítico. Se toma la
    palabra clave que aparece primero en esa sección.
    """
    text = _normalize(diagnosis_text or "")
    start = text.find("estado general")
    if start == -1:
        return DEFAULT_HEALTH_STATUS

    section = text[start:]
    end = section.find("plagas detectadas")
    if end != -1:
        section = section[:end]

    best_position, best_status = len(section), DEFAULT_HEALTH_STATUS
    for keyword, status in _STATUS_KEYWORDS:
        position = section.find(keyword)
        if position != -1 and position < best_position:
            best_position, best_status = position, status
    return best_status


def save_diagnosis(
    db: Session,
    plant: Plant,
    diagnosis_text: str,
    image_bytes: Optional[bytes] = None,
    images_dir: str = DIAGNOSIS_IMAGES_DIR,
) -> AIDiagnosis:
    """Guarda un diagnóstico de IA para la planta y hace commit.

    La imagen se guarda con nombre único para que cada diagnóstico conserve su foto.
    """
    image_url = None
    if image_bytes:
        os.makedirs(images_dir, exist_ok=True)
        filename = f"diag_{plant.id}_{uuid.uuid4().hex[:8]}.jpg"
        with open(os.path.join(images_dir, filename), "wb") as image_file:
            image_file.write(image_bytes)
        image_url = f"/{images_dir.strip('/')}/{filename}"

    diagnosis = AIDiagnosis(
        plant_id=plant.id,
        health_status=parse_health_status(diagnosis_text),
        diagnosis=diagnosis_text,
        image_url=image_url,
    )
    db.add(diagnosis)
    db.commit()
    db.refresh(diagnosis)
    return diagnosis
