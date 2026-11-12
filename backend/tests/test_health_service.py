# ============================================================
# Solar-Grow - Pruebas de la regla única de salud según sensores (spec 004)
# ============================================================
# Funciones puras: sin base de datos, sin hardware, sin red.
# El servicio se importa dentro de cada prueba (ver _servicio) para que, mientras
# `app/services/health_service.py` no exista, cada prueba falle por su cuenta
# con ModuleNotFoundError y no se rompa la recolección del resto de la suite.
# ============================================================
import importlib

import pytest

from app.models.plant import Plant

MIN_HUMIDITY = 25.0
MAX_TEMPERATURE = 35.0


def _servicio():
    return importlib.import_module("app.services.health_service")


# (suelo, temperatura, estado, puntaje): tabla de CA-1 más los bordes de la regla
TABLA_CA1 = [
    pytest.param(50, 28, "Sana", 100.0, id="normal"),
    pytest.param(25, 35, "Sana", 100.0, id="justo-en-ambos-umbrales"),
    pytest.param(20, 28, "Necesita agua", 90.0, id="suelo-bajo"),
    pytest.param(0, 28, "Necesita agua", 60.0, id="suelo-en-cero-tope-40"),
    pytest.param(50, 40, "Exceso de calor", 85.0, id="calor"),
    pytest.param(15, 45, "Necesita agua", 50.0, id="suelo-bajo-y-calor"),
    pytest.param(0, 45, "Critica", 30.0, id="critica-tope-de-ambos"),
]

BORDES = [
    pytest.param(24.9, 35, "Necesita agua", 99.8, id="suelo-justo-bajo-el-umbral"),
    pytest.param(50, 35.1, "Exceso de calor", 99.7, id="temperatura-justo-sobre-el-umbral"),
    pytest.param(10, 45, "Necesita agua", 40.0, id="puntaje-exactamente-40-no-es-critica"),
    pytest.param(9.5, 45, "Critica", 39.0, id="puntaje-39-es-critica"),
]


@pytest.mark.parametrize("soil, temperature, status, score", TABLA_CA1 + BORDES)
def test_regla_de_salud_da_estado_y_puntaje_de_la_tabla(soil, temperature, status, score):
    health = _servicio().calculate_sensor_health(soil, temperature, MIN_HUMIDITY, MAX_TEMPERATURE)
    assert health.status == status
    assert health.score == score


@pytest.mark.parametrize(
    "soil, temperature, status, score",
    [
        # exceso 15 -> 3*15 = 45, pero la resta por temperatura tope en 30
        pytest.param(50, 50, "Exceso de calor", 70.0, id="tope-30-solo-temperatura"),
        # exceso 10 -> 30 exactos: el tope no recorta nada
        pytest.param(50, 45, "Exceso de calor", 70.0, id="exceso-10-justo-en-el-tope"),
        # exceso 25 -> 75 sin tope; con tope 30 sigue en 70
        pytest.param(50, 60, "Exceso de calor", 70.0, id="tope-30-con-exceso-enorme"),
        # suelo: 2*25 = 50 -> tope 40; temperatura: 3*15 = 45 -> tope 30 => 30.0
        pytest.param(0, 50, "Critica", 30.0, id="topes-de-suelo-y-temperatura-a-la-vez"),
        # deficit 20 -> 40 (justo el tope) y exceso 25 -> 75 recortado a 30 => 100-40-30
        pytest.param(5, 60, "Critica", 30.0, id="ambos-topes-con-suelo-en-5"),
    ],
)
def test_regla_de_salud_limita_la_resta_por_temperatura_a_30(
    soil, temperature, status, score
):
    health = _servicio().calculate_sensor_health(soil, temperature, MIN_HUMIDITY, MAX_TEMPERATURE)
    assert (health.status, health.score) == (status, score)


def test_regla_de_salud_redondea_el_puntaje_a_un_decimal():
    # déficit 0.03 -> resta 0.06 -> 99.94 -> 99.9
    health = _servicio().calculate_sensor_health(24.97, 28, MIN_HUMIDITY, MAX_TEMPERATURE)
    assert health.score == 99.9
    assert health.status == "Necesita agua"


