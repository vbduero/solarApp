# ============================================================
# Solar-Grow Backend - Configuración
# ============================================================
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    """Configuración principal de la aplicación Solar-Grow."""

    # --- Aplicación ---
    APP_NAME: str = "Solar-Grow API"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = True

    # --- Base de Datos PostgreSQL ---
    # Usa psycopg3 como driver (compatible con Python 3.13)
    DATABASE_URL: str = "postgresql+psycopg://postgres:123456@localhost:5432/solar_grow_db"

    # --- JWT ---
    SECRET_KEY: str = "solar-grow-secret-key-change-in-production-2024"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440  # 24 horas

    # --- MQTT (Comunicación con ESP32/Raspberry Pi) ---
    MQTT_BROKER: str = "localhost"
    MQTT_PORT: int = 1883
    MQTT_TOPIC_SENSORS: str = "solargrow/sensors"
    MQTT_TOPIC_CONTROL: str = "solargrow/control"
    MQTT_TOPIC_AI: str = "solargrow/ai"

    # --- Raspberry Pi ---
    RASPBERRY_PI_URL: str = "http://192.168.1.100:5000"

    # --- Google Gemini (IA de Visión Computacional) ---
    # Obtén tu clave GRATIS en: https://aistudio.google.com/apikey
    GEMINI_API_KEY: str = ""

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    """Obtiene la configuración (cacheada)."""
    return Settings()
