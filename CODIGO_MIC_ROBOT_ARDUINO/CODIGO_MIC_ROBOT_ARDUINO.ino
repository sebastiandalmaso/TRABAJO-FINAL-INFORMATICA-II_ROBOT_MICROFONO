#include <AccelStepper.h>

// Pines RAMPS 1.4
#define X_STEP_PIN 54
#define X_DIR_PIN 55
#define X_ENABLE_PIN 38
#define X_MIN_PIN 3

#define Y_STEP_PIN 60
#define Y_DIR_PIN 61
#define Y_ENABLE_PIN 56
#define Y_MIN_PIN 14

// Configuración motores
#define MAX_SPEED 2000
#define ACCELERATION 500
#define STEP_INCREMENT 400

AccelStepper motorX(AccelStepper::DRIVER, X_STEP_PIN, X_DIR_PIN);
AccelStepper motorY(AccelStepper::DRIVER, Y_STEP_PIN, Y_DIR_PIN);

bool calibradoX = false;
bool calibradoY = false;
bool calibrandoX = false;
bool calibrandoY = false;
int etapaCalibracion = 0;

void setup() {
  Serial.begin(9600);
  
  // Configurar pines enable
  pinMode(X_ENABLE_PIN, OUTPUT);
  pinMode(Y_ENABLE_PIN, OUTPUT);
  digitalWrite(X_ENABLE_PIN, LOW); // Habilitar motores
  digitalWrite(Y_ENABLE_PIN, LOW);
  
  // Configurar fin de carrera
  pinMode(X_MIN_PIN, INPUT_PULLUP);
  pinMode(Y_MIN_PIN, INPUT_PULLUP);
  
  // Configurar motores
  motorX.setMaxSpeed(MAX_SPEED);
  motorX.setAcceleration(ACCELERATION);
  motorY.setMaxSpeed(MAX_SPEED);
  motorY.setAcceleration(ACCELERATION);
}

void calibrarMotor(AccelStepper &motor, int pinFinCarrera, bool &calibrado) {
  motor.setSpeed(-600); // Velocidad hacia el fin de carrera
  
  while (digitalRead(pinFinCarrera) == HIGH) {
    motor.runSpeed();
  }
  
  motor.setCurrentPosition(0);
  motor.moveTo(200); // Separarse un poco del fin de carrera
  motor.runToPosition();
  motor.setCurrentPosition(0);
  
  calibrado = true;
}

void loop() {
  if (Serial.available() > 0) {
    char comando = Serial.read();
    
    switch (comando) {
      case 'C': // Calibrar motor X
        calibrarMotor(motorX, X_MIN_PIN, calibradoX);
        Serial.println("X Calibrado");
        break;
        
      case 'F': // Calibrar motor Y
        calibrarMotor(motorY, Y_MIN_PIN, calibradoY);
        Serial.println("Y Calibrado");
        break;
        
      case 'A': // Motor X adelante
        if (calibradoX) motorX.move(STEP_INCREMENT);
        break;
        
      case 'B': // Motor X atrás
        if (calibradoX) motorX.move(-STEP_INCREMENT);
        break;
        
      case 'D': // Motor Y adelante
        if (calibradoY) motorY.move(STEP_INCREMENT);
        break;
        
      case 'E': // Motor Y atrás
        if (calibradoY) motorY.move(-STEP_INCREMENT);
        break;
    }
  }
  
  // Ejecutar movimientos
  motorX.run();
  motorY.run();
}