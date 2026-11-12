# ============================================================
# Solar-Grow - Servicio de salud según sensores
# ============================================================
# Regla única del estado de la planta. Solo usa humedad del suelo y
# temperatura; la luz, el voltaje y la batería no intervienen.
from typing import NamedTuple, Optional

from ..models.plant import Plant

SANA = "Sana"
NECESITA_AGUA = "Necesita agua"
EXCESO_DE_CALOR = "Exceso de calor"
CRITICA = "Critica"
SIN_DATOS = "Sin datos"

ONLINE_STATUS = "En línea"

# Mismos valores por defecto que las columnas de Plant
DEFAULT_MIN_HUMIDITY = 30.0
DEFAULT_MAX_TEMPERATURE = 35.0


class SensorHealth(NamedTuple):
    """Estado y puntaje (0-100) de la planta según los sensores."""
    status: str
    score: Optional[float]


def calculate_sensor_health(
    soil_humidity: Optional[float],
    temperature: Optional[float],
    min_humidity: Optional[float],
    max_temperature: Optional[float],
) -> SensorHealth:
    """Calcula el estado de salud con la humedad del suelo y la temperatura."""
    if soil_humidity is None:
        return SensorHealth(SIN_DATOS, None)

    if min_humidity is None:
        min_humidity = DEFAULT_MIN_HUMIDITY
    if max_temperature is None:
        max_temperature = DEFAULT_MAX_TEMPERATURE

    score = 100.0
    soil_low = soil_humidity < min_humidity
    too_hot = temperature is not None and temperature > max_temperature

    if soil_low:
        score -= min(2 * (min_humidity - soil_humidity), 40)
    if too_hot:
        score -= min(3 * (temperature - max_temperature), 30)

    if score < 40:
        status = CRITICA
    elif soil_low:
        status = NECESITA_AGUA
    elif too_hot:
        status = EXCESO_DE_CALOR
    else:
        status = SANA

    return SensorHealth(status, round(score, 1))


def calculate_live_health(
    plant: Optional[Plant],
    connection_status: str,
    soil_humidity: Optional[float],
    temperature: Optional[float],
) -> Optional[SensorHealth]:
    """Salud con la lectura en vivo del ESP8266; None si no aplica."""
    if connection_status != ONLINE_STATUS or plant is None:
        return None
    return calculate_sensor_health(
        soil_humidity, temperature, plant.min_humidity, plant.max_temperature
    )
