# ============================================================
# Solar-Grow Backend - Punto de Entrada Principal
# ============================================================
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .config import get_settings
from .database import engine, Base
from .routers import auth, plants, sensors, tasks, controls, ai, hardware

# Importar modelos para que se registren con Base.metadata
from .models import User, Plant, PlantLocation, SensorData, Task, Recommendation, AIDiagnosis  # noqa

settings = get_settings()

# Crear tablas en la base de datos
Base.metadata.create_all(bind=engine)

# Instancia de la aplicación FastAPI
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description=(
        "🌱 API de Solar-Grow - Estación ambiental inteligente "
        "con energía solar e inteligencia artificial"
    ),
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configuración de CORS para la app Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # En producción, limitar a la app
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Servir archivos estáticos (imágenes subidas)
import os
os.makedirs("static/images", exist_ok=True)
app.mount("/static", StaticFiles(directory="static"), name="static")

# Registrar routers
app.include_router(auth.router)
app.include_router(plants.router)
app.include_router(sensors.router)
app.include_router(tasks.router)
app.include_router(controls.router)
app.include_router(ai.router)
app.include_router(hardware.router)


@app.get("/", tags=["Root"])
def root():
    """Endpoint raíz - Información del API."""
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "description": "Estación ambiental inteligente con energía solar e IA",
        "docs": "/docs",
        "hardware": {
            "controller": "Raspberry Pi 4 (4GB)",
            "camera": "Cámara Módulo 3 Raspberry",
            "microcontroller": "ESP32",
            "sensors": ["DHT22", "Humedad suelo capacitivo", "LDR"],
            "actuators": ["Bomba de agua 5V", "Servomotores tracking solar"],
            "power": "Panel solar 20W + Batería recargable",
        },
    }


@app.get("/health", tags=["Root"])
def health_check():
    """Verificación de salud del servidor."""
    return {"status": "ok", "service": "solar-grow-api"}
