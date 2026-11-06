# ============================================================
# Solar-Grow - Pruebas de endpoints de tareas
# ============================================================
from datetime import datetime, timedelta, timezone

import pytest

from app.models.task import Task, TaskStatus, TaskType
from app.schemas.task import TaskResponse
from app.services.task_service import COLOMBIA_TZ

TASKS_URL = "/api/tasks/"


def days_from_today(days):
    """Fecha en UTC (SQLite descarta la zona), a la 01:00 del día de Colombia indicado.

    Parte del inicio del día para que las pruebas no fallen cerca de medianoche.
    """
    start_of_today = datetime.now(COLOMBIA_TZ).replace(hour=1, minute=0, second=0, microsecond=0)
    return (start_of_today + timedelta(days=days)).astimezone(timezone.utc)


@pytest.fixture
def make_task(db, user, plant):
    def _make_task(days=-3, status=TaskStatus.PENDIENTE, task_type=TaskType.REGAR, owner=None, owner_plant=None):
        task = Task(
            user_id=(owner or user).id,
            plant_id=(owner_plant or plant).id,
            task_type=task_type,
            status=status,
            due_date=days_from_today(days),
        )
        db.add(task)
        db.commit()
        db.refresh(task)
        return task

    return _make_task


# ------------------------------------------------------------
# GET /api/tasks/
# ------------------------------------------------------------
def test_get_devuelve_vencida_como_atrasada_y_la_guarda(client, db, make_task):
    task = make_task(days=-3)

    response = client.get(TASKS_URL)

    assert response.status_code == 200
    body = response.json()
    assert [item["id"] for item in body] == [task.id]
    assert body[0]["status"] == "Atrasada"
    assert body[0]["days_overdue"] == 3

    db.refresh(task)
    assert task.status == TaskStatus.ATRASADA
    assert task.days_overdue == 3


def test_get_filtro_status_usa_el_estado_calculado(client, make_task):
    task = make_task(days=-3)

    overdue = client.get(TASKS_URL, params={"status": "Atrasada"})
    pending = client.get(TASKS_URL, params={"status": "Pendiente"})

    assert [item["id"] for item in overdue.json()] == [task.id]
    assert pending.json() == []


def test_get_completada_con_fecha_pasada_no_aparece_en_hoy(client, make_task):
    make_task(days=-3, status=TaskStatus.COMPLETADA)

    assert client.get(TASKS_URL).json() == []


def test_get_upcoming_no_devuelve_vencidas_y_futura_sigue_pendiente(client, make_task):
    make_task(days=-3)
    future = make_task(days=2)

    body = client.get(TASKS_URL, params={"upcoming": "true"}).json()

    assert [item["id"] for item in body] == [future.id]
    assert body[0]["status"] == "Pendiente"
    assert body[0]["days_overdue"] == 0


def test_get_no_muestra_ni_modifica_tareas_de_otro_usuario(client, db, make_task, other_user, other_plant):
    foreign = make_task(days=-3, owner=other_user, owner_plant=other_plant)

    assert client.get(TASKS_URL).json() == []

    db.refresh(foreign)
    assert foreign.status == TaskStatus.PENDIENTE
    assert foreign.days_overdue == 0


def test_get_status_invalido_devuelve_422(client):
    assert client.get(TASKS_URL, params={"status": "Inventado"}).status_code == 422


def test_get_filtra_por_task_type(client, make_task):
    watering = make_task(days=-1, task_type=TaskType.REGAR)
    make_task(days=-1, task_type=TaskType.PODAR)

    body = client.get(TASKS_URL, params={"task_type": "Regar"}).json()

    assert [item["id"] for item in body] == [watering.id]
    assert body[0]["task_type"] == "Regar"


def test_get_task_type_invalido_devuelve_422(client):
    assert client.get(TASKS_URL, params={"task_type": "Inventado"}).status_code == 422


def test_get_conserva_el_contrato_json(client, make_task):
    make_task(days=-1)

    item = client.get(TASKS_URL).json()[0]

    assert set(item) == set(TaskResponse.model_fields)
    assert item["task_type"] == "Regar"
    assert item["status"] == "Atrasada"
    assert item["plant_location"] == "Balcon"


# ------------------------------------------------------------
# POST /api/tasks/
# ------------------------------------------------------------
def test_post_valido_devuelve_task_type_en_espanol(client, plant):
    response = client.post(
        TASKS_URL,
        json={
            "plant_id": plant.id,
            "task_type": "Regar",
            "due_date": days_from_today(1).isoformat(),
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["task_type"] == "Regar"
    assert body["status"] == "Pendiente"
    assert body["days_overdue"] == 0


def test_post_task_type_invalido_devuelve_422(client, plant):
    response = client.post(
        TASKS_URL,
        json={
            "plant_id": plant.id,
            "task_type": "Inventado",
            "due_date": days_from_today(1).isoformat(),
        },
    )

    assert response.status_code == 422


def test_post_planta_de_otro_usuario_devuelve_404(client, other_plant):
    response = client.post(
        TASKS_URL,
        json={
            "plant_id": other_plant.id,
            "task_type": "Regar",
            "due_date": days_from_today(1).isoformat(),
        },
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "Planta no encontrada"


# ------------------------------------------------------------
# PATCH /api/tasks/{id}
# ------------------------------------------------------------
def test_patch_completar_vencida_deja_de_estar_atrasada(client, make_task):
    task = make_task(days=-3)
    client.get(TASKS_URL)  # la marca como Atrasada

    response = client.patch(f"{TASKS_URL}{task.id}", json={"status": "Completada"})

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "Completada"
    assert body["days_overdue"] == 0
    assert body["completed_at"] is not None
    assert client.get(TASKS_URL).json() == []


def test_patch_sin_cambios_calcula_el_atraso(client, make_task):
    task = make_task(days=-3)

    body = client.patch(f"{TASKS_URL}{task.id}", json={}).json()

    assert body["status"] == "Atrasada"
    assert body["days_overdue"] == 3


def test_patch_pendiente_sobre_vencida_sigue_atrasada(client, make_task):
    task = make_task(days=-3)

    body = client.patch(f"{TASKS_URL}{task.id}", json={"status": "Pendiente"}).json()

    assert body["status"] == "Atrasada"
    assert body["days_overdue"] == 3


def test_patch_atrasada_sobre_no_vencida_queda_pendiente(client, make_task):
    task = make_task(days=2)

    body = client.patch(f"{TASKS_URL}{task.id}", json={"status": "Atrasada"}).json()

    assert body["status"] == "Pendiente"
    assert body["days_overdue"] == 0


def test_patch_tarea_de_otro_usuario_devuelve_404(client, make_task, other_user, other_plant):
    foreign = make_task(days=-3, owner=other_user, owner_plant=other_plant)

    response = client.patch(f"{TASKS_URL}{foreign.id}", json={"status": "Completada"})

    assert response.status_code == 404
    assert response.json()["detail"] == "Tarea no encontrada"


def test_patch_id_inexistente_devuelve_404(client):
    assert client.patch(f"{TASKS_URL}9999", json={"status": "Completada"}).status_code == 404


def test_patch_status_invalido_devuelve_422_y_no_cambia_la_fila(client, db, make_task):
    task = make_task(days=2)

    response = client.patch(f"{TASKS_URL}{task.id}", json={"status": "Inventado"})

    assert response.status_code == 422
    db.refresh(task)
    assert task.status == TaskStatus.PENDIENTE
