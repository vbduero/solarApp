/*
   ============================================================
   PROYECTO MACETA INTELIGENTE - ESP8266 NodeMCU
   ============================================================

   COMPONENTES:
   - ESP8266 NodeMCU
   - Sensor humedad suelo capacitivo v2.0 (A0)
   - Sensor DHT11 (D4)
   - Optoacoplador CW401 + MOSFET IRFZ44N (D1)
   - LED Indicador y Mini bomba de agua (Controlados por D1)

   FUNCIONAMIENTO:
   - Lee la humedad del suelo y convierte a porcentaje de manera local.
   - Lee temperatura y humedad ambiente del DHT11.
   - Riego automático con protecciones:
       * Enciende si la humedad baja de 40 % y apaga al llegar a 50 % (histéresis).
       * Cada riego automático dura como máximo MAX_RIEGO_AUTO_MS.
       * Entre riegos automáticos espera PAUSA_ENTRE_RIEGOS_MS para que el
         agua se absorba y el sensor refleje el cambio.
       * No riega hasta tener una lectura válida ni durante los primeros
         ESPERA_ARRANQUE_MS tras un reinicio.
       * Si la lectura del sensor está fuera de rango (desconectado o en
         corto), el riego automático queda bloqueado.
   - Comandos seriales enviados por el servidor Python de solarApp:
       * "WATER:<segundos>"  riego manual (máximo MAX_RIEGO_MANUAL_S).
       * "STOP"              apaga la bomba de inmediato.
   - Envía los datos formateados por Serial cada 2 segundos sin bloquear el CPU.

   ============================================================
*/

#include <DHT.h>

// =======================
// CONFIGURACION DHT11
// =======================
#define DHTPIN D4
#define DHTTYPE DHT11

DHT dht(DHTPIN, DHTTYPE);

// =======================
// SENSOR HUMEDAD SUELO
// =======================
#define SOIL_PIN A0

// =======================
// LED / MOSFET (BOMBA)
// =======================
#define LED_PIN D1

// =======================
// CALIBRACION SENSOR
// =======================
// Sensor totalmente al aire (seco) -> valor alto
// Sensor sumergido en agua (húmedo) -> valor bajo
const int valorSeco = 780;
const int valorHumedo = 350;

// Lecturas fuera de este rango no son físicamente posibles con el sensor
// conectado: se tratan como falla (cable suelto, corto, sin alimentación).
const int RAW_MIN_VALIDO = 150;
const int RAW_MAX_VALIDO = 950;

// =======================
// PARAMETROS DE RIEGO
// =======================
const int UMBRAL_ENCENDER = 40;   // % - por debajo se inicia el riego automático
const int UMBRAL_APAGAR = 50;     // % - al alcanzarlo se detiene el riego automático

const unsigned long MAX_RIEGO_AUTO_MS = 10000UL;        // 10 s máximo por riego automático
const unsigned long PAUSA_ENTRE_RIEGOS_MS = 300000UL;   // 5 min entre riegos automáticos
const unsigned long ESPERA_ARRANQUE_MS = 30000UL;       // 30 s sin riego automático tras reiniciar
const int MAX_RIEGO_MANUAL_S = 60;                      // tope del comando WATER

// Variables de sensores
int humedadSueloRaw = 0;
int porcentajeHumedad = 0;
float temperatura = 0.0;
float humedadAire = 0.0;
bool lecturaSueloValida = false;  // true cuando ya hay una lectura confiable
bool sensorSueloEnFalla = false;

// Estado del riego manual remoto (serial)
bool riegoManualActivo = false;
unsigned long inicioRiegoManual = 0;
unsigned long duracionRiegoManualMs = 0;

// Estado del riego automático
bool riegoAutoActivo = false;
unsigned long inicioRiegoAuto = 0;
bool huboRiegoAuto = false;
unsigned long finUltimoRiegoAuto = 0;

// Estado real de la salida
bool bombaEncendida = false;

// Temporizadores no bloqueantes
unsigned long ultimoEnvioSensores = 0;
const unsigned long intervaloSensores = 2000; // Enviar datos cada 2000 ms (2 segundos)

// Promedia varias muestras para reducir el ruido del ADC
int leerHumedadSueloRaw() {
  long suma = 0;
  for (int i = 0; i < 5; i++) {
    suma += analogRead(SOIL_PIN);
    delay(2);
  }
  return (int)(suma / 5);
}

void leerSensorSuelo() {
  humedadSueloRaw = leerHumedadSueloRaw();
  sensorSueloEnFalla = (humedadSueloRaw < RAW_MIN_VALIDO || humedadSueloRaw > RAW_MAX_VALIDO);

  // Mapear el valor analógico crudo al rango porcentual de 0 a 100
  porcentajeHumedad = map(humedadSueloRaw, valorSeco, valorHumedo, 0, 100);
  porcentajeHumedad = constrain(porcentajeHumedad, 0, 100);

  lecturaSueloValida = !sensorSueloEnFalla;
}

void detenerRiegoAuto(const char* motivo) {
  if (!riegoAutoActivo) return;
  riegoAutoActivo = false;
  huboRiegoAuto = true;
  finUltimoRiegoAuto = millis();
  Serial.print("RIEGO AUTOMATICO DETENIDO: ");
  Serial.println(motivo);
}

