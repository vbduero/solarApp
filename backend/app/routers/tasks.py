# ============================================================
# Solar-Grow - Router de Tareas
# ============================================================
from typing import List, Optional
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc

from ..database import get_db
from ..models.user import User
from ..models.plant import Plant
from ..models.task import Task, TaskStatus
from ..schemas.task import TaskCreate, TaskUpdate, TaskResponse
from ..utils.auth import get_current_user

router = APIRouter(prefix="/api/tasks", tags=["Tareas"])


@router.get("/", response_model=List[TaskResponse])
async def get_tasks(
    task_type: Optional[str] = Query(None, description="Filtrar por tipo de tarea"),
    status: Optional[str] = Query(None, description="Filtrar por estado"),
    upcoming: bool = Query(False, description="True para tareas próximas, False para hoy"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener tareas del usuario.
    
    Para la vista de 'Tareas' con tabs Hoy/Próximamente.
    """
    query = db.query(Task).filter(Task.user_id == current_user.id)

    if task_type:
        query = query.filter(Task.task_type == task_type)
    if status:
        query = query.filter(Task.status == status)

    now = datetime.now(timezone.utc)

    if upcoming:
        # Tareas futuras (próximamente)
        query = query.filter(Task.due_date > now)
    else:
        # Tareas de hoy y atrasadas
        query = query.filter(
            Task.due_date <= now,
            Task.status != TaskStatus.COMPLETADA,
        )

    tasks = query.order_by(Task.due_date.asc()).all()

    result = []
    for task in tasks:
        plant = db.query(Plant).filter(Plant.id == task.plant_id).first()
        task_dict = TaskResponse(
            id=task.id,
            plant_id=task.plant_id,
            plant_name=plant.common_name if plant else "Desconocida",
            plant_image=plant.image_url if plant else None,
            plant_location=plant.location.value if plant and plant.location else None,
            task_type=task.task_type.value if task.task_type else "Revisar",
            status=task.status.value if task.status else "Pendiente",
            description=task.description,
            due_date=task.due_date,
            completed_at=task.completed_at,
            days_overdue=task.days_overdue,
            is_auto_generated=task.is_auto_generated,
            created_at=task.created_at,
        )
        result.append(task_dict)

    return result


@router.post("/", response_model=TaskResponse)
async def create_task(
    task_data: TaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Crear una nueva tarea de cuidado."""
    plant = db.query(Plant).filter(
        Plant.id == task_data.plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(status_code=404, detail="Planta no encontrada")

    new_task = Task(
        user_id=current_user.id,
        plant_id=task_data.plant_id,
        task_type=task_data.task_type,
        description=task_data.description,
        due_date=task_data.due_date,
    )
    db.add(new_task)
    db.commit()
    db.refresh(new_task)

    return TaskResponse(
        id=new_task.id,
        plant_id=new_task.plant_id,
        plant_name=plant.common_name,
        plant_image=plant.image_url,
        plant_location=plant.location.value if plant.location else None,
        task_type=new_task.task_type.value,
        status=new_task.status.value,
        description=new_task.description,
        due_date=new_task.due_date,
        completed_at=new_task.completed_at,
        days_overdue=new_task.days_overdue,
        is_auto_generated=new_task.is_auto_generated,
        created_at=new_task.created_at,
    )


@router.patch("/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: int,
    task_data: TaskUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Actualizar estado de una tarea (completar/cancelar)."""
    task = db.query(Task).filter(
        Task.id == task_id,
        Task.user_id == current_user.id,
    ).first()

    if not task:
        raise HTTPException(status_code=404, detail="Tarea no encontrada")

    if task_data.status:
        task.status = task_data.status
    if task_data.status == "Completada":
        task.completed_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(task)

    plant = db.query(Plant).filter(Plant.id == task.plant_id).first()

    return TaskResponse(
        id=task.id,
        plant_id=task.plant_id,
        plant_name=plant.common_name if plant else "Desconocida",
        plant_image=plant.image_url if plant else None,
        plant_location=plant.location.value if plant and plant.location else None,
        task_type=task.task_type.value,
        status=task.status.value if isinstance(task.status, TaskStatus) else task.status,
        description=task.description,
        due_date=task.due_date,
        completed_at=task.completed_at,
        days_overdue=task.days_overdue,
        is_auto_generated=task.is_auto_generated,
        created_at=task.created_at,
    )
