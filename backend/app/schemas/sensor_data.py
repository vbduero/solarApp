# ============================================================
# Solar-Grow - Schemas de Datos de Sensores
# ============================================================
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class SensorDataCreate(BaseModel):
    """Schema para crear registro de datos de sensores.
    
    Usado cuando el ESP32 o la Raspberry Pi envían datos.
    """
    plant_id: int
    temperature: Optional[float] = None
    air_humidity: Optional[float] = None
    soil_humidity: Optional[float] = None
    light_level: Optional[float] = None
    solar_voltage: Optional[float] = None
    solar_power: Optional[float] = None
    battery_level: Optional[float] = None
    servo_angle_x: Optional[float] = None
    servo_angle_y: Optional[float] = None
    pump_active: int = 0
    source: str = "esp32"


class SensorDataResponse(BaseModel):
    """Schema de respuesta individual de datos de sensores."""
    id: int
    plant_id: int
    temperature: Optional[float] = None
    air_humidity: Optional[float] = None
    soil_humidity: Optional[float] = None
    light_level: Optional[float] = None
    solar_voltage: Optional[float] = None
    solar_power: Optional[float] = None
    battery_level: Optional[float] = None
    servo_angle_x: Optional[float] = None
    servo_angle_y: Optional[float] = None
    pump_active: int
    source: str
    recorded_at: datetime

    class Config:
        from_attributes = True


class SensorLatestResponse(BaseModel):
    """Schema de respuesta de los datos más recientes de sensores.
    
    Incluye el estado de salud calculado de la planta.
    """
    plant_id: int
    plant_name: str
    temperature: Optional[float] = None
    air_humidity: Optional[float] = None
    soil_humidity: Optional[float] = None
    light_level: Optional[float] = None
    solar_voltage: Optional[float] = None
    battery_level: Optional[float] = None
    pump_active: int = 0
    
    # Estado de salud calculado
    health_status: str = "healthy"  # saludable, necesita_agua, necesita_luz, critico
    health_score: float = 100.0  # Puntaje de 0-100
    
    recorded_at: Optional[datetime] = None
