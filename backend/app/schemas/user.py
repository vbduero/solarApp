# ============================================================
# Solar-Grow - Schemas de Usuario
# ============================================================
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime


class UserCreate(BaseModel):
    """Schema para registro de usuario."""
    email: EmailStr
    password: str
    full_name: Optional[str] = None
    city: Optional[str] = "Neiva"

class UserUpdate(BaseModel):
    """Schema para actualizar perfil."""
    full_name: Optional[str] = None
    city: Optional[str] = None
    avatar_url: Optional[str] = None


class UserLogin(BaseModel):
    """Schema para inicio de sesión."""
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    """Schema de respuesta de usuario."""
    id: int
    email: str
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    city: Optional[str] = None
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True


class Token(BaseModel):
    """Schema de token JWT."""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class TokenData(BaseModel):
    """Datos extraídos del token."""
    user_id: Optional[int] = None
