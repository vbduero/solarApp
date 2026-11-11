# ============================================================
# Solar-Grow - Script de Datos de Demostración
# ============================================================
"""
Ejecutar con: python -m backend.seed_data
Inserta datos de ejemplo para desarrollo y pruebas.
"""
import sys
import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Agregar el directorio padre al path
sys.path.insert(0, str(Path(__file__).parent))

from app.database import SessionLocal, engine, Base
from app.models.user import User
from app.models.plant import Plant, PlantLocation
from app.models.sensor_data import SensorData
from app.models.task import Task, TaskType, TaskStatus
from app.models.recommendation import Recommendation, AIDiagnosis, HealthStatus
from app.utils.auth import hash_password


def seed_database():
    """Inserta datos de demostración en la base de datos."""
    # Crear tablas
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()

    try:
        # Verificar si ya hay datos
        if db.query(User).first():
            print("[INFO] La base de datos ya tiene datos. Saltando seed.")
            return

        print("[INFO] Insertando datos de demostración para Solar-Grow...")

        # === USUARIO DE DEMOSTRACIÓN ===
        user = User(
            email="demo@solargrow.com",
            hashed_password=hash_password("solar123"),
            full_name="Agricultor Solar",
            city="Neiva",
        )
        db.add(user)
        db.flush()

        # === PLANTAS ===
        plants_data = [
            {
                "common_name": "Echeveria",
                "scientific_name": "Echeveria elegans",
                "plant_type": "Suculento",
                "location": PlantLocation.BALCON,
                "care_difficulty": "Fácil",
                "watering_frequency": "Cada 2 semanas",
                "sun_exposure": "Parcial",
                "soil_type": "Franco arenoso",
                "soil_ph_min": 5.5,
                "soil_ph_max": 6.5,
                "max_size": "Hasta 20 in",
                "toxicity": "No Tóxica",
                "hardiness_zones": "9 - 11",
                "description": "La Echeveria es una suculenta originaria de México. "
                              "Es perfecta para principiantes por su fácil cuidado.",
                "min_humidity": 25.0,
                "max_temperature": 35.0,
                "min_light": 30.0,
            },
            {
                "common_name": "Áloe de arena",
                "scientific_name": "Aloe vera",
                "plant_type": "Suculento",
                "location": PlantLocation.DORMITORIO,
                "care_difficulty": "Fácil",
                "watering_frequency": "Cada 2 semanas",
                "sun_exposure": "Parcial",
                "soil_type": "Franco arenoso",
                "soil_ph_min": 5.5,
                "soil_ph_max": 6.5,
                "max_size": "Hasta 20 in",
                "toxicity": "No Tóxica",
                "hardiness_zones": "9 - 11",
                "description": "El Áloe vera es conocida por sus propiedades medicinales. "
                              "Ideal para interiores con buena iluminación.",
                "min_humidity": 20.0,
                "max_temperature": 38.0,
                "min_light": 25.0,
            },
            {
                "common_name": "Nenúfares",
                "scientific_name": "Nymphaea",
                "plant_type": "Acuática",
                "location": PlantLocation.JARDIN,
                "care_difficulty": "Medio",
                "watering_frequency": "Mantener húmedo",
                "sun_exposure": "Directo",
                "soil_type": "Arcilloso",
                "min_humidity": 60.0,
                "max_temperature": 32.0,
                "min_light": 40.0,
            },
            {
                "common_name": "Geranios",
                "scientific_name": "Pelargonium",
                "plant_type": "Floral",
                "location": PlantLocation.BALCON,
                "care_difficulty": "Fácil",
                "watering_frequency": "2-3 veces por semana",
                "sun_exposure": "Directo",
                "min_humidity": 35.0,
                "max_temperature": 30.0,
                "min_light": 50.0,
            },
            {
                "common_name": "Hoja aplastada",
                "scientific_name": "Kalanchoe thyrsiflora",
                "plant_type": "Suculento",
                "location": PlantLocation.BALCON,
                "care_difficulty": "Fácil",
                "watering_frequency": "Cada 10 días",
                "sun_exposure": "Parcial",
                "min_humidity": 20.0,
                "max_temperature": 35.0,
                "min_light": 30.0,
            },
        ]

        plants = []
        for pdata in plants_data:
            plant = Plant(user_id=user.id, **pdata)
            db.add(plant)
            plants.append(plant)

        db.flush()

        # === DATOS DE SENSORES ===
        now = datetime.now(timezone.utc)
        for plant in plants:
            for i in range(48):  # 48 registros (cada 30 min = 24 horas)
                timestamp = now - timedelta(minutes=30 * i)
                import random
                sensor = SensorData(
                    plant_id=plant.id,
                    temperature=random.uniform(22.0, 32.0),
                    air_humidity=random.uniform(40.0, 80.0),
                    soil_humidity=random.uniform(20.0, 70.0),
                    light_level=random.uniform(10.0, 90.0),
                    solar_voltage=random.uniform(12.0, 18.0),
                    solar_power=random.uniform(5.0, 18.0),
                    battery_level=random.uniform(60.0, 100.0),
                    servo_angle_x=random.uniform(-45.0, 45.0),
                    servo_angle_y=random.uniform(0.0, 90.0),
                    pump_active=0,
                    source="esp32",
                    recorded_at=timestamp,
                )
                db.add(sensor)

        # === TAREAS ===
        tasks_data = [
            {
                "plant": plants[0],
                "task_type": TaskType.REGAR,
                "status": TaskStatus.PENDIENTE,
                "due_date": now - timedelta(hours=2),
                "days_overdue": 0,
            },
            {
                "plant": plants[1],
                "task_type": TaskType.REGAR,
                "status": TaskStatus.PENDIENTE,
                "due_date": now - timedelta(days=1),
                "days_overdue": 1,
            },
            {
                "plant": plants[1],
                "task_type": TaskType.FERTILIZAR,
                "status": TaskStatus.ATRASADA,
                "due_date": now - timedelta(days=2),
                "days_overdue": 2,
            },
            {
                "plant": plants[0],
                "task_type": TaskType.TRASPLANTAR,
                "status": TaskStatus.ATRASADA,
                "due_date": now - timedelta(days=1),
                "days_overdue": 1,
            },
            {
                "plant": plants[1],
                "task_type": TaskType.TRASPLANTAR,
                "status": TaskStatus.ATRASADA,
                "due_date": now - timedelta(days=2),
                "days_overdue": 2,
            },
        ]

        for tdata in tasks_data:
            task = Task(
                user_id=user.id,
                plant_id=tdata["plant"].id,
                task_type=tdata["task_type"],
                status=tdata["status"],
                due_date=tdata["due_date"],
                days_overdue=tdata["days_overdue"],
                is_auto_generated=True,
            )
            db.add(task)

        # === RECOMENDACIONES ===
        recs_data = [
            {
                "plant": plants[0],
                "title": "💧 Necesita agua",
                "message": "La humedad del suelo está por debajo del 30%. "
                          "Recomendamos regar la Echeveria con 200ml de agua.",
                "category": "riego",
                "priority": "alta",
            },
            {
                "plant": plants[0],
                "title": "☀️ Buena exposición solar",
                "message": "Tu Echeveria está recibiendo la cantidad óptima de luz. "
                          "Mantén la ubicación actual.",
                "category": "luz",
                "priority": "baja",
            },
            {
                "plant": plants[1],
                "title": "🌡️ Temperatura alta",
                "message": "La temperatura ha subido a 32°C. Considera mover "
                          "el Áloe a un lugar con sombra parcial.",
                "category": "temperatura",
                "priority": "media",
            },
        ]

        for rdata in recs_data:
            rec = Recommendation(
                plant_id=rdata["plant"].id,
                title=rdata["title"],
                message=rdata["message"],
                category=rdata["category"],
                priority=rdata["priority"],
            )
            db.add(rec)

        # === DIAGNÓSTICO IA ===
        diagnosis = AIDiagnosis(
            plant_id=plants[0].id,
            health_status=HealthStatus.BUENA,
            confidence=87.5,
            diagnosis="La planta presenta un estado general bueno. "
                     "Las hojas muestran color verde vibrante sin "
                     "señales de plagas o enfermedades.",
            detected_issues="[]",
            suggested_actions='["Mantener el riego actual", "Fertilizar en 2 semanas"]',
        )
        db.add(diagnosis)

        db.commit()
        print("[INFO] Datos de demostración insertados exitosamente!")
        print(f"   - 1 usuario (demo@solargrow.com / solar123)")
        print(f"   - {len(plants)} plantas")
        print(f"   - {48 * len(plants)} registros de sensores")
        print(f"   - {len(tasks_data)} tareas")
        print(f"   - {len(recs_data)} recomendaciones")
        print(f"   - 1 diagnostico IA")

    except Exception as e:
        db.rollback()
        print(f"Error al insertar datos: {e}")
        raise
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
