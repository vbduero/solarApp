# ============================================================
# Solar-Grow - Router de Plantas
# ============================================================
from typing import List, Optional
import os
import shutil
import uuid
from fastapi import APIRouter, Depends, HTTPException, status, Query, File, UploadFile
from sqlalchemy.orm import Session

from ..database import get_db
from ..models.user import User
from ..models.plant import Plant
from ..schemas.plant import PlantCreate, PlantUpdate, PlantResponse, PlantDetailResponse
from ..utils.auth import get_current_user

router = APIRouter(prefix="/api/plants", tags=["Plantas"])


@router.get("/", response_model=List[PlantResponse])
async def get_plants(
    location: Optional[str] = Query(None, description="Filtrar por ubicación"),
    search: Optional[str] = Query(None, description="Buscar por nombre"),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener todas las plantas del usuario.
    
    Soporta filtrado por ubicación y búsqueda por nombre.
    """
    query = db.query(Plant).filter(
        Plant.user_id == current_user.id,
        Plant.is_active == True,
    )

    if location:
        query = query.filter(Plant.location == location)
    if search:
        query = query.filter(Plant.common_name.ilike(f"%{search}%"))

    plants = query.order_by(Plant.created_at.desc()).all()
    return [PlantResponse.model_validate(p) for p in plants]


@router.get("/locations")
async def get_plant_locations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener las ubicaciones con cantidad de plantas.
    
    Para la vista 'Mis Plantas' organizada por ubicación.
    """
    plants = db.query(Plant).filter(
        Plant.user_id == current_user.id,
        Plant.is_active == True,
    ).all()

    locations = {}
    for plant in plants:
        loc = plant.location.value if plant.location else "Otro"
        if loc not in locations:
            locations[loc] = {"name": loc, "count": 0, "plants": []}
        locations[loc]["count"] += 1
        locations[loc]["plants"].append(PlantResponse.model_validate(plant))

    return list(locations.values())


@router.get("/{plant_id}", response_model=PlantDetailResponse)
async def get_plant(
    plant_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Obtener detalle completo de una planta."""
    plant = db.query(Plant).filter(
        Plant.id == plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Planta no encontrada",
        )

    return PlantDetailResponse.model_validate(plant)


@router.post("/upload-image")
async def upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    """Sube una imagen local de la planta y devuelve la URL estática."""
    os.makedirs("static/images", exist_ok=True)
    # Generar un nombre único para evitar colisiones
    ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"plant_{uuid.uuid4().hex[:8]}.{ext}"
    path = f"static/images/{filename}"
    
    with open(path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    return {"image_url": f"/{path}"}


@router.post("/", response_model=PlantDetailResponse, status_code=status.HTTP_201_CREATED)
async def create_plant(
    plant_data: PlantCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Crear una nueva planta."""
    
    # === LÓGICA DE AUTO-COMPLETADO BOTÁNICO SIMULADO ===
    name_lower = plant_data.common_name.lower()
    tipo = plant_data.plant_type or "Follaje"
    
    if "orquidea" in name_lower or "orquídea" in name_lower:
        plant_data.toxicity = "No Tóxica"
        plant_data.care_difficulty = "Avanzado"
        plant_data.sun_exposure = "Luz indirecta brillante"
        plant_data.soil_type = "Corteza especial"
        plant_data.soil_ph_min = 5.5
        plant_data.soil_ph_max = 6.5
        plant_data.max_size = "Hasta 30 cm"
        plant_data.watering_frequency = "Semanal (sumergir)"
        plant_data.hardiness_zones = "10 - 12"
        plant_data.description = "Planta epífita tropical conocida por sus hermosas flores de larga duración."
    elif "oregano" in name_lower or "orégano" in name_lower:
        plant_data.toxicity = "No Tóxica (Comestible)"
        plant_data.care_difficulty = "Fácil"
        plant_data.sun_exposure = "Sol directo"
        plant_data.soil_type = "Franco arenoso"
        plant_data.soil_ph_min = 6.0
        plant_data.soil_ph_max = 8.0
        plant_data.max_size = "Hasta 45 cm"
        plant_data.watering_frequency = "Cuando la tierra seque"
        plant_data.hardiness_zones = "5 - 10"
        plant_data.description = "Hierba perenne aromática muy usada en la cocina mediterránea."
    elif "zabila" in name_lower or "sábila" in name_lower or "aloe" in name_lower:
        plant_data.toxicity = "Leve a mascotas"
        plant_data.care_difficulty = "Muy Fácil"
        plant_data.sun_exposure = "Parcial a directo"
        plant_data.soil_type = "Tierra para cactus"
        plant_data.soil_ph_min = 7.0
        plant_data.soil_ph_max = 8.5
        plant_data.max_size = "Hasta 60 cm"
        plant_data.watering_frequency = "Cada 3 semanas"
        plant_data.hardiness_zones = "9 - 11"
        plant_data.description = "Planta suculenta medicinal conocida por el gel refrescante en sus hojas."
    elif tipo == "Suculento":
        plant_data.soil_type = "Suelo arenoso bien drenado"
        plant_data.soil_ph_min = 6.0
        plant_data.soil_ph_max = 7.0
        plant_data.max_size = "Variado"
        plant_data.hardiness_zones = "9 - 11"
        plant_data.description = "Planta con tejidos engrosados para retener agua."
    else:
        plant_data.soil_type = "Suelo universal estándar"
        plant_data.soil_ph_min = 6.0
        plant_data.soil_ph_max = 7.5
        plant_data.description = f"Planta de la clasificación {tipo}."

    new_plant = Plant(**plant_data.model_dump(), user_id=current_user.id)
    db.add(new_plant)
    db.commit()
    db.refresh(new_plant)

    return PlantDetailResponse.model_validate(new_plant)


@router.put("/{plant_id}", response_model=PlantDetailResponse)
async def update_plant(
    plant_id: int,
    plant_data: PlantUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Actualizar información de una planta."""
    plant = db.query(Plant).filter(
        Plant.id == plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Planta no encontrada",
        )

    update_data = plant_data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(plant, field, value)

    db.commit()
    db.refresh(plant)
    return PlantDetailResponse.model_validate(plant)


@router.delete("/{plant_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_plant(
    plant_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Eliminar una planta (soft delete)."""
    plant = db.query(Plant).filter(
        Plant.id == plant_id,
        Plant.user_id == current_user.id,
    ).first()

    if not plant:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Planta no encontrada",
        )

    plant.is_active = False
    db.commit()
