/*
* RobotMicrofonoControl.cpp
* 
* Implementación de la librería de control de robot
* Contiene toda la lógica de funcionamiento del sistema
*/

#include "RobotMicrofonoControl.h"

// ============================================
// IMPLEMENTACIÓN DE SensorAmbiental
// ============================================

/**
* Constructor: Inicializa el sensor DHT y variables internas
*/
SensorAmbiental::SensorAmbiental(uint8_t pin, uint8_t tipo, unsigned long intervaloMs) 
	: dht(pin, tipo), intervalo(intervaloMs) {
	temperatura = 0;
	humedad = 0;
	sensacionTermica = 0;
	lecturaValida = false;
	ultimaLectura = 0;
}

/**
* Inicializa la comunicación con el sensor DHT
*/
void SensorAmbiental::iniciar() {
	dht.begin();
}

/**
* Actualiza periódicamente los datos del sensor
* Solo lee cuando ha transcurrido el intervalo configurado
*/
void SensorAmbiental::actualizar() {
	unsigned long tiempoActual = millis();
	
	// Verificar si es momento de leer el sensor
	if (tiempoActual - ultimaLectura >= intervalo) {
		ultimaLectura = tiempoActual;
		
		// Leer humedad y temperatura
		float h = dht.readHumidity();
		float t = dht.readTemperature();
		
		// Verificar si la lectura es válida
		if (isnan(h) || isnan(t)) {
			lecturaValida = false;
			Serial.println("DHT:ERROR");
		} else {
			// Actualizar valores y calcular sensación térmica
			humedad = h;
			temperatura = t;
			sensacionTermica = dht.computeHeatIndex(t, h, false);
			lecturaValida = true;
			enviarDatos();
		}
	}
}

/**
* Envía los datos del sensor por puerto serial
* Formato: DHT:temperatura,humedad,sensacionTermica
*/
void SensorAmbiental::enviarDatos() {
	if (lecturaValida) {
		Serial.print("DHT:");
		Serial.print(temperatura, 1);
		Serial.print(",");
		Serial.print(humedad, 1);
		Serial.print(",");
		Serial.println(sensacionTermica, 1);
	}
}

// ============================================
// IMPLEMENTACIÓN DE ControladorRobot
// ============================================

/**
* Constructor: Inicializa los motores con configuración DRIVER
* (1 pin para STEP, 1 pin para DIR)
*/
ControladorRobot::ControladorRobot() 
	: motorX(AccelStepper::DRIVER, X_STEP_PIN, X_DIR_PIN),
	motorY(AccelStepper::DRIVER, Y_STEP_PIN, Y_DIR_PIN) {
	calibradoX = false;
	calibradoY = false;
	estadoActual = INICIALIZANDO;  // Estado inicial
}

/**
* Inicializa todo el sistema de control de motores
* Configura pines, velocidades y aceleraciones
*/
void ControladorRobot::iniciar() {
	// Configurar pines de habilitación (enable) de los drivers
	pinMode(X_ENABLE_PIN, OUTPUT);
	pinMode(Y_ENABLE_PIN, OUTPUT);
	digitalWrite(X_ENABLE_PIN, LOW);  // LOW = motor habilitado
	digitalWrite(Y_ENABLE_PIN, LOW);  // LOW = motor habilitado
	
	// Configurar pines de finales de carrera con pull-up interno
	pinMode(X_MIN_PIN, INPUT_PULLUP);
	pinMode(Y_MIN_PIN, INPUT_PULLUP);
	
	// Configurar parámetros de movimiento del motor X
	motorX.setMaxSpeed(MAX_SPEED);
	motorX.setAcceleration(ACCELERATION);
	
	// Configurar parámetros de movimiento del motor Y
	motorY.setMaxSpeed(MAX_SPEED);
	motorY.setAcceleration(ACCELERATION);
	
	// Mensaje de inicio en el monitor serial
	Serial.println("Sistema iniciado");
	Serial.print("Limites: X=");
	Serial.print(LIMITE_MAX_X);
	Serial.print(" Y=");
	Serial.println(LIMITE_MAX_Y);
	
	// Transicionar a estado de espera de calibración
	cambiarEstado(ESPERANDO_CALIBRACION);
}

/**
* Actualiza el estado de los motores
* Ejecuta un paso del movimiento si hay movimiento pendiente
* Debe llamarse continuamente en el loop
*/
void ControladorRobot::actualizar() {
	motorX.run();  // Ejecuta un paso del motor X si es necesario
	motorY.run();  // Ejecuta un paso del motor Y si es necesario
	
	// Actualizar máquina de estados
	actualizarEstado();
}

