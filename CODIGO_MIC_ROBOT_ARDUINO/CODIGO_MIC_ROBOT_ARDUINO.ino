#include <AccelStepper.h>
#include <DHT.h>

// Pines RAMPS 1.4
#define X_STEP_PIN 54
#define X_DIR_PIN 55
#define X_ENABLE_PIN 38
#define X_MIN_PIN 3

#define Y_STEP_PIN 60
#define Y_DIR_PIN 61
#define Y_ENABLE_PIN 56
#define Y_MIN_PIN 14

// Pin sensor DHT11
#define DHTPIN 32
#define DHTTYPE DHT11

// Configuración motores
#define MAX_SPEED 2000
#define ACCELERATION 500
#define STEP_INCREMENT 400

// LÍMITES MÁXIMOS FIJOS
const long LIMITE_MAX_X = 27000;
const long LIMITE_MAX_Y = 17000;

AccelStepper motorX(AccelStepper::DRIVER, X_STEP_PIN, X_DIR_PIN);
AccelStepper motorY(AccelStepper::DRIVER, Y_STEP_PIN, Y_DIR_PIN);

bool calibradoX = false;
bool calibradoY = false;

// Clase para manejar el sensor DHT11
class SensorAmbiental {
private:
  DHT dht;
  unsigned long ultimaLectura;
  unsigned long intervalo;
  float temperatura;
  float humedad;
  float sensacionTermica;
  bool lecturaValida;

public:
  SensorAmbiental(uint8_t pin, uint8_t tipo, unsigned long intervaloMs = 3000) 
    : dht(pin, tipo), intervalo(intervaloMs) {
    temperatura = 0;
    humedad = 0;
    sensacionTermica = 0;
    lecturaValida = false;
    ultimaLectura = 0;
  }

  void iniciar() {
    dht.begin();
  }

  void actualizar() {
    unsigned long tiempoActual = millis();
    
    if (tiempoActual - ultimaLectura >= intervalo) {
      ultimaLectura = tiempoActual;
      
      float h = dht.readHumidity();
      float t = dht.readTemperature();
      
      if (isnan(h) || isnan(t)) {
        lecturaValida = false;
        Serial.println("DHT:ERROR");
      } else {
        humedad = h;
        temperatura = t;
        sensacionTermica = dht.computeHeatIndex(t, h, false);
        lecturaValida = true;
        enviarDatos();
      }
    }
  }

  void enviarDatos() {
    if (lecturaValida) {
      Serial.print("DHT:");
      Serial.print(temperatura, 1);
      Serial.print(",");
      Serial.print(humedad, 1);
      Serial.print(",");
      Serial.println(sensacionTermica, 1);
    }
  }

  float getTemperatura() { return temperatura; }
  float getHumedad() { return humedad; }
  float getSensacionTermica() { return sensacionTermica; }
  bool esValida() { return lecturaValida; }
};

// Crear instancia del sensor
SensorAmbiental sensorDHT(DHTPIN, DHTTYPE, 3000);

void setup() {
  Serial.begin(9600);
  
  // Configurar pines enable
  pinMode(X_ENABLE_PIN, OUTPUT);
  pinMode(Y_ENABLE_PIN, OUTPUT);
  digitalWrite(X_ENABLE_PIN, LOW);
  digitalWrite(Y_ENABLE_PIN, LOW);
  
  // Configurar fin de carrera
  pinMode(X_MIN_PIN, INPUT_PULLUP);
  pinMode(Y_MIN_PIN, INPUT_PULLUP);
  
  // Configurar motores
  motorX.setMaxSpeed(MAX_SPEED);
  motorX.setAcceleration(ACCELERATION);
  motorY.setMaxSpeed(MAX_SPEED);
  motorY.setAcceleration(ACCELERATION);
  
  // Iniciar sensor DHT11
  sensorDHT.iniciar();
  
  Serial.println("Sistema iniciado");
  Serial.print("Limites: X=");
  Serial.print(LIMITE_MAX_X);
  Serial.print(" Y=");
  Serial.println(LIMITE_MAX_Y);
}

void calibrarMotor(AccelStepper &motor, int pinFinCarrera, bool &calibrado) {
  motor.setSpeed(-600);
  
  while (digitalRead(pinFinCarrera) == HIGH) {
    motor.runSpeed();
  }
  
  motor.setCurrentPosition(0);
  motor.moveTo(200);
  motor.runToPosition();
  motor.setCurrentPosition(0);
  
  calibrado = true;
}

