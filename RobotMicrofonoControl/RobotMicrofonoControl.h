/*
* RobotMicrofonoControl.h
* 
* Librería para control de robot de posicionamiento de micrófono
* Trabajo Final Informática II - UTN FRM
* Autor: Dalmaso Sebastián Martín
* Legajo: 50864
* Año: 2025
* 
* Esta librería encapsula toda la funcionalidad del robot:
* - Control de motores paso a paso con AccelStepper
* - Calibración automática con finales de carrera
* - Lectura de sensor DHT11 (temperatura y humedad)
* - Comunicación serial con Processing
* - Gestión de límites de movimiento
*/

#ifndef ROBOT_MICROFONO_CONTROL_H
#define ROBOT_MICROFONO_CONTROL_H

#include <Arduino.h>
#include <AccelStepper.h>
#include <DHT.h>

// ============================================
// DEFINICIÓN DE PINES RAMPS 1.4
// ============================================

// Pines del Motor X (eje horizontal)
#define X_STEP_PIN 54      // Pin de pulsos de paso
#define X_DIR_PIN 55       // Pin de dirección
#define X_ENABLE_PIN 38    // Pin de habilitación
#define X_MIN_PIN 3        // Pin de final de carrera mínimo

// Pines del Motor Y (eje vertical)
#define Y_STEP_PIN 60      // Pin de pulsos de paso
#define Y_DIR_PIN 61       // Pin de dirección
#define Y_ENABLE_PIN 56    // Pin de habilitación
#define Y_MIN_PIN 14       // Pin de final de carrera mínimo

// Pin del sensor DHT11
#define DHTPIN 32          // Pin de datos del sensor
#define DHTTYPE DHT11      // Tipo de sensor DHT

// ============================================
// CONFIGURACIÓN DE MOTORES
// ============================================

#define MAX_SPEED 2000         // Velocidad máxima en pasos/segundo
#define ACCELERATION 500       // Aceleración en pasos/segundo²
#define STEP_INCREMENT 400     // Incremento de pasos para movimiento manual
#define CALIBRATION_SPEED -600 // Velocidad durante calibración (negativa = retroceso)
#define CALIBRATION_OFFSET 200 // Offset después de tocar final de carrera

// ============================================
// LÍMITES DEL SISTEMA
// ============================================

const long LIMITE_MAX_X = 27000;  // Límite máximo del eje X en pasos
const long LIMITE_MAX_Y = 17000;  // Límite máximo del eje Y en pasos

// ============================================
// CLASE SENSOR AMBIENTAL
// ============================================

/**
* @brief Clase para gestionar el sensor DHT11
* 
* Maneja la lectura automática y periódica del sensor de temperatura
* y humedad, calculando también la sensación térmica.
*/
class SensorAmbiental {
private:
	DHT dht;                          // Objeto DHT de la librería
	unsigned long ultimaLectura;      // Timestamp de última lectura
	unsigned long intervalo;          // Intervalo entre lecturas (ms)
	float temperatura;                // Temperatura actual (°C)
	float humedad;                    // Humedad relativa actual (%)
	float sensacionTermica;           // Índice de calor calculado (°C)
	bool lecturaValida;               // Flag de validez de datos
	
public:
	/**
	* @brief Constructor del sensor ambiental
	* @param pin Pin digital conectado al sensor
	* @param tipo Tipo de sensor DHT (DHT11, DHT22, etc)
	* @param intervaloMs Intervalo entre lecturas en milisegundos
	*/
	SensorAmbiental(uint8_t pin, uint8_t tipo, unsigned long intervaloMs = 3000);
	
	/**
	* @brief Inicializa el sensor DHT
	* Debe llamarse en setup()
	*/
	void iniciar();
	
	/**
	* @brief Actualiza la lectura del sensor si es necesario
	* Debe llamarse en loop() continuamente
	* Lee el sensor solo cuando ha pasado el intervalo configurado
	*/
	void actualizar();
	
	/**
	* @brief Envía los datos del sensor por serial
	* Formato: "DHT:temperatura,humedad,sensacionTermica"
	*/
	void enviarDatos();
	
	// Getters para acceder a los datos
	float getTemperatura() { return temperatura; }
	float getHumedad() { return humedad; }
	float getSensacionTermica() { return sensacionTermica; }
	bool esValida() { return lecturaValida; }
};

// ============================================
// MÁQUINA DE ESTADOS DEL ROBOT
// ============================================

