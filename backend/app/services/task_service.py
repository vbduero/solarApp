# ============================================================
# Solar-Grow - Servicio de Tareas
# ============================================================
from datetime import date, datetime, timedelta, timezone
from typing import Optional

from sqlalchemy.orm import Session

from ..models.task import Task, TaskStatus

# Colombia no aplica horario de verano: desfase fijo, sin dependencias nuevas.
COLOMBIA_TZ = timezone(timedelta(hours=-5))


def _colombia_date(value: datetime) -> date:
    """Devuelve el día calendario de Colombia para una fecha.

    Las fechas sin zona (así las devuelve SQLite) se interpretan como UTC.
    """
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(COLOMBIA_TZ).date()


def apply_overdue_state(task: Task, now: Optional[datetime] = None) -> bool:
    """Ajusta status y days_overdue de la tarea según su due_date. No hace commit.

    Devuelve True si algo cambió.
    """
    today = _colombia_date(now or datetime.now(timezone.utc))
    due_day = _colombia_date(task.due_date)

    if task.status == TaskStatus.COMPLETADA:
        new_status, new_days_overdue = TaskStatus.COMPLETADA, 0
    elif due_day < today:
        new_status, new_days_overdue = TaskStatus.ATRASADA, (today - due_day).days
    else:
        new_status, new_days_overdue = TaskStatus.PENDIENTE, 0

    if task.status == new_status and task.days_overdue == new_days_overdue:
        return False

    task.status = new_status
    task.days_overdue = new_days_overdue
    return True


def refresh_overdue_tasks(db: Session, user_id: int, now: Optional[datetime] = None) -> int:
    """Aplica apply_overdue_state a las tareas del usuario y hace commit si hubo cambios.

    Devuelve cuántas tareas cambiaron.
    """
    now = now or datetime.now(timezone.utc)
    tasks = db.query(Task).filter(Task.user_id == user_id).all()
    changed = sum(apply_overdue_state(task, now) for task in tasks)
    if changed:
        db.commit()
    return changed
