# ============================================================
# Solar-Grow - Schemas de Recomendaciones e IA
# ============================================================
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class RecommendationResponse(BaseModel):
    """Schema de respuesta de recomendaciones."""
    id: int
    plant_id: int
    title: str
    message: str
    category: Optional[str] = None
    priority: str
    is_read: int
    created_at: datetime

    class Config:
        from_attributes = True


class AIDiagnosisResponse(BaseModel):
    """Schema de respuesta de diagnóstico de IA."""
    id: int
    plant_id: int
    health_status: str
    confidence: Optional[float] = None
    diagnosis: Optional[str] = None
    image_url: Optional[str] = None
    detected_issues: Optional[str] = None
    suggested_actions: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True


class WaterControlRequest(BaseModel):
    """Schema para solicitar riego remoto."""
    plant_id: int
    duration_seconds: int = 10  # Duración del riego en segundos


class WaterControlResponse(BaseModel):
    """Schema de respuesta de control de riego."""
    success: bool
    message: str
    plant_id: int
    duration_seconds: int
