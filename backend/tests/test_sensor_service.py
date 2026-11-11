# ============================================================
# Solar-Grow - Pruebas unitarias de pick_evenly (spec 001, CA-12)
# ============================================================
# pick_evenly(items, limit) elige `limit` elementos repartidos de forma pareja
# en las posiciones round(i * (N - 1) / (limit - 1)); con limit=1 toma la 0.
# ============================================================
from app.services.sensor_service import pick_evenly


def test_pick_evenly_con_menos_elementos_que_el_limite_devuelve_todos():
    items = [10, 20, 30]

    assert pick_evenly(items, 5) == [10, 20, 30]


def test_pick_evenly_con_tantos_elementos_como_el_limite_devuelve_todos():
    items = list(range(7))

    assert pick_evenly(items, 7) == items


def test_pick_evenly_con_mas_elementos_que_el_limite_devuelve_exactamente_limit():
    items = list(range(100))

    result = pick_evenly(items, 10)

    assert len(result) == 10
    assert len(set(result)) == 10


def test_pick_evenly_incluye_el_primero_y_el_ultimo():
    items = list(range(100))

    result = pick_evenly(items, 10)

    assert result[0] == 0
    assert result[-1] == 99


def test_pick_evenly_conserva_el_orden_y_reparte_parejo():
    items = list(range(101))

    # Posiciones 0, 25, 50, 75, 100 (sin empates de redondeo)
    assert pick_evenly(items, 5) == [0, 25, 50, 75, 100]


def test_pick_evenly_con_limite_1_devuelve_solo_el_primero():
    items = ["reciente", "medio", "antiguo"]

    assert pick_evenly(items, 1) == ["reciente"]


def test_pick_evenly_con_lista_vacia_devuelve_lista_vacia():
    assert pick_evenly([], 10) == []


def test_pick_evenly_no_modifica_la_lista_original():
    items = list(range(50))
    copia = list(items)

    pick_evenly(items, 5)

    assert items == copia
