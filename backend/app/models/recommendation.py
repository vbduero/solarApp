# ============================================================
# Solar-Grow - Modelos de Recomendaciones e IA
# ============================================================
import enum
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class HealthStatus(str, enum.Enum):
    """Estado de salud de la planta según análisis de IA."""
    EXCELENTE = "Excelente"
    BUENA = "Buena"
    REGULAR = "Regular"
    MALA = "Mala"
    CRITICA = "Critica"


class Recommendation(Base):
    """Recomendaciones de cuidado generadas por el sistema de IA.
    
    Basadas en los datos de sensores y el análisis visual
    de la cámara de la Raspberry Pi.
    """
    __tablename__ = "recommendations"

    id = Column(Integer, primary_key=True, index=True)
    plant_id = Column(Integer, ForeignKey("plants.id"), nullable=False)

    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    category = Column(String(100), nullable=True)  # riego, luz, temperatura, fertilización
    priority = Column(String(50), default="media")  # alta, media, baja
    is_read = Column(Integer, default=0)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relación
    plant = relationship("Plant", back_populates="recommendations")


class AIDiagnosis(Base):
    """Diagnóstico generado por la IA usando la cámara de la Raspberry Pi.
    
    Almacena resultados del análisis por visión computacional
    de la salud de la planta.
    """
    __tablename__ = "ai_diagnoses"

    id = Column(Integer, primary_key=True, index=True)
    plant_id = Column(Integer, ForeignKey("plants.id"), nullable=False)

    # Resultado del análisis
    health_status = Column(Enum(HealthStatus), nullable=False)
    confidence = Column(Float, nullable=True)  # % confianza del modelo
    diagnosis = Column(Text, nullable=True)  # Descripción del diagnóstico
    image_url = Column(String(500), nullable=True)  # URL de la imagen analizada

    # Problemas detectados
    detected_issues = Column(Text, nullable=True)  # JSON con problemas encontrados
    suggested_actions = Column(Text, nullable=True)  # JSON con acciones sugeridas

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relación
    plant = relationship("Plant", back_populates="diagnoses")
