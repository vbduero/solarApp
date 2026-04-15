# ============================================================
# Solar-Grow - Router de Integración Hardware (Raspberry Pi)
# ============================================================
# Incluye: Sensores DHT22, Cámara, y Diagnóstico IA con Gemini
# ============================================================
import base64
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
import requests
from google import genai
from ..config import get_settings

router = APIRouter(prefix="/api/hardware", tags=["Hardware Raspberry Pi"])

# IMPORTANTE
URL_RASPBERRY = "http://192.168.1.9:8000"


@router.get("/clima-actual")
def obtener_clima():
    """
    Flutter llama a este endpoint y nosotros (el backend)
    vamos rápidamente a la Raspberry a sacar los datos en tiempo real.
    """
    try:
        # Timeout para no bloquear la app si la Raspberry no está
        res = requests.get(f"{URL_RASPBERRY}/sensor", timeout=2)
        datos = res.json()
        if datos.get("status") == "success":
            temp = datos.get("temperatura")
            hum = datos.get("humedad")
            
            # Mostrar en terminal para verificación del usuario
            print(f"--- [HARDWARE RASPBERRY PI] ---")
            print(f"Temperatura: {temp} °C | Humedad (DHT22): {hum} %")
            print(f"-------------------------------")
            
            return {
                "estado_conexion": "En línea",
                "temperatura": temp,
                "humedad": hum
            }
        else:
            raise HTTPException(
                status_code=503,
                detail="Sensor ocupado en la Raspberry: " + datos.get("mensaje", "")
            )
    except Exception as e:
        raise HTTPException(
            status_code=504,
            detail=f"Sin conexión con Raspberry Pi en {URL_RASPBERRY}. Verifica que esté encendida."
        )


@router.get("/vista-cultivo")
def obtener_foto():
    """
    El backend descarga la foto de la Raspberry y se la reenvía
    automáticamente a Flutter como si fuera una imagen local.
    """
    try:
        res = requests.get(f"{URL_RASPBERRY}/camara", timeout=3)
        if res.status_code == 200:
            # Reenviamos los bytes directitos de la imagen a la App Móvil
            return Response(content=res.content, media_type="image/jpeg")
        else:
            raise HTTPException(
                status_code=500,
                detail="Fallo tomando foto en la estación"
            )
    except Exception as e:
        raise HTTPException(
            status_code=504,
            detail="Error de conexión con la cámara"
        )


@router.get("/diagnostico-ia")
def diagnostico_ia():
    """
    🧠 DIAGNÓSTICO CON INTELIGENCIA ARTIFICIAL REAL
    1. Captura la imagen en vivo de la Raspberry Pi
    2. La envía a Google Gemini (Visión Computacional)
    3. Gemini analiza plagas, enfermedades, estrés hídrico, etc.
    4. Devuelve el diagnóstico real al frontend
    """
    # --- Paso 1: Obtener la imagen de la cámara ---
    try:
        res = requests.get(f"{URL_RASPBERRY}/camara", timeout=5)
        if res.status_code != 200:
            raise HTTPException(
                status_code=500,
                detail="No se pudo capturar la foto de la cámara."
            )
        imagen_bytes = res.content
    except requests.exceptions.RequestException as e:
        raise HTTPException(
            status_code=504,
            detail=f"No se pudo conectar con la cámara de la Raspberry Pi: {str(e)}"
        )

    # --- Paso 2: Verificar API Key ---
    settings = get_settings()
    if not settings.GEMINI_API_KEY:
        raise HTTPException(
            status_code=500,
            detail="No se ha configurado la API Key de Gemini. "
                   "Configura la variable de entorno GEMINI_API_KEY."
        )

    # --- Paso 3: Enviar la imagen a Google Gemini para análisis ---
    try:
        client = genai.Client(api_key=settings.GEMINI_API_KEY)

        # El prompt para la IA
        prompt = """
        Eres un experto fitopatólogo e ingeniero agrónomo especializado en 
        diagnóstico visual de cultivos y plantas ornamentales.
        
        Analiza esta imagen de una planta capturada por una estación IoT 
        inteligente (Solar-Grow) y responde EN ESPAÑOL con el siguiente 
        formato exacto (usa estos encabezados tal cual):

        ESTADO GENERAL: (Saludable / Estrés leve / Estrés moderado / Crítico)
        
        PLAGAS DETECTADAS: (Nombre de la plaga o "Ninguna detectada". 
        Si detectas algo, indica el nivel de confianza en porcentaje)
        
        ENFERMEDADES: (Nombre de la enfermedad o "Ninguna detectada".
        Incluye posibles hongos, virus, bacterias visibles)
        
        SALUD FOLIAR: (Describe el color, turgencia y aspecto de las hojas)
        
        ESTRÉS HÍDRICO: (¿Muestra signos de falta o exceso de agua?)
        
        RECOMENDACIONES: (Lista 2-3 acciones específicas que el usuario 
        debe tomar basándose en lo que observas en la imagen)
        
        Sé preciso y profesional. Si la imagen no muestra una planta 
        claramente, indica lo que observas y sugiere mejorar el ángulo 
        de la cámara.
        """

        # Creamos el contenido con la imagen en base64
        imagen_base64 = base64.b64encode(imagen_bytes).decode("utf-8")

        contenido = [
            {
                "role": "user",
                "parts": [
                    {"text": prompt},
                    {
                        "inline_data": {
                            "mime_type": "image/jpeg",
                            "data": imagen_base64
                        }
                    }
                ]
            }
        ]

        # Intentar con varios modelos en caso de que uno tenga cuota agotada
        modelos = ["gemini-2.5-flash", "gemini-2.0-flash-lite", "gemini-2.0-flash"]
        ultimo_error = None

        for modelo in modelos:
            try:
                import time
                response = client.models.generate_content(
                    model=modelo,
                    contents=contenido
                )
                # --- Paso 4: Procesar la respuesta de Gemini ---
                texto_analisis = response.text

                return {
                    "status": "success",
                    "modelo_ia": f"Google {modelo} (Visión)",
                    "diagnostico": texto_analisis
                }
            except Exception as model_error:
                ultimo_error = model_error
                # Si es error de cuota (429), esperar e intentar el siguiente modelo
                if "429" in str(model_error) or "RESOURCE_EXHAUSTED" in str(model_error):
                    time.sleep(2)  # Esperar 2 segundos antes de intentar otro modelo
                    continue
                else:
                    raise  # Si es otro tipo de error, lanzar inmediatamente

        # Si ningún modelo funcionó
        raise HTTPException(
            status_code=429,
            detail=f"Todos los modelos de IA están temporalmente ocupados. "
                   f"Espera 1 minuto e inténtalo de nuevo. Último error: {str(ultimo_error)}"
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al procesar con Inteligencia Artificial: {str(e)}"
        )
