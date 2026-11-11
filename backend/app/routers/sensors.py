# ============================================================
# Solar-Grow - Router de Sensores
# ============================================================
import secrets
from typing import List, Optional
from fastapi import APIRouter, Depends, Header, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc

from ..database import get_db
from ..models.user import User
from ..models.plant import Plant
from ..models.sensor_data import SensorData
from ..schemas.sensor_data import SensorDataCreate, SensorDataResponse, SensorLatestResponse
from ..utils.auth import get_current_user
from ..config import get_settings
from ..services import sensor_service

router = APIRouter(prefix="/api/sensors", tags=["Sensores"])


def calculate_health(plant: Plant, data: SensorData) -> dict:
    """Calcula el estado de salud de la planta basándose en los sensores.
    
    Retorna el estado y un puntaje de 0-100 para determinar
    si la planta animada se muestra feliz o triste.
    """
    score = 100.0
    status = "healthy"
    issues = []

    # Verificar humedad del suelo
    if data.soil_humidity is not None and data.soil_humidity < plant.min_humidity:
        deficit = plant.min_humidity - data.soil_humidity
        score -= min(deficit * 2, 40)
        issues.append("needs_water")

    # Verificar temperatura
    if data.temperature is not None and data.temperature > plant.max_temperature:
        excess = data.temperature - plant.max_temperature
        score -= min(excess * 3, 30)
        issues.append("too_hot")

    # Verificar luz
    if data.light_level is not None and data.light_level < plant.min_light:
        deficit = plant.min_light - data.light_level
        score -= min(deficit * 1.5, 30)
        issues.append("needs_light")

    # Determinar estado
    score = max(0, score)
    if score >= 70:
        status = "healthy"
    elif score >= 40:
        if "needs_water" in issues:
            status = "needs_water"
        elif "needs_light" in issues:
            status = "needs_light"
        else:
            status = "stressed"
    else:
        status = "critical"

    return {"health_status": status, "health_score": round(score, 1)}


@router.get("/latest/{plant_id}", response_model=SensorLatestResponse)
async def get_latest_sensors(
    plant_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener los datos más recientes de los sensores de una planta.
    
    Este endpoint es usado por la pantalla de detalle de planta
    para mostrar los valores actuales y el estado de la planta animada.
    """
    plant = db.query(Plant).filter(
        Plant.id == plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")

    latest = db.query(SensorData).filter(
        SensorData.plant_id == plant_id,
    ).order_by(desc(SensorData.recorded_at)).first()

    if not latest:
        return SensorLatestResponse(
            plant_id=plant_id,
            plant_name=plant.common_name,
            health_status="unknown",
            health_score=50.0,
        )

    health = calculate_health(plant, latest)

    return SensorLatestResponse(
        plant_id=plant_id,
        plant_name=plant.common_name,
        temperature=latest.temperature,
        air_humidity=latest.air_humidity,
        soil_humidity=latest.soil_humidity,
        light_level=latest.light_level,
        solar_voltage=latest.solar_voltage,
        battery_level=latest.battery_level,
        pump_active=latest.pump_active,
        health_status=health["health_status"],
        health_score=health["health_score"],
        recorded_at=latest.recorded_at,
    )


@router.get("/history/{plant_id}", response_model=List[SensorDataResponse])
async def get_sensor_history(
    plant_id: int,
    hours: int = Query(24, ge=1, le=720, description="Horas de historial"),
    limit: int = Query(100, ge=1, le=500, description="Máximo de registros"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener historial de datos de sensores para gráficas.
    
    Para la pantalla de Estadísticas del sistema.
    """
    plant = db.query(Plant).filter(
        Plant.id == plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")

    records = sensor_service.get_history(db, plant_id, hours, limit)

    return [SensorDataResponse.model_validate(r) for r in records]


def verify_device_key(x_device_key: Optional[str] = Header(default=None)) -> None:
    """Comprueba la clave del dispositivo (cabecera X-Device-Key).

    La clave se configura en DEVICE_API_KEY (backend/.env). Si no está
    configurada, el endpoint queda deshabilitado.
    """
    expected_key = get_settings().DEVICE_API_KEY
    if not expected_key:
        raise HTTPException(
            status_code=503,
            detail="Recepción de lecturas deshabilitada: falta configurar DEVICE_API_KEY",
        )
    if not x_device_key or not secrets.compare_digest(
        x_device_key.encode("utf-8"), expected_key.encode("utf-8")
    ):
        raise HTTPException(status_code=401, detail="Clave de dispositivo inválida")


@router.post("/", response_model=SensorDataResponse)
async def create_sensor_data(
    data: SensorDataCreate,
    db: Session = Depends(get_db),
    _: None = Depends(verify_device_key),
):
    """Recibir datos de sensores del ESP32 o Raspberry Pi.
    
    Este endpoint es llamado por el hardware del sistema
    para registrar nuevas lecturas de sensores.
    No requiere autenticación de usuario: usa la clave del dispositivo
    en la cabecera X-Device-Key.
    """
    # Verificar que la planta existe
    plant = db.query(Plant).filter(Plant.id == data.plant_id).first()
    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")

    new_record = SensorData(**data.model_dump())
    db.add(new_record)
    db.commit()
    db.refresh(new_record)

    return SensorDataResponse.model_validate(new_record)
