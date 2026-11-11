# ============================================================
# Solar-Grow - Servicio de subida de imágenes
# ============================================================
# Valida las imágenes que suben los usuarios (plantas y avatares)
# antes de guardarlas en static/.
# ============================================================
import os
import uuid
from typing import Optional

from fastapi import HTTPException, UploadFile

# Tamaño máximo de una imagen subida
MAX_IMAGE_BYTES = 8 * 1024 * 1024  # 8 MB


def detect_image_extension(content: bytes) -> Optional[str]:
    """Devuelve la extensión real de la imagen según sus primeros bytes.

    No se confía en el nombre ni en el Content-Type que envía el cliente.
    Devuelve None si el contenido no es JPEG, PNG ni WebP.
    """
    if content.startswith(b"\xff\xd8\xff"):
        return "jpg"
    if content.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png"
    if content[:4] == b"RIFF" and content[8:12] == b"WEBP":
        return "webp"
    return None


def save_uploaded_image(file: UploadFile, directory: str, prefix: str) -> str:
    """Valida y guarda una imagen subida. Devuelve la ruta relativa del archivo.

    Lanza HTTPException 413 si supera MAX_IMAGE_BYTES y 400 si está vacía o
    no es una imagen JPEG, PNG o WebP.
    """
    # Leer un byte de más permite detectar el exceso sin cargar todo el archivo
    content = file.file.read(MAX_IMAGE_BYTES + 1)

    if len(content) > MAX_IMAGE_BYTES:
        raise HTTPException(
            status_code=413,
            detail=f"La imagen supera el tamaño máximo de {MAX_IMAGE_BYTES // (1024 * 1024)} MB",
        )
    if not content:
        raise HTTPException(status_code=400, detail="El archivo está vacío")

    extension = detect_image_extension(content)
    if extension is None:
        raise HTTPException(
            status_code=400,
            detail="Formato no permitido: la imagen debe ser JPEG, PNG o WebP",
        )

    os.makedirs(directory, exist_ok=True)
    # La extensión sale del contenido y el nombre es aleatorio: el nombre
    # original del cliente nunca se usa en la ruta
    path = f"{directory}/{prefix}_{uuid.uuid4().hex[:8]}.{extension}"
    with open(path, "wb") as image_file:
        image_file.write(content)
    return path
