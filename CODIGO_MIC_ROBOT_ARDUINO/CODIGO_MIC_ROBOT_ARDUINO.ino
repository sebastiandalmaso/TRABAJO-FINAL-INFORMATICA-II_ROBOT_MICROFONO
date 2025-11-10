/*
 * RobotMicrofono.ino
 * 
 * Sketch principal para control de robot de posicionamiento de micrófono
 * 
 * Trabajo Final Informática II - UTN FRM
 * Autor: Dalmaso Sebastián Martín
 * Legajo: 50864
 * Año: 2025
 * 
 * Este sketch utiliza la librería RobotMicrofonoControl para
 * gestionar todo el sistema de forma modular y organizada.
 * 
 * Hardware requerido:
 * - Arduino Mega 2560
 * - RAMPS 1.4
 * - 2 Motores paso a paso NEMA 17
 * - 2 Drivers A4988 o DRV8825
 * - 2 Finales de carrera
 * - Sensor DHT11
 * 
 * Conexiones según librería (ver RobotMicrofonoControl.h)
 */

// Incluir la librería personalizada
#include "RobotMicrofonoControl.h"

// ============================================
// INSTANCIAS GLOBALES
// ============================================

// Controlador principal del robot (motores y calibración)
ControladorRobot robot;

// Sensor de temperatura y humedad
// Parámetros: pin, tipo, intervalo de lectura (ms)
SensorAmbiental sensorDHT(DHTPIN, DHTTYPE, 3000);

// ============================================
// SETUP - Configuración inicial
// ============================================

void setup() {
  // Iniciar comunicación serial a 9600 baudios
  // Esta velocidad debe coincidir con Processing
  Serial.begin(9600);
  
  // Esperar un momento para estabilizar la comunicación
  delay(100);
  
  // Inicializar el controlador del robot
  // Configura pines, velocidades y límites
  robot.iniciar();
  
  // Inicializar el sensor de temperatura y humedad
  sensorDHT.iniciar();
  
  // Mensaje de bienvenida
  Serial.println("=========================================");
  Serial.println("Robot Microfono - Sistema Iniciado");
  Serial.println("Esperando comandos desde Processing...");
  Serial.println("=========================================");
}

// ============================================
// LOOP - Bucle principal
// ============================================

void loop() {
  // 1. Procesar comandos recibidos por serial desde Processing
  //    Comandos: C, F, A, B, D, E, P, G:x,y
  robot.procesarComando();
  
  // 2. Actualizar sensores ambientales
  //    Lee temperatura y humedad cada 3 segundos
  //    Envía datos automáticamente a Processing
  sensorDHT.actualizar();
  
  // 3. Actualizar estado de los motores
  //    Ejecuta los pasos necesarios para alcanzar posición objetivo
  //    Debe llamarse continuamente para movimientos suaves
  robot.actualizar();
  
  // El loop se ejecuta continuamente sin delays
  // para mantener el control preciso de los motores
}