def test_regla_de_salud_con_umbrales_nulos_usa_30_y_35():
    # Con 30 y 35: déficit 5 (resta 10) y exceso 1 (resta 3) -> 87.0
    health = _servicio().calculate_sensor_health(25, 36, None, None)
    assert (health.status, health.score) == ("Necesita agua", 87.0)
    # Con 25 y 35 la misma lectura daría otra cosa: la prueba distingue ambos casos
    otra = _servicio().calculate_sensor_health(25, 36, 25, 35)
    assert (otra.status, otra.score) == ("Exceso de calor", 97.0)


def test_regla_de_salud_con_un_solo_umbral_nulo_usa_el_defecto_solo_de_ese():
    # min nulo -> 30; max explícito 40, así que 38 °C no es calor
    health = _servicio().calculate_sensor_health(25, 38, None, 40)
    assert (health.status, health.score) == ("Necesita agua", 90.0)


@pytest.mark.parametrize("temperature", [None, 28, 45])
def test_regla_de_salud_sin_humedad_del_suelo_da_sin_datos(temperature):
    # Nunca se evalúa la temperatura sola ni se inventa un puntaje
    health = _servicio().calculate_sensor_health(None, temperature, MIN_HUMIDITY, MAX_TEMPERATURE)
    assert health.status == "Sin datos"
    assert health.score is None


@pytest.mark.parametrize(
    "soil, status, score",
    [
        pytest.param(20, "Necesita agua", 90.0, id="suelo-bajo"),
        pytest.param(50, "Sana", 100.0, id="suelo-normal"),
        pytest.param(0, "Necesita agua", 60.0, id="suelo-cero"),
    ],
)
def test_regla_de_salud_sin_temperatura_evalua_solo_el_suelo(soil, status, score):
    health = _servicio().calculate_sensor_health(soil, None, MIN_HUMIDITY, MAX_TEMPERATURE)
    assert (health.status, health.score) == (status, score)


def test_regla_de_salud_solo_devuelve_estados_en_espanol():
    servicio = _servicio()
    permitidos = {"Sana", "Necesita agua", "Exceso de calor", "Critica", "Sin datos"}
    prohibidos = {"healthy", "needs_water", "needs_light", "stressed", "critical", "unknown"}
    for soil in (None, 0, 10, 25, 50):
        for temperature in (None, 20, 35, 40, 50):
            estado = servicio.calculate_sensor_health(
                soil, temperature, MIN_HUMIDITY, MAX_TEMPERATURE
            ).status
            assert estado in permitidos
            assert estado not in prohibidos


# --- Estado en vivo (CA-7 y CA-8) ---

def test_salud_en_vivo_en_linea_usa_los_umbrales_de_la_planta():
    plant = Plant(min_humidity=25, max_temperature=35)  # sin guardar
    health = _servicio().calculate_live_health(plant, "En línea", 20, 28)
    assert (health.status, health.score) == ("Necesita agua", 90.0)

    # Con otros umbrales de planta, la misma lectura da otro resultado
    exigente = Plant(min_humidity=60, max_temperature=35)
    health = _servicio().calculate_live_health(exigente, "En línea", 20, 28)
    assert (health.status, health.score) == ("Necesita agua", 60.0)


@pytest.mark.parametrize("soil, temperature, status, score", TABLA_CA1)
def test_salud_en_vivo_coincide_con_la_regla_pura(soil, temperature, status, score):
    plant = Plant(min_humidity=25, max_temperature=35)
    health = _servicio().calculate_live_health(plant, "En línea", soil, temperature)
    assert (health.status, health.score) == (status, score)


def test_salud_en_vivo_en_linea_sin_suelo_da_sin_datos():
    plant = Plant(min_humidity=25, max_temperature=35)
    health = _servicio().calculate_live_health(plant, "En línea", None, 28)
    assert (health.status, health.score) == ("Sin datos", None)


@pytest.mark.parametrize(
    "tiene_planta, conexion",
    [
        pytest.param(True, "Desconectado", id="desconectado"),
        pytest.param(True, "", id="estado-vacio"),
        pytest.param(True, "en linea", id="estado-con-otra-escritura"),
        pytest.param(False, "En línea", id="sin-planta"),
        pytest.param(False, "Desconectado", id="sin-planta-y-desconectado"),
    ],
)
def test_salud_en_vivo_es_none_si_no_esta_en_linea_o_no_hay_planta(tiene_planta, conexion):
    plant = Plant(min_humidity=25, max_temperature=35) if tiene_planta else None
    assert _servicio().calculate_live_health(plant, conexion, 20, 28) is None