/**
* Actualiza la máquina de estados del robot
* Gestiona transiciones automáticas según el estado actual
*/
void ControladorRobot::actualizarEstado() {
	switch (estadoActual) {
	case INICIALIZANDO:
		// Transición automática manejada en iniciar()
		break;
		
	case ESPERANDO_CALIBRACION:
		// Espera comando 'C' desde Processing
		// No hay transición automática
		break;
		
	case CALIBRANDO_X:
		// Si X terminó de calibrar, pasar automáticamente a calibrar Y
		if (calibradoX) {
			cambiarEstado(CALIBRANDO_Y);
		}
		break;
		
	case CALIBRANDO_Y:
		// Si Y terminó de calibrar, pasar a operacional
		if (calibradoY) {
			cambiarEstado(OPERACIONAL);
		}
		break;
		
	case OPERACIONAL:
		// Verificar si hay movimiento en progreso
		if (motorX.distanceToGo() != 0 || motorY.distanceToGo() != 0) {
			cambiarEstado(MOVIENDO);
		}
		break;
		
	case MOVIENDO:
		// Si llegó a destino, volver a operacional
		if (motorX.distanceToGo() == 0 && motorY.distanceToGo() == 0) {
			cambiarEstado(OPERACIONAL);
		}
		break;
		
	case ERROR_ESTADO:
		// Estado de error, requiere reinicio manual
		break;
	}
}

/**
* Cambia el estado del robot y notifica por serial
*/
void ControladorRobot::cambiarEstado(EstadoRobot nuevoEstado) {
	if (estadoActual != nuevoEstado) {
		estadoActual = nuevoEstado;
		Serial.print("ESTADO:");
		Serial.println(getNombreEstado());
	}
}

/**
* Obtiene el nombre del estado actual como string
*/
String ControladorRobot::getNombreEstado() {
	switch (estadoActual) {
	case INICIALIZANDO: return "INICIALIZANDO";
	case ESPERANDO_CALIBRACION: return "ESPERANDO_CALIBRACION";
	case CALIBRANDO_X: return "CALIBRANDO_X";
	case CALIBRANDO_Y: return "CALIBRANDO_Y";
	case OPERACIONAL: return "OPERACIONAL";
	case MOVIENDO: return "MOVIENDO";
	case ERROR_ESTADO: return "ERROR";
	default: return "DESCONOCIDO";
	}
}

/**
* Calibra un motor llevándolo hasta el final de carrera
* y estableciendo ese punto como posición cero
*/
void ControladorRobot::calibrarMotor(AccelStepper &motor, int pinFinCarrera, bool &calibrado) {
	Serial.println("Iniciando calibracion de motor...");
	
	// Establecer velocidad constante de retroceso
	motor.setSpeed(CALIBRATION_SPEED);
	
	// Retroceder hasta que se active el final de carrera
	// (HIGH = no activado, LOW = activado con pull-up)
	while (digitalRead(pinFinCarrera) == HIGH) {
		motor.runSpeed();
	}
	
	Serial.println("Final de carrera alcanzado");
	
	// Establecer posición actual como cero
	motor.setCurrentPosition(0);
	
	// Avanzar un poco para liberar el final de carrera
	motor.moveTo(CALIBRATION_OFFSET);
	motor.runToPosition();
	
	// Re-establecer posición cero después del offset
	motor.setCurrentPosition(0);
	
	// Marcar como calibrado
	calibrado = true;
	
	Serial.println("Motor calibrado exitosamente");
}

/**
* Mueve ambos motores a una posición específica
* Verifica que las coordenadas estén dentro de los límites
*/
void ControladorRobot::moverAPosicion(long targetX, long targetY) {
	Serial.print("DEBUG: Recibido comando mover a X:");
	Serial.print(targetX);
	Serial.print(" Y:");
	Serial.println(targetY);
	
	// Verificar que X esté dentro de límites
	if (targetX < 0 || targetX > LIMITE_MAX_X) {
		Serial.print("ERROR: X fuera de límites (0-");
		Serial.print(LIMITE_MAX_X);
		Serial.println(")");
		return;
	}
	
	// Verificar que Y esté dentro de límites
	if (targetY < 0 || targetY > LIMITE_MAX_Y) {
		Serial.print("ERROR: Y fuera de límites (0-");
		Serial.print(LIMITE_MAX_Y);
		Serial.println(")");
		return;
	}
	
	// Verificar que ambos motores estén calibrados
	if (calibradoX && calibradoY) {
		// Establecer posiciones objetivo
		motorX.moveTo(targetX);
		motorY.moveTo(targetY);
		
		Serial.print("MOVIENDO:");
		Serial.print(targetX);
		Serial.print(",");
		Serial.println(targetY);
	} else {
		// Error: motores no calibrados
		Serial.println("ERROR:Motores no calibrados");
		if (!calibradoX) Serial.println("ERROR:Motor X no calibrado");
		if (!calibradoY) Serial.println("ERROR:Motor Y no calibrado");
	}
}

/**
* Envía la posición actual por puerto serial
*/
void ControladorRobot::enviarPosicion() {
	Serial.print("POS:");
	Serial.print(motorX.currentPosition());
	Serial.print(",");
	Serial.println(motorY.currentPosition());
}

