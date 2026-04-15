# ============================================================
# Solar-Grow - Modelo de Datos de Sensores
# ============================================================
from sqlalchemy import Column, Integer, Float, DateTime, ForeignKey, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class SensorData(Base):
    """Registro de datos de sensores del sistema Solar-Grow.
    
    Almacena las lecturas de todos los sensores conectados al ESP32
    y la Raspberry Pi 4 en intervalos regulares.
    """
    __tablename__ = "sensor_data"

    id = Column(Integer, primary_key=True, index=True)
    plant_id = Column(Integer, ForeignKey("plants.id"), nullable=False)

    # Sensor DHT22
    temperature = Column(Float, nullable=True)  # °C
    air_humidity = Column(Float, nullable=True)  # %

    # Sensor de humedad de suelo capacitivo
    soil_humidity = Column(Float, nullable=True)  # %

    # Sensor LDR
    light_level = Column(Float, nullable=True)  # %

    # Panel Solar
    solar_voltage = Column(Float, nullable=True)  # V
    solar_power = Column(Float, nullable=True)  # W

    # Batería
    battery_level = Column(Float, nullable=True)  # %

    # Servomotores (ángulo del tracking solar)
    servo_angle_x = Column(Float, nullable=True)  # grados
    servo_angle_y = Column(Float, nullable=True)  # grados

    # Estado del riego
    pump_active = Column(Integer, default=0)  # 0 = off, 1 = on

    # Fuente del dato
    source = Column(String(50), default="esp32")  # esp32, raspberry, manual

    # Timestamp
    recorded_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    # Relación
    plant = relationship("Plant", back_populates="sensor_data")