/**
* @brief Estados posibles del sistema
* 
* El robot opera bajo una máquina de estados finitos:
* - INICIALIZANDO: Estado inicial, configurando hardware
* - ESPERANDO_CALIBRACION: Esperando comando de calibración
* - CALIBRANDO_X: Calibrando motor X
* - CALIBRANDO_Y: Calibrando motor Y
* - OPERACIONAL: Sistema calibrado, listo para operar
* - MOVIENDO: Ejecutando movimiento a posición
* - ERROR: Estado de error, requiere reinicio
*/
enum EstadoRobot {
	INICIALIZANDO,
	ESPERANDO_CALIBRACION,
	CALIBRANDO_X,
	CALIBRANDO_Y,
	OPERACIONAL,
	MOVIENDO,
	ERROR_ESTADO
};

// ============================================
// CLASE CONTROLADOR DE ROBOT
// ============================================

/**
* @brief Clase principal para control del robot
* 
* Gestiona los dos motores paso a paso, la calibración,
* movimientos y comunicación serial con la interfaz Processing.
* Implementa máquina de estados finitos para control robusto.
*/
class ControladorRobot {
private:
	AccelStepper motorX;      // Motor del eje X
	AccelStepper motorY;      // Motor del eje Y
	bool calibradoX;          // Flag de calibración del motor X
	bool calibradoY;          // Flag de calibración del motor Y
	EstadoRobot estadoActual; // Estado actual de la máquina de estados
	
	/**
	* @brief Calibra un motor individual usando su final de carrera
	* @param motor Referencia al motor a calibrar
	* @param pinFinCarrera Pin del final de carrera
	* @param calibrado Referencia al flag de calibración
	*/
	void calibrarMotor(AccelStepper &motor, int pinFinCarrera, bool &calibrado);
	
	/**
	* @brief Mueve el robot a una posición específica
	* @param targetX Posición objetivo en X (pasos)
	* @param targetY Posición objetivo en Y (pasos)
	* Verifica límites antes de ejecutar el movimiento
	*/
	void moverAPosicion(long targetX, long targetY);
	
public:
	/**
	* @brief Constructor del controlador
	* Inicializa los motores con sus pines correspondientes
	*/
	ControladorRobot();
	
	/**
	* @brief Inicializa el sistema de motores
	* Configura pines, velocidades y aceleraciones
	* Debe llamarse en setup()
	*/
	void iniciar();
	
	/**
	* @brief Actualiza el estado de los motores
	* Debe llamarse en loop() continuamente
	*/
	void actualizar();
	
	/**
	* @brief Actualiza la máquina de estados del robot
	* Gestiona transiciones automáticas entre estados
	*/
	void actualizarEstado();
	
	/**
	* @brief Cambia el estado del robot
	* @param nuevoEstado Estado al que transicionar
	*/
	void cambiarEstado(EstadoRobot nuevoEstado);
	
	/**
	* @brief Procesa comandos recibidos por serial
	* 
	* Comandos disponibles:
	* - 'C': Calibrar motor X
	* - 'F': Calibrar motor Y
	* - 'A': Mover X adelante (incremento)
	* - 'B': Mover X atrás (decremento)
	* - 'D': Mover Y adelante (incremento)
	* - 'E': Mover Y atrás (decremento)
	* - 'P': Enviar posición actual
	* - 'G:x,y': Ir a posición específica
	*/
	void procesarComando();
	
	/**
	* @brief Obtiene la posición actual del motor X
	* @return Posición en pasos
	*/
	long getPosicionX() { return motorX.currentPosition(); }
	
	/**
	* @brief Obtiene la posición actual del motor Y
	* @return Posición en pasos
	*/
	long getPosicionY() { return motorY.currentPosition(); }
	
	/**
	* @brief Verifica si el motor X está calibrado
	* @return true si está calibrado
	*/
	bool estaCalibradoX() { return calibradoX; }
	
	/**
	* @brief Verifica si el motor Y está calibrado
	* @return true si está calibrado
	*/
	bool estaCalibradoY() { return calibradoY; }
	
	/**
	* @brief Envía la posición actual por serial
	* Formato: "POS:posX,posY"
	*/
	void enviarPosicion();
	
	/**
	* @brief Obtiene el estado actual del robot
	* @return Estado actual
	*/
	EstadoRobot getEstado() { return estadoActual; }
	
	/**
	* @brief Obtiene el nombre del estado actual como string
	* @return Nombre del estado (para debugging)
	*/
	String getNombreEstado();
};

#endif // ROBOT_MICROFONO_CONTROL_H
