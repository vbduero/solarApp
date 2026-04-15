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
from ..utils.auth import get_current_user
from ..config import get_settings

router = APIRouter(prefix="/api/controls", tags=["Control Remoto"])

settings = get_settings()


@router.post("/water", response_model=WaterControlResponse)
async def activate_watering(
    request: WaterControlRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Activar el riego remoto de una planta.
    
    Envía un comando MQTT al ESP32 para activar la bomba de agua
    durante la duración especificada.
    """
    # Verificar que la planta pertenece al usuario
    plant = db.query(Plant).filter(
        Plant.id == request.plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")

    # Construir comando MQTT
    command = {
        "action": "water",
        "plant_id": request.plant_id,
        "duration_seconds": request.duration_seconds,
        "user_id": current_user.id,
    }

    try:
        # Intentar enviar por MQTT
        # En producción, esto se conecta al broker MQTT
        # Por ahora, simulamos el envío exitoso
        # mqtt_client.publish(settings.MQTT_TOPIC_CONTROL, json.dumps(command))

        return WaterControlResponse(
            success=True,
            message=f"Riego activado para {plant.common_name} por {request.duration_seconds} segundos",
            plant_id=request.plant_id,
            duration_seconds=request.duration_seconds,
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al enviar comando de riego: {str(e)}",
        )


@router.post("/stop-water")
async def stop_watering(
    request: WaterControlRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Detener el riego de una planta."""
    plant = db.query(Plant).filter(
        Plant.id == request.plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")

    command = {
        "action": "stop_water",
        "plant_id": request.plant_id,
    }

    # mqtt_client.publish(settings.MQTT_TOPIC_CONTROL, json.dumps(command))

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
