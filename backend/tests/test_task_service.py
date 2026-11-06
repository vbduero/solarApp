# ============================================================
# Solar-Grow - Pruebas del cálculo de tareas atrasadas
# ============================================================
from datetime import datetime, timedelta, timezone

import pytest

from app.models.task import Task, TaskStatus, TaskType
from app.services.task_service import COLOMBIA_TZ, apply_overdue_state, refresh_overdue_tasks

# 2026-11-05 07:00 en Colombia (12:00 UTC)
NOW = datetime(2026, 11, 5, 7, 0, tzinfo=COLOMBIA_TZ)


def colombia(day, hour=0, minute=0):
    return datetime(2026, 11, day, hour, minute, tzinfo=COLOMBIA_TZ)


def utc(day, hour=0, minute=0):
    return datetime(2026, 11, day, hour, minute, tzinfo=timezone.utc)


def build_task(due_date, status=TaskStatus.PENDIENTE, days_overdue=0):
    return Task(
        task_type=TaskType.REGAR,
        status=status,
        due_date=due_date,
        days_overdue=days_overdue,
    )


@pytest.mark.parametrize(
    "due_date, now, expected_status, expected_days",
    [
        pytest.param(utc(2, 10), NOW, TaskStatus.ATRASADA, 3, id="caso1-vencida-hace-3-dias"),
        pytest.param(
            colombia(4, 23, 59), colombia(5, 0, 1), TaskStatus.ATRASADA, 1,
            id="caso2-minutos-despues-de-medianoche",
        ),
        pytest.param(
            colombia(3, 20), colombia(5, 10), TaskStatus.ATRASADA, 2,
            id="caso3-cuenta-dias-calendario-no-horas",
        ),
        pytest.param(colombia(5, 0), NOW, TaskStatus.PENDIENTE, 0, id="caso4-limite-inicio-de-hoy"),
        pytest.param(NOW + timedelta(days=1), NOW, TaskStatus.PENDIENTE, 0, id="caso5-vence-manana"),
        pytest.param(
            datetime(2026, 11, 5, 3, 0), NOW, TaskStatus.ATRASADA, 1,
            id="caso8-sin-zona-se-interpreta-como-utc",
        ),
        pytest.param(utc(5, 3), NOW, TaskStatus.ATRASADA, 1, id="caso9-ayer-en-colombia-hoy-en-utc"),
        pytest.param(
            utc(4, 10), utc(5, 2), TaskStatus.PENDIENTE, 0,
            id="caso10-en-colombia-aun-no-cambia-el-dia",
        ),
        pytest.param(
            colombia(5, 9), colombia(5, 20), TaskStatus.PENDIENTE, 0,
            id="caso14-vence-hoy-consultada-a-las-20-colombia",
        ),
    ],
)
def test_calcula_estado_y_dias_segun_el_dia_de_colombia(due_date, now, expected_status, expected_days):
    task = build_task(due_date)

    apply_overdue_state(task, now)

    assert task.status == expected_status
    assert task.days_overdue == expected_days


def test_completada_con_fecha_pasada_no_queda_atrasada():
    task = build_task(utc(1), status=TaskStatus.COMPLETADA, days_overdue=4)

    assert apply_overdue_state(task, NOW) is True

    assert task.status == TaskStatus.COMPLETADA
    assert task.days_overdue == 0


def test_atrasada_con_fecha_futura_vuelve_a_pendiente():
    task = build_task(NOW + timedelta(days=2), status=TaskStatus.ATRASADA, days_overdue=2)

    apply_overdue_state(task, NOW)

    assert task.status == TaskStatus.PENDIENTE
    assert task.days_overdue == 0


def test_segunda_llamada_con_el_mismo_now_no_cambia_nada():
    task = build_task(utc(2))

    assert apply_overdue_state(task, NOW) is True
    assert apply_overdue_state(task, NOW) is False


def test_un_dia_despues_suma_un_dia_de_atraso():
    task = build_task(utc(2))
    apply_overdue_state(task, NOW)
    days_before = task.days_overdue

    assert apply_overdue_state(task, NOW + timedelta(days=1)) is True

    assert task.days_overdue == days_before + 1


def test_refresh_solo_cambia_tareas_del_usuario_indicado(db, user, other_user, plant, other_plant):
    overdue = Task(user_id=user.id, plant_id=plant.id, task_type=TaskType.REGAR, due_date=utc(2, 10))
    future = Task(
        user_id=user.id,
        plant_id=plant.id,
        task_type=TaskType.PODAR,
        due_date=NOW + timedelta(days=1),
    )
    foreign = Task(
        user_id=other_user.id,
        plant_id=other_plant.id,
        task_type=TaskType.REGAR,
        due_date=utc(2),
    )
    db.add_all([overdue, future, foreign])
    db.commit()

    assert refresh_overdue_tasks(db, user.id, NOW) == 1

    db.refresh(overdue)
    db.refresh(future)
    db.refresh(foreign)
    assert (overdue.status, overdue.days_overdue) == (TaskStatus.ATRASADA, 3)
    assert (future.status, future.days_overdue) == (TaskStatus.PENDIENTE, 0)
    assert (foreign.status, foreign.days_overdue) == (TaskStatus.PENDIENTE, 0)