void moverAPosicion(long targetX, long targetY) {
  Serial.print("DEBUG: Recibido comando mover a X:");
  Serial.print(targetX);
  Serial.print(" Y:");
  Serial.println(targetY);
  
  // Verificar límites antes de mover
  if (targetX < 0 || targetX > LIMITE_MAX_X) {
    Serial.print("ERROR: X fuera de límites (0-");
    Serial.print(LIMITE_MAX_X);
    Serial.println(")");
    return;
  }
  
  if (targetY < 0 || targetY > LIMITE_MAX_Y) {
    Serial.print("ERROR: Y fuera de límites (0-");
    Serial.print(LIMITE_MAX_Y);
    Serial.println(")");
    return;
  }
  
  if (calibradoX && calibradoY) {
    motorX.moveTo(targetX);
    motorY.moveTo(targetY);
    Serial.print("MOVIENDO:");
    Serial.print(targetX);
    Serial.print(",");
    Serial.println(targetY);
  } else {
    Serial.println("ERROR:Motores no calibrados");
    if (!calibradoX) Serial.println("ERROR:Motor X no calibrado");
    if (!calibradoY) Serial.println("ERROR:Motor Y no calibrado");
  }
}

void procesarComando() {
  if (Serial.available() > 0) {
    String comando = Serial.readStringUntil('\n');
    comando.trim();
    
    if (comando.length() == 0) return;
    
    char cmd = comando.charAt(0);
    
    switch (cmd) {
      case 'C': // Calibrar motor X
        calibrarMotor(motorX, X_MIN_PIN, calibradoX);
        Serial.println("X Calibrado");
        break;
        
      case 'F': // Calibrar motor Y
        calibrarMotor(motorY, Y_MIN_PIN, calibradoY);
        Serial.println("Y Calibrado");
        break;
        
      case 'A': // Motor X adelante
        if (calibradoX) {
          long nuevaPosX = motorX.currentPosition() + STEP_INCREMENT;
          if (nuevaPosX <= LIMITE_MAX_X) {
            motorX.move(STEP_INCREMENT);
          } else {
            Serial.println("LIMITE: X en máximo");
          }
        }
        break;
        
      case 'B': // Motor X atrás
        if (calibradoX) {
          long nuevaPosX = motorX.currentPosition() - STEP_INCREMENT;
          if (nuevaPosX >= 0) {
            motorX.move(-STEP_INCREMENT);
          } else {
            Serial.println("LIMITE: X en mínimo");
          }
        }
        break;
        
      case 'D': // Motor Y adelante
        if (calibradoY) {
          long nuevaPosY = motorY.currentPosition() + STEP_INCREMENT;
          if (nuevaPosY <= LIMITE_MAX_Y) {
            motorY.move(STEP_INCREMENT);
          } else {
            Serial.println("LIMITE: Y en máximo");
          }
        }
        break;
        
      case 'E': // Motor Y atrás
        if (calibradoY) {
          long nuevaPosY = motorY.currentPosition() - STEP_INCREMENT;
          if (nuevaPosY >= 0) {
            motorY.move(-STEP_INCREMENT);
          } else {
            Serial.println("LIMITE: Y en mínimo");
          }
        }
        break;
        
      case 'P': // Enviar posición actual
        Serial.print("POS:");
        Serial.print(motorX.currentPosition());
        Serial.print(",");
        Serial.println(motorY.currentPosition());
        break;
        
      case 'S': // Solicitar datos del sensor manualmente
        sensorDHT.enviarDatos();
        break;
        
      case 'G': // Ir a posición específica (formato: G:x,y)
        if (comando.indexOf(':') > 0) {
          String coords = comando.substring(2);
          coords.trim();
          int comaPos = coords.indexOf(',');
          
          Serial.print("DEBUG: Comando G recibido: ");
          Serial.println(comando);
          Serial.print("DEBUG: Coordenadas extraídas: ");
          Serial.println(coords);
          
          if (comaPos > 0) {
            String strX = coords.substring(0, comaPos);
            String strY = coords.substring(comaPos + 1);
            strX.trim();
            strY.trim();
            
            long targetX = strX.toInt();
            long targetY = strY.toInt();
            
            Serial.print("DEBUG: X=");
            Serial.print(targetX);
            Serial.print(" Y=");
            Serial.println(targetY);
            
            moverAPosicion(targetX, targetY);
          } else {
            Serial.println("ERROR: Formato incorrecto, falta coma");
          }
        } else {
          Serial.println("ERROR: Formato incorrecto, falta ':'");
        }
        break;
    }
  }
}

void loop() {
  // Procesar comandos seriales
  procesarComando();
  
  // Actualizar sensor DHT11 (lectura automática cada 3 segundos)
  sensorDHT.actualizar();
  
  // Ejecutar movimientos de motores
  motorX.run();
  motorY.run();
}