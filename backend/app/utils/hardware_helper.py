# ============================================================
# Solar-Grow - Utilidades de Hardware (ESP8266 Serial & Webcam)
# ============================================================
import re
import time
import threading
import serial
import serial.tools.list_ports
import cv2
from datetime import datetime, timezone
from ..database import SessionLocal
from ..models.plant import Plant
from ..models.sensor_data import SensorData

# Variables globales para almacenar los últimos datos leídos del ESP8266
LATEST_DATA = {
    "temperatura": 25.0,
    "humedad_aire": 50.0,
    "humedad_suelo_raw": 500,
    "humedad_suelo": 50.0,
    "led_encendido": False,
    "recorded_at": None,
    "status_conexion": "Desconectado"
}

# Hilos y control de ejecución
_serial_thread = None
_stop_event = threading.Event()
_lock = threading.Lock()
_ser_device = None  # Objeto de conexión serial activo globalmente

# Configuración del mapeo del sensor de humedad capacitivo
# Seco suele ser alrededor de 750-800, Húmedo alrededor de 350
VALOR_SECO = 780
VALOR_HUMEDO = 350

# Última vez que se guardó en base de datos para no saturarla
_ultima_insercion_db = 0
INTERVALO_INSERCION_DB = 60  # segundos (1 minuto)

def iniciar_lectura_serial(port="COM3", baudrate=115200):
    """Inicia el hilo de fondo para leer datos del puerto serial."""
    global _serial_thread, _stop_event
    
    _stop_event.clear()
    _serial_thread = threading.Thread(
        target=_background_serial_reader,
        args=(port, baudrate),
        daemon=True,
        name="ESP8266SerialReader"
    )
    _serial_thread.start()
    print(f"[HARDWARE] Hilo de lectura serial iniciado en {port}...")

def detener_lectura_serial():
    """Detiene el hilo de fondo de lectura serial."""
    global _stop_event, _serial_thread
    _stop_event.set()
    if _serial_thread:
        _serial_thread.join(timeout=2)
        print("[HARDWARE] Hilo de lectura serial detenido.")

def enviar_comando_serial(comando: str):
    """Envía un comando de texto al ESP8266 por el puerto serial."""
    global _ser_device
    with _lock:
        if _ser_device and _ser_device.is_open:
            try:
                _ser_device.write((comando + "\n").encode('utf-8'))
                _ser_device.flush()
                print(f"[ESP8266 SERIAL] Comando enviado exitosamente: {comando}")
                return True
            except Exception as e:
                print(f"[ESP8266 SERIAL] Error al enviar comando serial: {e}")
        else:
            print("[ESP8266 SERIAL] Intento de enviar comando pero el dispositivo no está conectado.")
        return False

def obtener_datos_actuales():
    """Retorna una copia segura de los últimos datos recibidos."""
    with _lock:
        return LATEST_DATA.copy()

def capturar_foto_webcam():
    """
    Captura una imagen usando la cámara del computador en tiempo real.
    Ideal para reemplazar el endpoint de la Raspberry Pi.
    Incluye warmup extendido para que la cámara ajuste exposición
    y no devuelva frames negros en Windows.
    """
    import numpy as np
    
    # 0 es el índice de la cámara predeterminada del computador
    # Usamos cv2.CAP_DSHOW en Windows para que inicialice más rápido
    cap = cv2.VideoCapture(0, cv2.CAP_DSHOW)
    if not cap.isOpened():
        # Reintento sin DSHOW por si acaso
        cap = cv2.VideoCapture(0)
        
    if not cap.isOpened():
        print("[CAMARA] No se pudo acceder a la cámara del computador.")
        raise Exception("No se pudo acceder a la cámara del computador. Verifica si está conectada u ocupada.")
        
    try:
        # Configurar resolución 720p para mejor calidad de imagen
        cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        
        # Warmup extendido: leer muchos frames para que la cámara ajuste
        # la exposición automática (en Windows esto suele necesitar ~15-30 frames)
        print("[CAMARA] Calentando cámara (ajuste de exposición)...")
        for i in range(30):
            cap.read()
            time.sleep(0.05)  # 50ms entre frames = ~1.5s total de warmup
            
        # Intentar capturar un frame con buena iluminación (hasta 5 intentos)
        frame = None
        for intento in range(5):
            ret, candidate = cap.read()
            if not ret:
                time.sleep(0.1)
                continue
                
            # Verificar que el frame no sea completamente negro
            brightness = np.mean(candidate)
            if brightness > 10:  # Umbral mínimo de brillo (0-255)
                frame = candidate
                print(f"[CAMARA] Frame capturado OK (brillo promedio: {brightness:.1f}, intento {intento+1})")
                break
            else:
                print(f"[CAMARA] Frame demasiado oscuro (brillo: {brightness:.1f}), reintentando...")
                time.sleep(0.2)
        
        if frame is None:
            # Último intento: tomar lo que sea
            ret, frame = cap.read()
            if not ret or frame is None:
                print("[CAMARA] Error al capturar el frame después de todos los intentos.")
                raise Exception("No se pudo obtener imagen de la cámara.")
            
        # Codificar el frame como JPEG con calidad alta
        encode_params = [cv2.IMWRITE_JPEG_QUALITY, 90]
        success, jpeg_bytes = cv2.imencode('.jpg', frame, encode_params)
        if not success:
            raise Exception("Error al codificar imagen a JPEG.")
        
        print(f"[CAMARA] Imagen capturada exitosamente ({len(jpeg_bytes)} bytes)")
        return jpeg_bytes.tobytes()
    finally:
        cap.release()

