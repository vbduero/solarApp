# ============================================================
# Solar-Grow - Router de Control (Riego Remoto)
# ============================================================
import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.user import User
from ..models.plant import Plant
from ..schemas.recommendation import WaterControlRequest, WaterControlResponse
from ..services.hardware_service import find_active_user_plant, is_device_plant
from ..utils.auth import get_current_user
from ..config import get_settings
from ..utils.hardware_helper import enviar_comando_serial

router = APIRouter(prefix="/api/controls", tags=["Control Remoto"])


def _get_controllable_plant(db: Session, plant_id: int, user: User) -> Plant:
    """Devuelve la planta si es del usuario, está activa y tiene el ESP8266 conectado.

    404 si no existe, es ajena o está borrada; 409 si no es la planta del ESP8266.
    """
    plant = find_active_user_plant(db, plant_id, user.id)
    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")
    if not is_device_plant(db, plant, get_settings().ESP8266_PLANT_ID):
        raise HTTPException(
            status_code=409, detail="Esta planta no tiene el ESP8266 conectado."
        )
    return plant


@router.post("/water", response_model=WaterControlResponse)
async def activate_watering(
    request: WaterControlRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Activar el riego remoto de una planta.
    
    Envía un comando por puerto serial (USB) al ESP8266 para activar la
    bomba de agua durante la duración especificada.
    """
    plant = _get_controllable_plant(db, request.plant_id, current_user)

    # Construir comando MQTT
    command = {
        "action": "water",
        "plant_id": request.plant_id,
        "duration_seconds": request.duration_seconds,
        "user_id": current_user.id,
    }

    # Enviar comando por puerto serial al ESP8266 NodeMCU
    try:
        enviado = enviar_comando_serial(f"WATER:{request.duration_seconds}")
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al enviar comando de riego: {str(e)}",
        )

    if not enviado:
        raise HTTPException(
            status_code=503,
            detail="No se pudo activar el riego: el ESP8266 no está conectado "
                   "al puerto serial del servidor.",
        )

    return WaterControlResponse(
        success=True,
        message=f"Riego activado para {plant.common_name} por {request.duration_seconds} segundos",
        plant_id=request.plant_id,
        duration_seconds=request.duration_seconds,
    )


@router.post("/stop-water")
async def stop_watering(
    request: WaterControlRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Detener el riego de una planta (siempre envía STOP)."""
    plant = _get_controllable_plant(db, request.plant_id, current_user)

    # Enviar el comando STOP por puerto serial al ESP8266 NodeMCU
    try:
        enviado = enviar_comando_serial("STOP")
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al enviar comando para detener el riego: {str(e)}",
        )

    if not enviado:
        raise HTTPException(
            status_code=503,
            detail="No se pudo detener el riego: el ESP8266 no está conectado "
                   "al puerto serial del servidor.",
        )

    return {"success": True, "message": f"Riego detenido para {plant.common_name}"}


@router.get("/status/{plant_id}")
async def get_control_status(
    plant_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener el estado actual de los controles de una planta.
    
    Incluye estado de la bomba, ángulo de los servos del tracker solar,
    y nivel de batería.
    """
    plant = db.query(Plant).filter(
        Plant.id == plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")

    # En producción, se consulta al ESP32 vía MQTT
    return {
        "plant_id": plant_id,
        "pump_active": False,
        "solar_tracker": {
            "angle_x": 0.0,
            "angle_y": 0.0,
            "tracking_active": True,
        },
        "battery": {
            "level": 85.0,
            "charging": True,
        },
    }