/**
* Procesa comandos recibidos desde la interfaz Processing
* Lee comandos del buffer serial y ejecuta las acciones correspondientes
*/
void ControladorRobot::procesarComando() {
	// Verificar si hay datos disponibles en el puerto serial
	if (Serial.available() > 0) {
		// Leer comando hasta el salto de línea
		String comando = Serial.readStringUntil('\n');
		comando.trim();  // Eliminar espacios en blanco
		
		// Ignorar comandos vacíos
		if (comando.length() == 0) return;
		
		// Obtener el primer carácter como código de comando
		char cmd = comando.charAt(0);
		
		// Procesar según el comando recibido
		switch (cmd) {
		case 'C': // Calibrar motor X
			// Solo permitir calibración en estado apropiado
			if (estadoActual == ESPERANDO_CALIBRACION || estadoActual == OPERACIONAL) {
				cambiarEstado(CALIBRANDO_X);
				calibrarMotor(motorX, X_MIN_PIN, calibradoX);
				Serial.println("X Calibrado");
			} else {
				Serial.println("ERROR: No se puede calibrar en estado actual");
			}
			break;
			
		case 'F': // Calibrar motor Y
			// Este comando generalmente se llama automáticamente
			if (estadoActual == CALIBRANDO_Y || estadoActual == OPERACIONAL) {
				cambiarEstado(CALIBRANDO_Y);
				calibrarMotor(motorY, Y_MIN_PIN, calibradoY);
				Serial.println("Y Calibrado");
			} else {
				Serial.println("ERROR: No se puede calibrar Y en estado actual");
			}
			break;
			
		case 'A': // Motor X adelante (incrementar posición)
			if (estadoActual == OPERACIONAL || estadoActual == MOVIENDO) {
				if (calibradoX) {
					long nuevaPosX = motorX.currentPosition() + STEP_INCREMENT;
					// Verificar límite máximo
					if (nuevaPosX <= LIMITE_MAX_X) {
						motorX.move(STEP_INCREMENT);
					} else {
						Serial.println("LIMITE: X en máximo");
					}
				}
			} else {
				Serial.println("ERROR: Sistema no operacional");
			}
			break;
			
		case 'B': // Motor X atrás (decrementar posición)
			if (estadoActual == OPERACIONAL || estadoActual == MOVIENDO) {
				if (calibradoX) {
					long nuevaPosX = motorX.currentPosition() - STEP_INCREMENT;
					// Verificar límite mínimo
					if (nuevaPosX >= 0) {
						motorX.move(-STEP_INCREMENT);
					} else {
						Serial.println("LIMITE: X en mínimo");
					}
				}
			} else {
				Serial.println("ERROR: Sistema no operacional");
			}
			break;
			
		case 'D': // Motor Y adelante (incrementar posición)
			if (estadoActual == OPERACIONAL || estadoActual == MOVIENDO) {
				if (calibradoY) {
					long nuevaPosY = motorY.currentPosition() + STEP_INCREMENT;
					// Verificar límite máximo
					if (nuevaPosY <= LIMITE_MAX_Y) {
						motorY.move(STEP_INCREMENT);
					} else {
						Serial.println("LIMITE: Y en máximo");
					}
				}
			} else {
				Serial.println("ERROR: Sistema no operacional");
			}
			break;
			
		case 'E': // Motor Y atrás (decrementar posición)
			if (estadoActual == OPERACIONAL || estadoActual == MOVIENDO) {
				if (calibradoY) {
					long nuevaPosY = motorY.currentPosition() - STEP_INCREMENT;
					// Verificar límite mínimo
					if (nuevaPosY >= 0) {
						motorY.move(-STEP_INCREMENT);
					} else {
						Serial.println("LIMITE: Y en mínimo");
					}
				}
			} else {
				Serial.println("ERROR: Sistema no operacional");
			}
			break;
			
		case 'P': // Enviar posición actual
			enviarPosicion();
			break;
			
		case 'G': // Ir a posición específica (formato: G:x,y)
			// Solo permitir movimiento en estado operacional
			if (estadoActual == OPERACIONAL || estadoActual == MOVIENDO) {
				if (comando.indexOf(':') > 0) {
					// Extraer coordenadas después de ':'
					String coords = comando.substring(2);
					coords.trim();
					int comaPos = coords.indexOf(',');
					
					Serial.print("DEBUG: Comando G recibido: ");
					Serial.println(comando);
					Serial.print("DEBUG: Coordenadas extraídas: ");
					Serial.println(coords);
					
					// Verificar formato correcto (debe tener coma)
					if (comaPos > 0) {
						// Separar X e Y
						String strX = coords.substring(0, comaPos);
						String strY = coords.substring(comaPos + 1);
						strX.trim();
						strY.trim();
						
						// Convertir a números
						long targetX = strX.toInt();
						long targetY = strY.toInt();
						
						Serial.print("DEBUG: X=");
						Serial.print(targetX);
						Serial.print(" Y=");
						Serial.println(targetY);
						
						// Ejecutar movimiento
						moverAPosicion(targetX, targetY);
					} else {
						Serial.println("ERROR: Formato incorrecto, falta coma");
					}
				} else {
					Serial.println("ERROR: Formato incorrecto, falta ':'");
				}
			} else {
				Serial.println("ERROR: Sistema no calibrado, no se puede mover");
			}
			break;
			
		default:
			// Comando no reconocido
			Serial.print("ERROR: Comando desconocido: ");
			Serial.println(cmd);
			break;
		}
	}
}
