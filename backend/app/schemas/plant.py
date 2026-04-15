# ============================================================
# Solar-Grow - Schemas de Planta
# ============================================================
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class PlantCreate(BaseModel):
    """Schema para crear una planta."""
    common_name: str
    scientific_name: Optional[str] = None
    plant_type: Optional[str] = None
    image_url: Optional[str] = None
    location: str = "Jardin"
    care_difficulty: str = "Fácil"
    watering_frequency: str = "Cada 2 semanas"
    sun_exposure: str = "Parcial"
    soil_type: Optional[str] = None
    soil_ph_min: Optional[float] = None
    soil_ph_max: Optional[float] = None
    max_size: Optional[str] = None
    toxicity: str = "No Tóxica"
    hardiness_zones: Optional[str] = None
    description: Optional[str] = None
    min_humidity: float = 30.0
    max_temperature: float = 35.0
    min_light: float = 20.0


class PlantUpdate(BaseModel):
    """Schema para actualizar una planta."""
    common_name: Optional[str] = None
    location: Optional[str] = None
    min_humidity: Optional[float] = None
    max_temperature: Optional[float] = None
    min_light: Optional[float] = None
    last_fertilized: Optional[datetime] = None
    next_fertilize_date: Optional[datetime] = None


class PlantResponse(BaseModel):
    """Schema de respuesta básica de planta (para listas)."""
    id: int
    common_name: str
    scientific_name: Optional[str] = None
    plant_type: Optional[str] = None
    image_url: Optional[str] = None
    location: Optional[str] = None
    is_active: bool

    class Config:
        from_attributes = True


class PlantDetailResponse(BaseModel):
    """Schema de respuesta detallada de planta."""
    id: int
    common_name: str
    scientific_name: Optional[str] = None
    plant_type: Optional[str] = None
    image_url: Optional[str] = None
    location: Optional[str] = None
    care_difficulty: Optional[str] = None
    watering_frequency: Optional[str] = None
    sun_exposure: Optional[str] = None
    soil_type: Optional[str] = None
    soil_ph_min: Optional[float] = None
    soil_ph_max: Optional[float] = None
    max_size: Optional[str] = None
    toxicity: Optional[str] = None
    hardiness_zones: Optional[str] = None
    description: Optional[str] = None
    min_humidity: float
    max_temperature: float
    min_light: float
    last_fertilized: Optional[datetime] = None
    next_fertilize_date: Optional[datetime] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True
