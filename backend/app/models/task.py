# ============================================================
# Solar-Grow - Modelo de Tareas
# ============================================================
import enum
from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class TaskType(str, enum.Enum):
    """Tipos de tareas de cuidado de plantas."""
    REGAR = "Regar"
    FERTILIZAR = "Fertilizar"
    TRASPLANTAR = "Trasplantar"
    PODAR = "Podar"
    REVISAR = "Revisar"


class TaskStatus(str, enum.Enum):
    """Estados posibles de una tarea."""
    PENDIENTE = "Pendiente"
    COMPLETADA = "Completada"
    ATRASADA = "Atrasada"


class Task(Base):
    """Modelo de tareas de cuidado para las plantas.
    
    Representa acciones pendientes como regar, fertilizar
    o trasplantar que el usuario debe realizar.
    """
    __tablename__ = "tasks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    plant_id = Column(Integer, ForeignKey("plants.id"), nullable=False)

    task_type = Column(Enum(TaskType), nullable=False)
    status = Column(Enum(TaskStatus), default=TaskStatus.PENDIENTE)
    description = Column(String(500), nullable=True)

    # Fechas
    due_date = Column(DateTime(timezone=True), nullable=False)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    days_overdue = Column(Integer, default=0)

    # Automática o manual
    is_auto_generated = Column(Boolean, default=False)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # Relaciones
    user = relationship("User", back_populates="tasks")
    plant = relationship("Plant", back_populates="tasks")
