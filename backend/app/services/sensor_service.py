# ============================================================
# Solar-Grow - Servicio de historial de sensores
# ============================================================
from datetime import datetime, timedelta, timezone
from typing import List, TypeVar

from sqlalchemy import desc
from sqlalchemy.orm import Session

from ..models.sensor_data import SensorData

T = TypeVar("T")


def pick_evenly(items: List[T], limit: int) -> List[T]:
    """Elige `limit` elementos repartidos de forma pareja en la lista.

    Si hay `limit` elementos o menos, devuelve una copia con todos. Si no, toma
    las posiciones round(i * (N - 1) / (limit - 1)); con limit=1 solo la 0.
    Incluye siempre el primero y el último (salvo con limit=1). No modifica
    la lista original.
    """
    total = len(items)
    if total <= limit:
        return list(items)
    if limit <= 1:
        return list(items[:1])
    return [items[round(i * (total - 1) / (limit - 1))] for i in range(limit)]


def get_history(db: Session, plant_id: int, hours: int, limit: int) -> List[SensorData]:
    """Lecturas de una planta en las últimas `hours` horas, de la más reciente
    a la más antigua, con como mucho `limit` lecturas repartidas por todo el periodo.
    """
    since = datetime.now(timezone.utc) - timedelta(hours=hours)

    # Solo los id (baratos) para elegir qué lecturas traer
    ids = [
        row[0]
        for row in db.query(SensorData.id)
        .filter(SensorData.plant_id == plant_id, SensorData.recorded_at >= since)
        .order_by(desc(SensorData.recorded_at), desc(SensorData.id))
        .all()
    ]
    chosen = pick_evenly(ids, limit)
    if not chosen:
        return []

    records = (
        db.query(SensorData)
        .filter(SensorData.id.in_(chosen))
        .order_by(desc(SensorData.recorded_at), desc(SensorData.id))
        .all()
    )
    return records