// Aplica el estado deseado al pin y avisa al backend solo cuando cambia
void aplicarEstadoBomba() {
  bool deseada = riegoAutoActivo || riegoManualActivo;
  if (deseada != bombaEncendida) {
    bombaEncendida = deseada;
    digitalWrite(LED_PIN, bombaEncendida ? HIGH : LOW);
    Serial.println(bombaEncendida ? "BOMBA ENCENDIDO" : "BOMBA APAGADO");
  }
}

void procesarComando(String comando) {
  comando.trim();

  // El backend envía el comando en formato WATER:<segundos>
  if (comando.startsWith("WATER:")) {
    int duracionSegundos = comando.substring(6).toInt();
    if (duracionSegundos > 0) {
      if (duracionSegundos > MAX_RIEGO_MANUAL_S) {
        duracionSegundos = MAX_RIEGO_MANUAL_S;
      }
      riegoManualActivo = true;
      inicioRiegoManual = millis();
      duracionRiegoManualMs = (unsigned long)duracionSegundos * 1000UL;
      Serial.print("COMANDO RECIBIDO -> REGAR POR ");
      Serial.print(duracionSegundos);
      Serial.println(" SEGUNDOS");
    }
  } else if (comando == "STOP") {
    riegoManualActivo = false;
    detenerRiegoAuto("comando STOP");
    Serial.println("COMANDO RECIBIDO -> DETENER RIEGO");
  }
}

void setup() {
  // Asegurar la bomba apagada antes de configurar el pin como salida
  digitalWrite(LED_PIN, LOW);
  pinMode(LED_PIN, OUTPUT);
  digitalWrite(LED_PIN, LOW);

  // Inicialización de la comunicación serial
  Serial.begin(115200);
  Serial.setTimeout(100); // No bloquear el loop esperando un comando incompleto

  // Inicializar sensor DHT
  dht.begin();

  Serial.println("====================================");
  Serial.println("SISTEMA MACETA INTELIGENTE INICIADO");
  Serial.println("====================================");
  Serial.println("BOMBA APAGADO");
}

void loop() {
  unsigned long tiempoActual = millis();

  // 1. LEER Y PROCESAR COMANDOS SERIALES (RIEGO MANUAL / STOP)
  if (Serial.available() > 0) {
    procesarComando(Serial.readStringUntil('\n'));
  }

  // 2. VERIFICAR SI TERMINÓ EL RIEGO MANUAL
  if (riegoManualActivo && (tiempoActual - inicioRiegoManual >= duracionRiegoManualMs)) {
    riegoManualActivo = false;
    Serial.println("RIEGO MANUAL FINALIZADO");
  }

  // 3. LÍMITE DE TIEMPO DEL RIEGO AUTOMÁTICO (se revisa en cada vuelta)
  if (riegoAutoActivo && (tiempoActual - inicioRiegoAuto >= MAX_RIEGO_AUTO_MS)) {
    detenerRiegoAuto("tiempo maximo alcanzado");
  }

  // 4. LECTURA DE SENSORES, DECISIÓN DE RIEGO Y ENVÍO DE DATOS (CADA 2 SEGUNDOS)
  if (tiempoActual - ultimoEnvioSensores >= intervaloSensores) {
    ultimoEnvioSensores = tiempoActual;

    leerSensorSuelo();

    // Lectura de temperatura y humedad ambiente
    float tempRead = dht.readTemperature();
    float humRead = dht.readHumidity();

    // Comprobar lecturas válidas del sensor DHT11
    if (!isnan(tempRead)) {
      temperatura = tempRead;
    }
    if (!isnan(humRead)) {
      humedadAire = humRead;
    }

    // --- Decisión de riego automático ---
    if (riegoAutoActivo) {
      if (sensorSueloEnFalla) {
        detenerRiegoAuto("falla del sensor de suelo");
      } else if (porcentajeHumedad >= UMBRAL_APAGAR) {
        detenerRiegoAuto("humedad recuperada");
      }
    } else {
      bool arranqueCumplido = tiempoActual >= ESPERA_ARRANQUE_MS;
      bool pausaCumplida = !huboRiegoAuto ||
                           (tiempoActual - finUltimoRiegoAuto >= PAUSA_ENTRE_RIEGOS_MS);

      if (lecturaSueloValida && arranqueCumplido && pausaCumplida &&
          porcentajeHumedad < UMBRAL_ENCENDER) {
        riegoAutoActivo = true;
        inicioRiegoAuto = tiempoActual;
        Serial.println("RIEGO AUTOMATICO INICIADO: tierra seca");
      }
    }

    // Imprimir los datos en consola en el formato exacto que espera el backend de Python
    Serial.println("================================");
    Serial.print("Valor analogico: ");
    Serial.println(humedadSueloRaw);

    Serial.print("Humedad suelo: ");
    Serial.print(porcentajeHumedad);
    Serial.println(" %");

    Serial.print("Temperatura: ");
    Serial.print(temperatura);
    Serial.println(" °C");

    Serial.print("Humedad ambiente: ");
    Serial.print(humedadAire);
    Serial.println(" %");

    if (sensorSueloEnFalla) {
      Serial.println("ALERTA: sensor de suelo fuera de rango, riego automatico bloqueado");
    }

    // Estado de la bomba para que el backend lo actualice en tiempo real
    bool deseada = riegoAutoActivo || riegoManualActivo;
    Serial.println(deseada ? "BOMBA ENCENDIDO" : "BOMBA APAGADO");
    Serial.println("================================");
  }

  // 5. APLICAR EL ESTADO FINAL A LA BOMBA
  aplicarEstadoBomba();
}
