# ============================================================
# Solar-Grow - Modelo de Planta
# ============================================================
import enum
from sqlalchemy import Column, Integer, String, Float, Boolean, DateTime, ForeignKey, Enum, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class PlantLocation(str, enum.Enum):
    """Ubicaciones posibles de la planta."""
    BALCON = "Balcon"
    DORMITORIO = "Dormitorio"
    SALA = "Sala"
    COCINA = "Cocina"
    JARDIN = "Jardin"
    TERRAZA = "Terraza"
    OTRO = "Otro"


class Plant(Base):
    """Modelo de planta monitoreada por el sistema Solar-Grow."""
    __tablename__ = "plants"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    # Información botánica
    common_name = Column(String(255), nullable=False)  # Ej: "Áloe de arena"
    scientific_name = Column(String(255), nullable=True)  # Ej: "Aloe vera"
    plant_type = Column(String(100), nullable=True)  # Ej: "Suculento"
    image_url = Column(String(500), nullable=True)

    # Ubicación
    location = Column(Enum(PlantLocation), default=PlantLocation.JARDIN)

    # Cuidados recomendados
    care_difficulty = Column(String(50), default="Fácil")  # Fácil, Medio, Difícil
    watering_frequency = Column(String(100), default="Cada 2 semanas")
    sun_exposure = Column(String(50), default="Parcial")  # Directo, Parcial, Sombra
    soil_type = Column(String(100), nullable=True)
    soil_ph_min = Column(Float, nullable=True)
    soil_ph_max = Column(Float, nullable=True)
    max_size = Column(String(50), nullable=True)  # Ej: "Hasta 20 in"
    toxicity = Column(String(100), default="No Tóxica")
    hardiness_zones = Column(String(50), nullable=True)  # Ej: "9 - 11"
    description = Column(Text, nullable=True)

    # Umbrales de sensores para determinar estado de salud
    min_humidity = Column(Float, default=30.0)  # % humedad suelo mínima
    max_temperature = Column(Float, default=35.0)  # °C máxima
    min_light = Column(Float, default=20.0)  # % luz mínima

    # Última fecha de fertilización
    last_fertilized = Column(DateTime(timezone=True), nullable=True)
    next_fertilize_date = Column(DateTime(timezone=True), nullable=True)

    # Estado
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())

    # Relaciones
    owner = relationship("User", back_populates="plants")
    sensor_data = relationship("SensorData", back_populates="plant", cascade="all, delete-orphan")
    tasks = relationship("Task", back_populates="plant", cascade="all, delete-orphan")
    recommendations = relationship("Recommendation", back_populates="plant", cascade="all, delete-orphan")
    diagnoses = relationship("AIDiagnosis", back_populates="plant", cascade="all, delete-orphan")
