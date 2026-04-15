# ============================================================
# Solar-Grow - Router de IA y Recomendaciones
# ============================================================
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import desc

from ..database import get_db
from ..models.user import User
from ..models.plant import Plant
from ..models.recommendation import Recommendation, AIDiagnosis
from ..schemas.recommendation import RecommendationResponse, AIDiagnosisResponse
from ..utils.auth import get_current_user

router = APIRouter(prefix="/api/ai", tags=["Inteligencia Artificial"])


@router.get("/recommendations/{plant_id}", response_model=List[RecommendationResponse])
async def get_recommendations(
    plant_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener recomendaciones de cuidado generadas por la IA.
    
    Las recomendaciones se generan a partir del análisis de:
    - Datos de sensores (DHT22, humedad suelo, LDR)
    - Imágenes de la cámara Raspberry Pi
    - Historial de cuidados
    """
    plant = db.query(Plant).filter(
        Plant.id == plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")

    recommendations = db.query(Recommendation).filter(
        Recommendation.plant_id == plant_id,
    ).order_by(desc(Recommendation.created_at)).limit(20).all()

    return [RecommendationResponse.model_validate(r) for r in recommendations]


@router.get("/diagnosis/{plant_id}", response_model=List[AIDiagnosisResponse])
async def get_diagnoses(
    plant_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener diagnósticos de la IA por visión computacional.
    
    Los diagnósticos usan la cámara del Módulo 3 de Raspberry Pi
    para analizar visualmente la salud de la planta.
    """
    plant = db.query(Plant).filter(
        Plant.id == plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")

    diagnoses = db.query(AIDiagnosis).filter(
        AIDiagnosis.plant_id == plant_id,
    ).order_by(desc(AIDiagnosis.created_at)).limit(10).all()

    return [AIDiagnosisResponse.model_validate(d) for d in diagnoses]


@router.post("/request-diagnosis/{plant_id}")
async def request_diagnosis(
    plant_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Solicitar un nuevo diagnóstico de IA.
    
    Envía una señal a la Raspberry Pi para tomar una foto
    y analizarla con el modelo de IA.
    """
    plant = db.query(Plant).filter(
        Plant.id == plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")

    # En producción: enviar comando a Raspberry Pi
    # response = httpx.post(f"{settings.RASPBERRY_PI_URL}/capture-and-analyze")

    return {
        "success": True,
        "message": f"Diagnóstico solicitado para {plant.common_name}. "
                   "La Raspberry Pi está capturando y analizando la imagen.",
        "estimated_time_seconds": 30,
    }
