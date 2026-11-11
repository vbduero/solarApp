# ============================================================
# Solar-Grow - Router de Integración Hardware (ESP8266 & PC Webcam)
# ============================================================
# Incluye: Sensores ESP8266 (DHT11, Humedad suelo), Cámara PC, y Diagnóstico IA con Gemini
# ============================================================
import base64
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
from google import genai
from ..config import get_settings
from ..utils.hardware_helper import obtener_datos_actuales, capturar_foto_webcam

router = APIRouter(prefix="/api/hardware", tags=["Hardware ESP8266 & Webcam"])


@router.get("/clima-actual")
def obtener_clima():
    """
    Flutter llama a este endpoint para obtener los datos
    del ESP8266 por puerto serial en tiempo real.
    """
    datos = obtener_datos_actuales()
    
    # Mostrar en terminal para verificación
    print(f"--- [HARDWARE ESP8266 SERIAL] ---")
    print(f"Conexión: {datos['status_conexion']}")
    print(f"Temperatura: {datos['temperatura']} °C")
    print(f"Humedad Aire: {datos['humedad_aire']} %")
    print(f"Humedad Suelo: {datos['humedad_suelo']}% (Raw: {datos['humedad_suelo_raw']})")
    print(f"LED (Bomba): {'ENCENDIDO' if datos['led_encendido'] else 'APAGADO'}")
    print(f"---------------------------------")
    
    return {
        "estado_conexion": datos["status_conexion"],
        "temperatura": datos["temperatura"],
        "humedad": datos["humedad_aire"],  # Compatibilidad
        "humedad_aire": datos["humedad_aire"],
        "humedad_suelo": datos["humedad_suelo"],
        "humedad_suelo_raw": datos["humedad_suelo_raw"],
        "led_encendido": datos["led_encendido"]
    }


@router.get("/vista-cultivo")
def obtener_foto():
    """
    Captura una foto de la webcam del computador y la envía a Flutter.
    """
    try:
        foto_bytes = capturar_foto_webcam()
        return Response(content=foto_bytes, media_type="image/jpeg")
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error al capturar foto de la webcam: {str(e)}"
        )


@router.get("/diagnostico-ia")
def diagnostico_ia():
    """
    🧠 DIAGNÓSTICO CON INTELIGENCIA ARTIFICIAL REAL
    1. Captura la imagen en vivo usando la webcam del computador
    2. La envía a Google Gemini (Visión Computacional)
    3. Gemini analiza plagas, enfermedades, estrés hídrico, etc.
    4. Devuelve el diagnóstico real al frontend
    """
    # --- Paso 1: Obtener la imagen de la cámara del computador ---
    try:
        imagen_bytes = capturar_foto_webcam()
        
        # Guardar la imagen capturada para que el frontend la pueda mostrar estáticamente
        try:
            import os
            os.makedirs("static", exist_ok=True)
            with open("static/ultimo_diagnostico.jpg", "wb") as f:
                f.write(imagen_bytes)
            print("[HARDWARE] Foto de diagnóstico guardada en static/ultimo_diagnostico.jpg")
        except Exception as save_err:
            print(f"[HARDWARE] Error al guardar la foto en static: {save_err}")
            
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"No se pudo capturar la foto de la cámara del computador: {str(e)}"
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

        # Incluir datos de sensores en tiempo real para un diagnóstico más rico
        datos_sensor = obtener_datos_actuales()
        contexto_sensores = f"""
        DATOS EN TIEMPO REAL DE LOS SENSORES IoT (ESP8266):
        - Humedad del suelo: {datos_sensor['humedad_suelo']}%
        - Temperatura ambiente: {datos_sensor['temperatura']}°C
        - Humedad del aire: {datos_sensor['humedad_aire']}%
        - Bomba de riego: {'ACTIVA (regando)' if datos_sensor['led_encendido'] else 'Inactiva'}
        - Estado de conexión: {datos_sensor['status_conexion']}
        """

        # El prompt para la IA
        prompt = f"""
        Eres un experto fitopatólogo e ingeniero agrónomo especializado en 
        diagnóstico visual de cultivos y plantas ornamentales.
        
        Analiza esta imagen de una planta capturada por una estación IoT 
        inteligente (Solar-Grow) y responde EN ESPAÑOL con el siguiente 
        formato exacto (usa estos encabezados tal cual):

        {contexto_sensores}

        ESTADO GENERAL: (Saludable / Estrés leve / Estrés moderado / Crítico)
        Incluye una evaluación basada tanto en la imagen como en los datos 
        de los sensores IoT.
        
        PLAGAS DETECTADAS: (Nombre de la plaga o "Ninguna detectada". 
        Si detectas algo, indica el nivel de confianza en porcentaje)
        
        ENFERMEDADES: (Nombre de la enfermedad o "Ninguna detectada".
        Incluye posibles hongos, virus, bacterias visibles)
        
        SALUD FOLIAR: (Describe el color, turgencia y aspecto de las hojas)
        
        ESTRÉS HÍDRICO: (¿Muestra signos de falta o exceso de agua? 
        Correlaciona con el dato de humedad del suelo: {datos_sensor['humedad_suelo']}%)
        
        RECOMENDACIONES: (Lista 2-3 acciones específicas que el usuario 
        debe tomar basándose en lo que observas en la imagen Y los datos 
        de los sensores. Por ejemplo, si la humedad del suelo es baja, 
        recomienda riego. Si la temperatura es alta, recomienda sombra.)
        
        Sé preciso y profesional. Si la imagen no muestra una planta 
        claramente, indica lo que observas y sugiere mejorar el ángulo 
        de la cámara para que apunte directamente a la planta.
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
                    "diagnostico": texto_analisis,
                    "url_imagen": "/static/ultimo_diagnostico.jpg"
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