def _background_serial_reader(port, baudrate):
    """Función de lectura en bucle que se ejecuta en segundo plano."""
    global _ultima_insercion_db, _ser_device
    
    re_suelo = re.compile(r"Humedad suelo:\s*(\d+)")
    re_temp = re.compile(r"Temperatura:\s*([\d.]+)")
    re_hum = re.compile(r"Humedad ambiente:\s*([\d.]+)")
    re_raw = re.compile(r"Valor analogico:\s*(\d+)")
    
    while not _stop_event.is_set():
        ser = None
        try:
            # Intentar abrir puerto serial
            ser = serial.Serial(port, baudrate, timeout=1)
            
            with _lock:
                LATEST_DATA["status_conexion"] = "En línea"
                _ser_device = ser
                
            print(f"[ESP8266 SERIAL] Conectado exitosamente al puerto {port}")
            
            # Limpiar buffers de entrada
            ser.reset_input_buffer()
            
            while not _stop_event.is_set():
                if ser.in_waiting > 0:
                    try:
                        line = ser.readline().decode('utf-8', errors='ignore').strip()
                        if not line:
                            continue
                            
                        # Buscar patrones en la salida serial
                        m_suelo = re_suelo.search(line)
                        m_temp = re_temp.search(line)
                        m_hum = re_hum.search(line)
                        m_raw = re_raw.search(line)
                        
                        cambio = False
                        with _lock:
                            if m_raw:
                                LATEST_DATA["humedad_suelo_raw"] = int(m_raw.group(1))
                                cambio = True

                            if m_suelo:
                                # El Arduino ya envía el porcentaje de humedad del suelo directamente
                                porcentaje = float(m_suelo.group(1))
                                LATEST_DATA["humedad_suelo"] = max(0.0, min(100.0, round(porcentaje, 1)))
                                cambio = True
                                
                            if m_temp:
                                LATEST_DATA["temperatura"] = float(m_temp.group(1))
                                cambio = True
                                
                            if m_hum:
                                LATEST_DATA["humedad_aire"] = float(m_hum.group(1))
                                cambio = True
                                
                            if "LED ENCENDIDO" in line or "BOMBA ENCENDIDO" in line:
                                LATEST_DATA["led_encendido"] = True
                                cambio = True
                                
                            if "LED APAGADO" in line or "BOMBA APAGADO" in line:
                                LATEST_DATA["led_encendido"] = False
                                cambio = True
                                
                            if cambio:
                                LATEST_DATA["recorded_at"] = datetime.now(timezone.utc)
                                
                        # Guardar periódicamente en base de datos si cambiaron los datos
                        if cambio and (time.time() - _ultima_insercion_db > INTERVALO_INSERCION_DB):
                            _guardar_datos_en_db()
                            _ultima_insercion_db = time.time()
                            
                    except Exception as line_error:
                        print(f"[ESP8266 SERIAL] Error procesando línea: {line_error}")
                        
                time.sleep(0.1)
                
        except serial.SerialException as se:
            with _lock:
                LATEST_DATA["status_conexion"] = "Desconectado"
                
            print(f"[ESP8266 SERIAL] No se pudo conectar al puerto {port}. Error: {se}")
            # Mostrar puertos COM disponibles
            ports = [p.device for p in serial.tools.list_ports.comports()]
            if ports:
                print(f"[ESP8266 SERIAL] Puertos seriales detectados en el sistema: {ports}")
                # Si port no está en la lista de puertos activos pero hay otros, probamos el primero que esté libre en la siguiente vuelta
                if port not in ports:
                    print(f"Se sugiere cambiar el puerto a uno de los activos en el archivo .env o usar el puerto detectado: {ports[0]}")
            else:
                print("[ESP8266 SERIAL] No se detecto ningun puerto serial (USB) conectado!")
                
            # Reintentar conexión en 5 segundos
            for _ in range(5):
                if _stop_event.is_set():
                    break
                time.sleep(1)
        finally:
            if ser and ser.is_open:
                ser.close()
                print(f"[ESP8266 SERIAL] Puerto {port} cerrado.")
            with _lock:
                _ser_device = None

def _guardar_datos_en_db():
    """Inserta la lectura actual en la base de datos de PostgreSQL."""
    db = SessionLocal()
    try:
        # Obtener la primera planta disponible en el sistema
        plant = db.query(Plant).first()
        if not plant:
            print("[HARDWARE DB] No hay ninguna planta registrada en la base de datos. Saltando guardado.")
            return
            
        with _lock:
            temp = LATEST_DATA["temperatura"]
            hum_aire = LATEST_DATA["humedad_aire"]
            hum_suelo = LATEST_DATA["humedad_suelo"]
            led_on = LATEST_DATA["led_encendido"]
            
        # Crear registro de datos
        nuevo_registro = SensorData(
            plant_id=plant.id,
            temperature=temp,
            air_humidity=hum_aire,
            soil_humidity=hum_suelo,
            light_level=85.0, # Por ahora valor estático para luz
            solar_voltage=12.4,
            solar_power=8.0,
            battery_level=95.0,
            pump_active=1 if led_on else 0,
            source="esp8266",
            recorded_at=datetime.now(timezone.utc)
        )
        
        db.add(nuevo_registro)
        db.commit()
        print(f"[HARDWARE DB] Lectura guardada para planta {plant.common_name} (ID {plant.id}): Temp={temp}C, HumSuelo={hum_suelo}%")
    except Exception as e:
        db.rollback()
        print(f"[HARDWARE DB] Error al guardar datos del sensor en BD: {e}")
    finally:
        db.close()
