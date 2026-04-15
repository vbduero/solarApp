# ============================================================
# Solar-Grow - Schemas de Tareas
# ============================================================
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class TaskCreate(BaseModel):
    """Schema para crear una tarea."""
    plant_id: int
    task_type: str  # Regar, Fertilizar, Trasplantar, Podar, Revisar
    description: Optional[str] = None
    due_date: datetime


class TaskUpdate(BaseModel):
    """Schema para actualizar una tarea (completar/cancelar)."""
    status: Optional[str] = None  # Pendiente, Completada, Atrasada
    completed_at: Optional[datetime] = None


class TaskResponse(BaseModel):
    """Schema de respuesta de tarea."""
    id: int
    plant_id: int
    plant_name: Optional[str] = None
    plant_image: Optional[str] = None
    plant_location: Optional[str] = None
    task_type: str
    status: str
    description: Optional[str] = None
    due_date: datetime
    completed_at: Optional[datetime] = None
    days_overdue: int
    is_auto_generated: bool
    created_at: datetime

    class Config:
        from_attributes = True
