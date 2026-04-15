# ============================================================
# Solar-Grow - Router de Autenticación
# ============================================================
from fastapi import APIRouter, Depends, HTTPException, status, File, UploadFile
from sqlalchemy.orm import Session
import os
import uuid
import shutil

from ..database import get_db
from ..models.user import User
from ..schemas.user import UserCreate, UserLogin, UserResponse, UserUpdate, Token
from ..utils.auth import hash_password, verify_password, create_access_token, get_current_user

router = APIRouter(prefix="/api/auth", tags=["Autenticación"])


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(user_data: UserCreate, db: Session = Depends(get_db)):
    """Registrar un nuevo usuario en Solar-Grow."""
    # Verificar si el email ya existe
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Ya existe un usuario con este correo electrónico",
        )

    # Crear usuario
    new_user = User(
        email=user_data.email,
        hashed_password=hash_password(user_data.password),
        full_name=user_data.full_name,
        city=user_data.city,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Generar token
    access_token = create_access_token(data={"sub": str(new_user.id)})

    return Token(
        access_token=access_token,
        user=UserResponse.model_validate(new_user),
    )


@router.post("/login", response_model=Token)
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    """Iniciar sesión en Solar-Grow."""
    user = db.query(User).filter(User.email == credentials.email).first()
    if not user or not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Correo o contraseña incorrectos",
        )

    access_token = create_access_token(data={"sub": str(user.id)})

    return Token(
        access_token=access_token,
        user=UserResponse.model_validate(user),
    )


@router.get("/me", response_model=UserResponse)
async def get_me(current_user: User = Depends(get_current_user)):
    """Obtener información del usuario actual."""
    return UserResponse.model_validate(current_user)

@router.put("/me", response_model=UserResponse)
async def update_me(
    user_update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Actualizar perfil del usuario."""
    update_data = user_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(current_user, field, value)
    
    db.commit()
    db.refresh(current_user)
    return UserResponse.model_validate(current_user)

@router.post("/upload-avatar")
async def upload_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    """Sube una foto de perfil y devuelve la URL estática."""
    os.makedirs("static/avatars", exist_ok=True)
    ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"avatar_{uuid.uuid4().hex[:8]}.{ext}"
    path = f"static/avatars/{filename}"
    
    with open(path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    return {"avatar_url": f"/{path}"}
