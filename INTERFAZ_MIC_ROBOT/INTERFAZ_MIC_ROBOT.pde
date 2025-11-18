/*
 * ============================================================================
 * TRABAJO FINAL - INFORMÁTICA II
 * Robot Controlador de Micrófono con Motores Paso a Paso
 * ============================================================================
 * * Autor: Dalmaso Sebastián Martín
 * Legajo: 50864
 * Ciclo Lectivo: 2025
 * Universidad Tecnológica Nacional - Facultad Regional Mendoza
 * * DESCRIPCIÓN:
 * Este programa controla un sistema robótico de posicionamiento de micrófono
 * mediante dos motores paso a paso (eje X e Y). Incluye:
 * - Sistema de calibración automática
 * - Control manual de los motores
 * - Almacenamiento de posiciones favoritas (slots)
 * - Monitoreo de temperatura y humedad con sensor DHT11
 * - Sistema de registro de eventos (logging)
 * - Movimiento a posiciones aleatorias
 * * COMUNICACIÓN:
 * Se comunica con Arduino mediante puerto serial a 9600 baudios
 * * ============================================================================
 */

import processing.serial.*;  // Librería para comunicación serial con Arduino

// ============================================================================
// VARIABLES GLOBALES DE COMUNICACIÓN
// ============================================================================

Serial puerto;         // Objeto para manejar el puerto serial
boolean conectado = false; // Estado de conexión con Arduino

// ============================================================================
// ESTADOS DE LA APLICACIÓN
// ============================================================================

// Enumeración para los diferentes estados del programa
enum Estado {
  CALIBRANDO,  // Estado inicial: requiere calibración de motores
  OPERACIONAL  // Estado normal: sistema listo para operar
}

Estado estadoActual = Estado.CALIBRANDO; // Comienza en estado de calibración

// ============================================================================
// VARIABLES DE CALIBRACIÓN
// ============================================================================

boolean calibracionIniciada = false; // Indica si el proceso de calibración comenzó
boolean motorXCalibrado = false;     // Indica si el motor X completó su calibración
boolean motorYCalibrado = false;     // Indica si el motor Y completó su calibración
float progresoCalibracion = 0;       // Progreso de calibración (0.0 a 1.0)
String mensajeCalibracion = "Presiona el botón para iniciar"; // Mensaje mostrado durante calibración
Button btnIniciarCalibracion;        // Botón para iniciar el proceso de calibración

// ============================================================================
// LÍMITES MÁXIMOS DE LOS MOTORES
// ============================================================================

// Estos valores representan el máximo de pasos que pueden dar los motores
// Se determinan mediante finales de carrera durante la calibración
final long LIMITE_MAX_X = 27000; // Límite máximo del motor X (pasos)
final long LIMITE_MAX_Y = 17000; // Límite máximo del motor Y (pasos)

// ============================================================================
// VARIABLES DE POSICIÓN
// ============================================================================

long posX = 0; // Posición actual del motor X (en pasos)
long posY = 0; // Posición actual del motor Y (en pasos)

// Variables para posición de imagen (no utilizadas actualmente)
int px, py;
PImage P;  // Imagen del logo de la UTN

// ============================================================================
// VARIABLES DEL SENSOR DHT11 (Temperatura y Humedad)
// ============================================================================

float temperatura = 0;       // Temperatura actual en °C
float humedad = 0;           // Humedad relativa en %
float sensacionTermica = 0;    // Índice de sensación térmica calculado
boolean dhtValido = false;     // Indica si hay datos válidos del sensor

// ============================================================================
// TEMPORIZADOR PARA ACTUALIZACIÓN AUTOMÁTICA
// ============================================================================

int ultimaActualizacion = 0;     // Timestamp de la última actualización
int intervaloActualizacion = 2000; // Intervalo en milisegundos (2 segundos)

// ============================================================================
// LISTA DE POSICIONES GUARDADAS
// ============================================================================

ListaPosiciones listaPosiciones; //  Lista enlazada que almacena las posiciones guardadas

// ============================================================================
// BOTONES DE LA INTERFAZ
// ============================================================================

// Botones de control manual de los motores
Button btnXAdelante; // Mueve motor X hacia adelante
Button btnXAtras;    // Mueve motor X hacia atrás
Button btnYAdelante; // Mueve motor Y hacia adelante
Button btnYAtras;    // Mueve motor Y hacia atrás

// Botón para generar y moverse a posición aleatoria
Button btnPosicionAleatoria;

// Botón para ver el histórico de eventos registrados
Button btnHistoricoEventos;

// ============================================================================
// SISTEMA DE LOGGING (Registro de Eventos)
// ============================================================================

Logger logger; // Objeto que maneja el registro de eventos en archivo CSV

// ============================================================================
// CONTROL DE MOVIMIENTO CONTINUO
// ============================================================================

// Variables para detectar cuando un botón se mantiene presionado
boolean btnXAdelantePresionado = false;
boolean btnXAtrasPresionado = false;
boolean btnYAdelantePresionado = false;
boolean btnYAtrasPresionado = false;

int ultimoEnvioMovimiento = 0;   // Timestamp del último comando enviado
int intervaloMovimiento = 100;     // Intervalo mínimo entre comandos (ms)

// ============================================================================
// ARCHIVOS DE ALMACENAMIENTO
// ============================================================================

final String ARCHIVO_SLOTS = "slots_posiciones.dat"; // Archivo para guardar posiciones

// ============================================================================
// FUNCIÓN SETUP - SE EJECUTA UNA VEZ AL INICIO
// ============================================================================

void setup() {
  // Configurar tamaño de la ventana
  size(1220, 650);
  
  // Intentar cargar el logo de la UTN
  // Si no existe el archivo, continúa sin él
  try {
    P = loadImage("utn_logo.png");
  } catch (Exception e) {
    println("Advertencia: No se pudo cargar utn_logo.png"); // 🟡 Advertencia
    P = null;
  }
  
  // ============================================================================
  // INICIALIZAR SISTEMA DE LOGGING
  // ============================================================================
  
  logger = new Logger("historico_eventos.csv");
  logger.registrarEvento("INICIO", "Aplicación iniciada"); //  Evento
  
  // ============================================================================
  // INICIALIZAR LISTA DE POSICIONES (6 SLOTS)
  // ============================================================================
  
  listaPosiciones = new ListaPosiciones(6); //  Inicializa la lista enlazada
  
  // Intentar cargar posiciones guardadas previamente
  listaPosiciones.cargarDesdeArchivo(ARCHIVO_SLOTS);
  
  // ============================================================================
  // CONECTAR CON ARDUINO
  // ============================================================================
  
  try {
    // Mostrar puertos disponibles en la consola
    println("Puertos disponibles:");
    printArray(Serial.list());
    
    // Intentar conectar al primer puerto disponible a 9600 baudios
    puerto = new Serial(this, Serial.list()[0], 9600);
    puerto.bufferUntil('\n'); // Leer hasta encontrar salto de línea
    conectado = true;
    
    // Registrar conexión exitosa
    logger.registrarEvento("CONEXION", "Conectado al puerto serial: " + Serial.list()[0]); //  Evento
  } catch (Exception e) {
    // Si falla la conexión, continuar sin Arduino
    println("Error: No se pudo conectar al puerto serial");
    logger.registrarEvento("ERROR", "No se pudo conectar al puerto serial"); // Error
  }
  
  // ============================================================================
  // INICIALIZAR BOTONES DE LA INTERFAZ
  // ============================================================================
  
  // Botón de calibración inicial (pantalla de calibración)
  btnIniciarCalibracion = new Button(460, 350, 300, 80, "INICIAR CALIBRACIÓN", color(100, 200, 255));
  
  // Botones de movimiento manual de los motores
  btnXAdelante = new Button(100, 250, 80, 50, "X →", color(100, 200, 255));
  btnXAtras = new Button(100, 310, 80, 50, "X ←", color(100, 200, 255));
  btnYAdelante = new Button(450, 250, 80, 50, "Y →", color(100, 255, 100));
  btnYAtras = new Button(450, 310, 80, 50, "Y ←", color(100, 255, 100));
  
  // Botón de posición aleatoria - centrado entre los controles de motores
  btnPosicionAleatoria = new Button(220, 270, 190, 70, "IR A POSICIÓN\nALEATORIA", color(255, 150, 50));
  
  // Botón de histórico de eventos - arriba a la derecha
  btnHistoricoEventos = new Button(900, 60, 270, 50, "VER HISTÓRICO DE EVENTOS", color(200, 100, 255));
}

// ============================================================================
// FUNCIÓN DRAW - SE EJECUTA CONTINUAMENTE (LOOP PRINCIPAL)
// ============================================================================

void draw() {
  background(50); // Fondo gris oscuro
  
  // Mostrar pantalla según el estado actual
  if (estadoActual == Estado.CALIBRANDO) {
    dibujarPantallaCalibracion(); // Mostrar pantalla de calibración
  } else {
    dibujarInterfazPrincipal();   // Mostrar interfaz operacional
    manejarBotonesPresionados();  // Procesar botones mantenidos presionados
  }
}

// ============================================================================
// MANEJO DE BOTONES PRESIONADOS CONTINUAMENTE
// ============================================================================

/**
 * Esta función envía comandos continuos al Arduino mientras un botón
 * de movimiento se mantiene presionado, respetando un intervalo mínimo
 */
void manejarBotonesPresionados() {
  // Si no hay conexión, no hacer nada
  if (!conectado) return;
  
  int tiempoActual = millis();
  
  // Verificar si ha pasado suficiente tiempo desde el último comando
  if (tiempoActual - ultimoEnvioMovimiento < intervaloMovimiento) return;
  
  // Enviar comando según el botón presionado y respetando límites
  if (btnXAdelantePresionado && posX < LIMITE_MAX_X) {
    puerto.write("A\n"); // Comando para mover X adelante
    ultimoEnvioMovimiento = tiempoActual;
  } else if (btnXAtrasPresionado && posX > 0) {
    puerto.write("B\n"); // Comando para mover X atrás
    ultimoEnvioMovimiento = tiempoActual;
  } else if (btnYAdelantePresionado && posY < LIMITE_MAX_Y) {
    puerto.write("D\n"); // Comando para mover Y adelante
    ultimoEnvioMovimiento = tiempoActual;
  } else if (btnYAtrasPresionado && posY > 0) {
    puerto.write("E\n"); // Comando para mover Y atrás
    ultimoEnvioMovimiento = tiempoActual;
  }
}

// ============================================================================
// PANTALLA DE CALIBRACIÓN
// ============================================================================

/**
 * Dibuja la interfaz de calibración inicial
 * Se muestra al inicio y requiere calibrar ambos motores antes de continuar
 */
void dibujarPantallaCalibracion() {
  // ============================================================================
  // INDICADOR DE CONEXIÓN (esquina superior derecha)
  // ============================================================================
  
  textAlign(RIGHT);
  textSize(18);
  if (conectado) {
    fill(100, 255, 100); // Verde si está conectado
    text("CONECTADO  :)", width - 30, 30);
  } else {
    fill(255, 100, 100); // Rojo si está desconectado
    text("DESCONECTADO  :/", width - 30, 30);
  }
  
  // ============================================================================
  // TÍTULO PRINCIPAL
  // ============================================================================
  
  fill(255);
  textAlign(CENTER);
  textSize(48);
  text("Calibración Requerida", width/2, 150);
  
  // Subtítulo explicativo
  textSize(20);
  fill(200);
  text("Los motores deben ser calibrados antes de operar", width/2, 200);
  
  // ============================================================================
  // CONTENIDO SEGÚN ESTADO DE CALIBRACIÓN
  // ============================================================================
  
  if (!calibracionIniciada) {
    // Estado inicial: Esperando que el usuario inicie la calibración
    
    if (conectado) {
      // Mostrar botón de inicio si hay conexión
      btnIniciarCalibracion.display();
      
      // Advertencias de seguridad
      fill(150);
      textSize(16);
      text("La calibración moverá los motores hasta los finales de carrera", width/2, 500);
      text("Asegúrate de que el área esté despejada", width/2, 525);
    } else {
      // Mensaje de error si no hay conexión
      fill(255, 100, 100);
      textSize(24);
      text("Arduino no conectado  :(", width/2, 350);
      
      fill(200);
      textSize(16);
      text("Conecta el Arduino y reinicia la aplicación", width/2, 390);
    }
  } else {
    // Calibración en proceso: Mostrar progreso
    
    // Mensaje de estado actual
    fill(255);
    textSize(24);
    text(mensajeCalibracion, width/2, 280);
    
    // ============================================================================
    // BARRA DE PROGRESO
    // ============================================================================
    
    float barWidth = 600;
    float barHeight = 40;
    float barX = (width - barWidth) / 2;
    float barY = 320;
    
    // Marco de la barra
    noFill();
    stroke(255);
    strokeWeight(3);
    rect(barX, barY, barWidth, barHeight, 5);
    
    // Relleno de progreso (color cambia según el estado)
    noStroke();
    if (motorXCalibrado && motorYCalibrado) {
      fill(100, 255, 100); // Verde cuando está completo
    } else if (motorXCalibrado) {
      fill(100, 200, 255); // Azul cuando X está calibrado
    } else {
      fill(255, 200, 100); // Naranja durante calibración de X
    }
    rect(barX + 3, barY + 3, (barWidth - 6) * progresoCalibracion, barHeight - 6, 5);
    
    // Porcentaje de progreso
    fill(255);
    textSize(20);
    text(int(progresoCalibracion * 100) + "%", width/2, barY + barHeight + 35);
    
    // ============================================================================
    // ESTADO DE CADA MOTOR
    // ============================================================================
    
    textSize(16);
    
    // Motor X
    fill(motorXCalibrado ? color(100, 255, 100) : color(150));
    text("Motor X: " + (motorXCalibrado ? "✓ Calibrado" : "En proceso..."), width/2 - 150, 420);
    
    // Motor Y
    fill(motorYCalibrado ? color(100, 255, 100) : color(150));
    text("Motor Y: " + (motorYCalibrado ? "✓ Calibrado" : "En proceso..."), width/2 + 150, 420);
    
    // Actualizar el progreso visual
    actualizarProgresoCalibracion();
  }
  
  strokeWeight(1); // Restaurar grosor de línea por defecto
}

// ============================================================================
// ACTUALIZAR PROGRESO DE CALIBRACIÓN
// ============================================================================

/**
 * Actualiza el progreso visual de la calibración y cambia al estado
 * OPERACIONAL cuando ambos motores están calibrados
 */
void actualizarProgresoCalibracion() {
  if (motorXCalibrado && motorYCalibrado) {
    // Ambos motores calibrados: 100%
    progresoCalibracion = 1.0;
    mensajeCalibracion = "¡Calibración completada!";
    
    // Cambiar a estado operacional después de un breve delay
    if (progresoCalibracion >= 1.0 && millis() % 2000 < 50) {
      estadoActual = Estado.OPERACIONAL;
      logger.registrarEvento("CALIBRACION", "Calibración completada exitosamente"); // 🟢 Evento
      println("Sistema listo para operar");
    }
  } else if (motorXCalibrado) {
    // Solo X calibrado: 50%
    progresoCalibracion = 0.5;
    mensajeCalibracion = "Calibrando Motor Y...";
  } else if (calibracionIniciada) {
    // Calibración iniciada pero X aún no termina: 25%
    progresoCalibracion = 0.25;
    mensajeCalibracion = "Calibrando Motor X...";
  }
}

// ============================================================================
// INTERFAZ PRINCIPAL (OPERACIONAL)
// ============================================================================

/**
 * Dibuja la interfaz principal cuando el sistema está operacional
 * Incluye controles de motores, sensor DHT11 y posiciones guardadas
 */
void dibujarInterfazPrincipal() {
  // ============================================================================
  // ACTUALIZACIÓN AUTOMÁTICA DE POSICIÓN
  // ============================================================================
  
  // Solicitar posición actual al Arduino periódicamente
  if (conectado && millis() - ultimaActualizacion > intervaloActualizacion) {
    puerto.write("P\n"); // Comando para solicitar posición
    ultimaActualizacion = millis();
  }
  
  // ============================================================================
  // ENCABEZADO
  // ============================================================================
  
  fill(255);
  textAlign(CENTER);
  textSize(24);
  text("Trabajo Final Informática II - Robot para micrófono", 300, 50);
  
  fill(255);
  textAlign(CENTER);
  textSize(24);
  text("Control Motores Paso a Paso", 300, 100);
  
  // ============================================================================
  // INDICADOR DE ESTADO DE CONEXIÓN
  // ============================================================================
  
  textSize(20);
  fill(conectado ? color(100, 255, 100) : color(255, 100, 100));
  text(conectado ? "Estado: Conectado" : "Estado: Desconectado", 1030, 30);
  
  // ============================================================================
  // LOGO DE LA UTN
  // ============================================================================
  
  // Mostrar imagen solo si se cargó correctamente
  if (P != null) {
    image(P, 887, 150);
  }
  
  // ============================================================================
  // INFORMACIÓN DEL AUTOR
  // ============================================================================
  
  fill(255);
  textSize(20);
  text("Realizado por", 1030, 250);
  fill(255);
  textSize(20);
  text("Dalmaso Sebastián Martín", 1030, 275);
  fill(255);
  textSize(20);
  text("Legajo: 50864 - Ciclo Lectivo 2025", 1030, 300);
  
  // ============================================================================
  // INFORMACIÓN DEL MOTOR X
  // ============================================================================
  
  fill(255);
  textSize(18);
  textAlign(LEFT);
  text("Motor X", 80, 140);
  textSize(14);
  text("Posición: " + posX + " pasos", 80, 165);
  text("Límite: " + LIMITE_MAX_X + " pasos", 80, 185);
  
  // Barra de progreso del motor X
  drawProgressBar(80, 200, 180, 20, posX, LIMITE_MAX_X, color(100, 200, 255));
  
  // ============================================================================
  // INFORMACIÓN DEL MOTOR Y
  // ============================================================================
  
  textSize(18);
  textAlign(LEFT);
  text("Motor Y", 430, 140);
  textSize(14);
  text("Posición: " + posY + " pasos", 430, 165);
  text("Límite: " + LIMITE_MAX_Y + " pasos", 430, 185);
  
  // Barra de progreso del motor Y
  drawProgressBar(430, 200, 180, 20, posY, LIMITE_MAX_Y, color(100, 255, 100));
  
  // ============================================================================
  // PANELES Y BOTONES
  // ============================================================================
  
  drawSensorPanel();       // Panel del sensor DHT11
  drawPosicionesPanel();     // Panel de posiciones guardadas
  
  // Mostrar todos los botones de control
  btnXAdelante.display();
  btnXAtras.display();
  btnYAdelante.display();
  btnYAtras.display();
  btnPosicionAleatoria.display();
  btnHistoricoEventos.display();
}

// ============================================================================
// PANEL DE POSICIONES GUARDADAS
// ============================================================================

/**
 * Dibuja el panel inferior con los 6 slots de posiciones guardadas
 */
void drawPosicionesPanel() {
  // Marco del panel
  stroke(255);
  strokeWeight(2);
  fill(40);
  rect(30, 380, 1165, 240, 10);
  
  // Título del panel
  fill(200, 150, 255);
  textAlign(CENTER);
  textSize(18);
  text("POSICIONES GUARDADAS", 600, 405);
  
  // Dibujar todos los slots de posiciones
  listaPosiciones.dibujar(45, 420);
  
  strokeWeight(1);
}

// ============================================================================
// PANEL DEL SENSOR DHT11
// ============================================================================

/**
 * Dibuja el panel del sensor de temperatura y humedad DHT11
 * Muestra temperatura, humedad y sensación térmica con barras visuales
 */
void drawSensorPanel() {
  // Marco del panel
  stroke(255);
  strokeWeight(2);
  fill(40);
  rect(640, 50, 230, 280, 10);
  
  // Título del panel
  fill(255, 200, 100);
  textAlign(CENTER);
  textSize(20);
  text("Sensor DHT11", 755, 85);
  
  // Línea separadora
  stroke(100);
  line(660, 100, 850, 100);
  
  // ============================================================================
  // INDICADOR DE ESTADO DEL SENSOR
  // ============================================================================
  
  noStroke();
  textSize(12);
  fill(dhtValido ? color(100, 255, 100) : color(255, 100, 100));
  text(dhtValido ? "Activo" : "Sin datos", 755, 120);
  
  if (dhtValido) {
    // Si hay datos válidos, mostrar información completa
    
    // ============================================================================
    // TEMPERATURA
    // ============================================================================
    
    fill(255);
    textSize(14);
    text("Temperatura:", 696, 160);
    textSize(22);
    textAlign(RIGHT);
    text(nf(temperatura, 0, 1) + "°C", 850, 165);
    
    // Barra de temperatura con código de colores
    drawTempBar(660, 175, 180, 15, temperatura);
    
    // ============================================================================
    // HUMEDAD
    // ============================================================================
    
    fill(255);
    textSize(14);
    textAlign(LEFT);
    text("Humedad:", 658, 220);
    textSize(22);
    textAlign(RIGHT);
    text(nf(humedad, 0, 1) + "%", 850, 225);
    
    // Barra de humedad
    drawHumidityBar(660, 235, 180, 15, humedad);
    
    // ============================================================================
    // SENSACIÓN TÉRMICA
    // ============================================================================
    
    fill(255, 200, 100);
    textAlign(LEFT);
    textSize(14);
    text("Sensación térmica:", 660, 275);
    textSize(18);
    textAlign(RIGHT);
    text(nf(sensacionTermica, 0, 1) + "°C", 850, 280);
    
    // ============================================================================
    // ALERTAS
    // ============================================================================
    
    // Mostrar alerta si la temperatura es muy alta
    if (temperatura > 35) {
      fill(255, 100, 100);
      textAlign(CENTER);
      textSize(12);
      text("Temperatura alta", 755, 310);
    } 
    // Mostrar alerta si la humedad es muy alta
    else if (humedad > 80) {
      fill(255, 200, 100);
      textAlign(CENTER);
      textSize(12);
      text("Humedad elevada", 755, 310);
    }
  } else {
    // Si no hay datos válidos, mostrar mensaje de espera
    fill(150);
    textAlign(CENTER);
    textSize(14);
    text("Esperando datos\ndel sensor...", 755, 200);
  }
  
  strokeWeight(1);
}

// ============================================================================
// BARRA DE TEMPERATURA CON CÓDIGO DE COLORES
// ============================================================================

/**
 * Dibuja una barra de progreso para la temperatura
 * El color cambia según el rango de temperatura:
 * - Azul: < 20°C (frío)
 * - Verde: 20-28°C (confortable)
 * - Naranja: 28-35°C (cálido)
 * - Rojo: > 35°C (caliente)
 */
void drawTempBar(float x, float y, float w, float h, float temp) {
  // Marco de la barra
  noFill();
  stroke(255, 100, 100);
  rect(x, y, w, h);
  
  noStroke();
  float progress = constrain(temp / 50.0, 0, 1); // Normalizar a 0-1 (máx 50°C)
  
  // Determinar color según temperatura
  if (temp < 20) {
    fill(100, 150, 255); // Azul: frío
  } else if (temp < 28) {
    fill(100, 255, 100); // Verde: confortable
  } else if (temp < 35) {
    fill(255, 200, 100); // Naranja: cálido
  } else {
    fill(255, 100, 100); // Rojo: caliente
  }
  
  // Dibujar relleno de la barra
  rect(x + 2, y + 2, (w - 4) * progress, h - 4);
}

// ============================================================================
// BARRA DE HUMEDAD
// ============================================================================

/**
 * Dibuja una barra de progreso para la humedad relativa
 * Rango: 0-100%
 */
void drawHumidityBar(float x, float y, float w, float h, float hum) {
  // Marco de la barra
  noFill();
  stroke(100, 200, 255);
  rect(x, y, w, h);
  
  noStroke();
  float progress = constrain(hum / 100.0, 0, 1); // Normalizar a 0-1
  fill(100, 200, 255); // Color azul para humedad
  
  // Dibujar relleno de la barra
  rect(x + 2, y + 2, (w - 4) * progress, h - 4);
}

// ============================================================================
// BARRA DE PROGRESO GENÉRICA
// ============================================================================

/**
 * Dibuja una barra de progreso genérica
 * Usada para mostrar la posición actual de los motores
 * * @param x, y - Posición de la barra
 * @param w, h - Ancho y alto de la barra
 * @param value - Valor actual
 * @param max - Valor máximo
 * @param c - Color de la barra
 */
void drawProgressBar(float x, float y, float w, float h, long value, long max, color c) {
  // Marco de la barra
  noFill();
  stroke(255);
  rect(x, y, w, h);
  
  // Calcular progreso (0 a 1)
  noStroke();
  fill(c);
  float progress = constrain((float)value / max, 0, 1);
  
  // Dibujar relleno
  rect(x + 2, y + 2, (w - 4) * progress, h - 4);
}

// ============================================================================
// EVENTO: CLIC DEL MOUSE
// ============================================================================

/**
 * Maneja todos los clics de mouse en la interfaz
 * Procesa clics en botones y slots de posiciones
 */
void mousePressed() {
  // ============================================================================
  // MODO CALIBRACIÓN
  // ============================================================================
  
  if (estadoActual == Estado.CALIBRANDO) {
    // Solo permitir clic en botón de inicio de calibración
    if (!calibracionIniciada && btnIniciarCalibracion.isPressed(mouseX, mouseY)) {
      iniciarCalibracion();
    }
    return;
  }
  
  // ============================================================================
  // MODO OPERACIONAL
  // ============================================================================
  
  // El botón de histórico funciona incluso sin conexión Arduino
  if (!conectado && !btnHistoricoEventos.isPressed(mouseX, mouseY)) return;
  
  // Verificar clic en botón de histórico de eventos
  if (btnHistoricoEventos.isPressed(mouseX, mouseY)) {
    logger.abrirArchivo();
    return;
  }
  
  // Verificar clic en botón de posición aleatoria
  if (btnPosicionAleatoria.isPressed(mouseX, mouseY)) {
    irAPosicionAleatoria();
    return;
  }
  
  // Verificar clic en algún slot de posiciones
  int slotIndex = listaPosiciones.verificarClick(mouseX, mouseY);
  if (slotIndex >= 0) {
    return; // Si se hizo clic en un slot, no hacer nada más
  }
 
// ============================================================================
// BOTONES DE MOVIMIENTO MANUAL
// ============================================================================

// Si el clic no fue en un slot, verificar botones de movimiento manual
// Activar la bandera correspondiente para movimiento continuo
// y enviar el primer comando

if (btnXAdelante.isPressed(mouseX, mouseY)) {
  btnXAdelantePresionado = true;
  if (posX < LIMITE_MAX_X) { // 🔴 Validación de límite
    puerto.write("A\n"); // Comando: Mover X Adelante
    logger.registrarEvento("MOVIMIENTO", "Motor X adelante (posición actual: " + posX + ")");
    ultimoEnvioMovimiento = millis();
  }
} else if (btnXAtras.isPressed(mouseX, mouseY)) {
  btnXAtrasPresionado = true;
  if (posX > 0) { // 🔴 Validación de límite
    puerto.write("B\n"); // Comando: Mover X Atrás
    logger.registrarEvento("MOVIMIENTO", "Motor X atrás (posición actual: " + posX + ")");
    ultimoEnvioMovimiento = millis();
  }
} else if (btnYAdelante.isPressed(mouseX, mouseY)) {
  btnYAdelantePresionado = true;
  if (posY < LIMITE_MAX_Y) { // 🔴 Validación de límite
    puerto.write("D\n"); // Comando: Mover Y Adelante
    logger.registrarEvento("MOVIMIENTO", "Motor Y adelante (posición actual: " + posY + ")");
    ultimoEnvioMovimiento = millis();
  }
} else if (btnYAtras.isPressed(mouseX, mouseY)) {
  btnYAtrasPresionado = true;
  if (posY > 0) { // 🔴 Validación de límite
    puerto.write("E\n"); // Comando: Mover Y Atrás
    logger.registrarEvento("MOVIMIENTO", "Motor Y atrás (posición actual: " + posY + ")");
    ultimoEnvioMovimiento = millis();
  }
}
}

// ============================================================================
// EVENTO: SOLTAR CLIC DEL MOUSE
// ============================================================================

/**
 * Se llama cuando se suelta el botón del mouse
 * Detiene el movimiento continuo al desactivar todas las banderas
 */
void mouseReleased() {
  btnXAdelantePresionado = false;
  btnXAtrasPresionado = false;
  btnYAdelantePresionado = false;
  btnYAtrasPresionado = false;
}

// ============================================================================
// FUNCIÓN: INICIAR CALIBRACIÓN
// ============================================================================

/**
 * Inicia el proceso de calibración de los motores
 * Envía el comando 'C' al Arduino para comenzar el "homing"
 */
void iniciarCalibracion() {
  calibracionIniciada = true;
  motorXCalibrado = false;
  motorYCalibrado = false;
  progresoCalibracion = 0;
  
  if (conectado) {
    println("Iniciando calibración...");
    logger.registrarEvento("CALIBRACION", "Calibración iniciada");
    puerto.write("C\n"); // Comando: Iniciar Calibración (ambos motores)
  } else {
    println("ERROR: No hay conexión con Arduino");
    logger.registrarEvento("ERROR", "Intento de calibración sin conexión Arduino"); //  Error
  }
}

// ============================================================================
// FUNCIÓN: IR A POSICIÓN ALEATORIA
// ============================================================================

/**
 * Genera una posición aleatoria dentro de los límites y envía el
 * comando 'G' (GoTo) al Arduino para moverse a esa posición
 */
void irAPosicionAleatoria() {
  if (!conectado) {
    println("ERROR: No hay conexión con Arduino");
    logger.registrarEvento("ERROR", "Intento de movimiento aleatorio sin conexión"); //  Error
    return;
  }
  
  // Generar posición aleatoria dentro de los límites
  long randomX = (long)random(0, LIMITE_MAX_X);
  long randomY = (long)random(0, LIMITE_MAX_Y);
  
  // Enviar comando al Arduino
  String comando = "G:" + randomX + "," + randomY + "\n";
  puerto.write(comando); // Comando: GoTo (G:X,Y)
  
  logger.registrarEvento("POSICION_ALEATORIA", "X:" + randomX + " Y:" + randomY); //  Evento
  
  // Imprimir en consola para depuración
  println("═══════════════════════════════════════");
  println(" POSICIÓN ALEATORIA GENERADA");
  println("   X: " + randomX + " pasos");
  println("   Y: " + randomY + " pasos");
  println("   Comando enviado: " + comando.trim());
  println("═══════════════════════════════════════");
}

// ============================================================================
// CALLBACKS DE ARCHIVOS (SLOTS)
// ============================================================================

/**
 * Callback para cargar un archivo de slots (no implementado en el
 * código actual, pero preparado para un futuro `selectInput()`)
 * @param selection - El archivo seleccionado por el usuario
 */
void cargarArchivoSlots(File selection) {
  if (selection != null) {
    listaPosiciones.cargarDesdeArchivo(selection.getAbsolutePath());
  }
}

/**
 * Callback para guardar un archivo de slots (no implementado en el
 * código actual, pero preparado para un futuro `selectOutput()`)
 * @param selection - El archivo seleccionado por el usuario
 */
void guardarArchivoSlots(File selection) {
  if (selection != null) {
    String filename = selection.getAbsolutePath();
    if (!filename.endsWith(".dat")) {
      filename += ".dat"; // 🟡 Advertencia: Asegurar extensión .dat
    }
    listaPosiciones.guardarEnArchivo(filename);
  }
}

// ============================================================================
// EVENTO: RECEPCIÓN SERIAL (COMUNICACIÓN ARDUINO -> PROCESSING)
// ============================================================================

/**
 * Se llama automáticamente cuando se reciben datos del puerto serial
 * Procesa los mensajes recibidos del Arduino
 * @param p - El objeto Serial que recibió los datos
 */
void serialEvent(Serial p) {
  String data = p.readStringUntil('\n'); // Leer hasta el salto de línea
  if (data != null) {
    data = trim(data);
    println("Arduino: " + data); // Imprimir en consola para depuración
    
    // ============================================================================
    // PARSEO DEL PROTOCOLO SERIAL
    // ============================================================================
    
    // 🟢 Mensaje: "X Calibrado"
    if (data.equals("X Calibrado")) {
      motorXCalibrado = true;
      logger.registrarEvento("CALIBRACION", "Motor X calibrado");
      // Si X terminó y Y aún no, enviar comando para calibrar Y
      if (calibracionIniciada && !motorYCalibrado) {
        puerto.write("F\n"); // Comando: Calibrar solo Y
      }
    } 
    // 🟢 Mensaje: "Y Calibrado"
    else if (data.equals("Y Calibrado")) {
      motorYCalibrado = true;
      logger.registrarEvento("CALIBRACION", "Motor Y calibrado");
    } 
    // 🔵 Mensaje de Posición: "POS:X,Y"
    else if (data.startsWith("POS:")) {
      String[] pos = split(data.substring(4), ',');
      if (pos.length == 2) {
        try {
          posX = Long.parseLong(pos[0]);
          posY = Long.parseLong(pos[1]);
        } catch (NumberFormatException e) {
          logger.registrarEvento("ERROR", "Datos de posición corruptos: " + data); //  Error
        }
      }
    } 
    // 🔵 Mensaje del Sensor: "DHT:TEMP,HUM,HEAT_INDEX"
    else if (data.startsWith("DHT:")) {
      String[] valores = split(data.substring(4), ',');
      if (valores.length == 3) {
        try {
          temperatura = Float.parseFloat(valores[0]);
          humedad = Float.parseFloat(valores[1]);
          sensacionTermica = Float.parseFloat(valores[2]);
          
          if (!dhtValido) { // Si es la primera lectura válida
            logger.registrarEvento("SENSOR", "DHT11 activado - Temp:" + temperatura + "°C Hum:" + humedad + "%"); //  Evento
          }
          
          dhtValido = true;
          
          // Registrar alertas
          if (temperatura > 35) {
            logger.registrarEvento("ALERTA", "Temperatura alta: " + temperatura + "°C"); //  Advertencia
          }
          if (humedad > 80) {
            logger.registrarEvento("ALERTA", "Humedad elevada: " + humedad + "%"); //  Advertencia
          }
        } catch (NumberFormatException e) {
          logger.registrarEvento("ERROR", "Datos DHT corruptos: " + data); //  Error
        }
      }
    } 
    // 🔴 Mensaje de Error del Sensor: "DHT:ERROR"
    else if (data.equals("DHT:ERROR")) {
      if (dhtValido) { // Si estaba funcionando y falló
        logger.registrarEvento("ERROR", "Sensor DHT11 desconectado o error de lectura"); // 🔴 Error
      }
      dhtValido = false;
    }
  }
}

// ============================================================================
// CLASE: Logger
// ============================================================================
/**
 * Clase para gestionar el registro de eventos en un archivo CSV
 * Maneja la creación del archivo, formato de líneas, un buffer de
 * escritura y la apertura del archivo de log
 */
class Logger {
  String nombreArchivo;     // Nombre del archivo CSV (e.g., "historico.csv")
  ArrayList<String> buffer; // 🔵 Buffer para almacenar eventos antes de escribirlos
  int contadorEventos;      // Contador total de eventos en esta sesión
  
  /**
   * Constructor de la clase Logger
   * @param archivo - El nombre del archivo CSV a utilizar
   */
  Logger(String archivo) {
    this.nombreArchivo = archivo;
    this.buffer = new ArrayList<String>(); // Inicializa la estructura de datos
    this.contadorEventos = 0;
    
    // Crear encabezado del CSV si el archivo no existe
    File f = new File(sketchPath(nombreArchivo));
    if (!f.exists()) {
      crearArchivoConEncabezado();
    }
  }
  
  /**
   * Crea el archivo CSV y escribe la fila de encabezado
   */
  void crearArchivoConEncabezado() {
    String[] encabezado = {
      "TIMESTAMP,FECHA,HORA,TIPO_EVENTO,DESCRIPCION"
    };
    saveStrings(nombreArchivo, encabezado);
    println("✓ Archivo de log creado: " + nombreArchivo); //  Evento
  }
  
  /**
   * Registra un nuevo evento en el buffer
   * @param tipo - El tipo de evento (e.g., "ERROR", "MOVIMIENTO")
   * @param descripcion - Descripción detallada del evento
   */
  void registrarEvento(String tipo, String descripcion) {
    contadorEventos++;
    
    // Obtener timestamp y formato de fecha/hora
    long timestamp = System.currentTimeMillis();
    String fecha = day() + "/" + month() + "/" + year();
    String hora = nf(hour(), 2) + ":" + nf(minute(), 2) + ":" + nf(second(), 2);
    
    // Formatear línea CSV. 
    // 🟡 Importante: Envuelve la descripción en comillas para manejar comas
    String linea = timestamp + "," + fecha + "," + hora + "," + tipo + ",\"" + descripcion + "\"";
    
    buffer.add(linea);
    
    // Guardar el buffer en el archivo si se acumulan 10 eventos
    // o si es un evento crítico (ERROR, ALERTA)
    if (buffer.size() >= 10 || tipo.equals("ERROR") || tipo.equals("ALERTA")) {
      guardarBuffer();
    }
    
    println("[LOG] " + tipo + ": " + descripcion);
  }
  
  /**
   * Escribe el contenido del buffer en el archivo CSV
   * Lee el archivo existente, añade las nuevas líneas y lo guarda
   */
  void guardarBuffer() {
    if (buffer.size() == 0) return; // Nada que guardar
    
    // Leer archivo existente
    File f = new File(sketchPath(nombreArchivo));
    ArrayList<String> lineasExistentes = new ArrayList<String>();
    
    if (f.exists()) {
      String[] temp = loadStrings(nombreArchivo);
      if (temp != null) {
        for (String linea : temp) {
          lineasExistentes.add(linea);
        }
      }
    }
    
    // Agregar nuevas líneas del buffer
    for (String nuevaLinea : buffer) {
      lineasExistentes.add(nuevaLinea);
    }
    
    // Guardar todo
    String[] datos = lineasExistentes.toArray(new String[lineasExistentes.size()]);
    saveStrings(nombreArchivo, datos);
    
    println("✓ Buffer de log guardado (" + buffer.size() + " eventos)"); // 🟢 Evento
    buffer.clear(); // Limpiar el buffer
  }
  
  /**
   * Abre el archivo de log con la aplicación predeterminada del sistema
   * Utiliza Java AWT Desktop
   */
  void abrirArchivo() {
    // Guardar cualquier evento pendiente antes de abrir
    guardarBuffer();
    
    String rutaCompleta = sketchPath(nombreArchivo);
    File f = new File(rutaCompleta);
    
    if (!f.exists() || f.length() < 100) { // 100 bytes para asegurar que hay más que el encabezado
      // 🟡 Advertencia: No hay log para mostrar
      javax.swing.JOptionPane.showMessageDialog(
        null,
        "El archivo de histórico aún no contiene eventos significativos.",
        "Histórico vacío",
        javax.swing.JOptionPane.INFORMATION_MESSAGE
      );
      return;
    }
    
    registrarEvento("SISTEMA", "Histórico de eventos abierto por el usuario");
    
    // Intentar abrir el archivo con la aplicación predeterminada
    try {
      java.awt.Desktop desktop = java.awt.Desktop.getDesktop();
      desktop.open(f);
      
      // 🟢 Mostrar mensaje de éxito
      javax.swing.JOptionPane.showMessageDialog(
        null,
        "Archivo de histórico abierto.\nRuta: " + rutaCompleta + "\nTotal de eventos: " + contadorEventos,
        "Histórico de Eventos",
        javax.swing.JOptionPane.INFORMATION_MESSAGE
      );
    } catch (Exception e) {
      // 🔴 Error: No se pudo abrir automáticamente
      // Mostrar la ruta para que el usuario lo abra manualmente
      javax.swing.JOptionPane.showMessageDialog(
        null,
        "No se pudo abrir el archivo automáticamente.\n\nPuedes abrirlo manualmente desde:\n" + rutaCompleta + "\n\nTotal de eventos registrados: " + contadorEventos,
        "Archivo de histórico disponible",
        javax.swing.JOptionPane.INFORMATION_MESSAGE
      );
      println("Ruta del archivo: " + rutaCompleta);
    }
  }
}

// ============================================================================
// CLASE: Button
// ============================================================================
/**
 * Clase para crear un botón simple en la interfaz
 * Dibuja un rectángulo con texto y detecta si el mouse está sobre él
 */
class Button {
  float x, y, w, h; // Posición (x, y) y tamaño (ancho, alto)
  String label;     // Texto del botón
  color c;          // Color base del botón
  
  /**
   * Constructor de la clase Button
   */
  Button(float x, float y, float w, float h, String label, color c) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.label = label;
    this.c = c;
  }
  
  /**
   * Dibuja el botón en la pantalla
   * Cambia de color (se aclara) si el mouse está encima (hover)
   */
  void display() {
    boolean hover = isPressed(mouseX, mouseY);
    // Aclarar el color si el mouse está encima
    fill(hover ? color(min(255, red(c)+30), min(255, green(c)+30), min(255, blue(c)+30)) : c);
    stroke(255);
    strokeWeight(2);
    rect(x, y, w, h, 8); // Rectángulo redondeado
    fill(0); // Texto en color negro
    textAlign(CENTER, CENTER);
    textSize(14);
    text(label, x+w/2, y+h/2);
    strokeWeight(1);
  }
  
  /**
   * Verifica si las coordenadas (mx, my) están dentro del botón
   * @param mx - Coordenada X del mouse
   * @param my - Coordenada Y del mouse
   * @return boolean - true si el mouse está sobre el botón, false si no
   */
  boolean isPressed(float mx, float my) {
    return mx > x && mx < x+w && my > y && my < y+h;
  }
}

// ============================================================================
// CLASE: NodoPosicion
// ============================================================================
/**
 * 🔵 Representa un nodo en la lista enlazada de posiciones
 * Contiene la información de un "Slot" de posición guardada
 */
class NodoPosicion {
  int indice;             // Índice del slot (e.g., 1, 2, 3...)
  String nombre;          // Nombre descriptivo (dado por el usuario)
  long posX;              // Posición X guardada
  long posY;              // Posición Y guardada
  boolean ocupado;        // true si el slot contiene datos
  boolean fueraLimites;   //  true si la posición guardada excede los límites actuales
  NodoPosicion siguiente; //  Puntero al siguiente nodo en la lista
  
  /**
   * Constructor del NodoPosicion
   * @param idx - El índice del slot
   */
  NodoPosicion(int idx) {
    this.indice = idx;
    this.nombre = "";
    this.posX = 0;
    this.posY = 0;
    this.ocupado = false;
    this.fueraLimites = false;
    this.siguiente = null; //  Inicialmente no apunta a nada
  }
  
  /**
   * Guarda una nueva posición en este nodo
   * @param nom - Nombre para la posición
   * @param x - Posición X
   * @param y - Posición Y
   */
  void actualizarPosicion(String nom, long x, long y) {
    this.nombre = nom;
    this.posX = x;
    this.posY = y;
    this.ocupado = true;
    verificarLimites(); // Comprobar si es válida
    
    // Registrar en el log
    logger.registrarEvento("SLOT_GUARDADO", "Slot " + indice + " - " + nom + " (X:" + x + " Y:" + y + ")"); //  Evento
  }
  
  /**
   * Comprueba si la posición guardada está dentro de los límites
   * definidos en las variables globales
   */
  void verificarLimites() {
    fueraLimites = (posX > LIMITE_MAX_X || posY > LIMITE_MAX_Y || posX < 0 || posY < 0);
  }
  
  /**
   * Envía el comando 'G' (GoTo) al Arduino para ir a esta posición guardada
   */
  void irAPosicion() {
    if (!ocupado) {
      println("Error: Slot " + indice + " está vacío"); //  Error
      return;
    }
    
    if (fueraLimites) {
      println("ERROR: No se puede ir a la posición del Slot " + indice);
      println("La posición excede los límites configurados");
      logger.registrarEvento("ERROR", "Intento de ir a Slot " + indice + " fuera de límites"); //  Error
      return;
    }
    
    if (!conectado) {
      println("Error: No hay conexión con Arduino");
      logger.registrarEvento("ERROR", "Intento de movimiento sin conexión Arduino"); //  Error
      return;
    }
    
    // Enviar comando GoTo
    String comando = "G:" + posX + "," + posY + "\n";
    puerto.write(comando); // Comando: GoTo (G:X,Y)
    logger.registrarEvento("MOVIMIENTO_SLOT", "Ir a Slot " + indice + " - " + nombre + " (X:" + posX + " Y:" + posY + ")"); // 🟢 Evento
    println("Yendo a posición Slot " + indice + ": " + nombre);
  }
  
  /**
   * Limpia el slot, dejándolo como "vacío"
   */
  void limpiar() {
    logger.registrarEvento("SLOT_BORRADO", "Slot " + indice + " borrado - era: " + nombre); // 🟡 Evento de limpieza
    nombre = "";
    posX = 0;
    posY = 0;
    ocupado = false;
    fueraLimites = false;
    println("Slot " + indice + " limpiado");
  }
  
  /**
   * Serializa los datos del nodo a un String para guardar en archivo
   * @return String - Formato: "indice|nombre|posX|posY|ocupado"
   */
  String serializar() {
    return indice + "|" + nombre + "|" + posX + "|" + posY + "|" + ocupado;
  }
  
  /**
   * Deserializa un String y carga los datos en el nodo
   * @param data - El String leído del archivo
   */
  void deserializar(String data) {
    String[] partes = split(data, '|');
    if (partes.length == 5) { //  Validación de formato
      try {
        indice = Integer.parseInt(partes[0]);
        nombre = partes[1];
        posX = Long.parseLong(partes[2]);
        posY = Long.parseLong(partes[3]);
        ocupado = Boolean.parseBoolean(partes[4]);
        verificarLimites(); // Comprobar si es válida
      } catch (Exception e) {
        println("Error al deserializar slot: " + data); // 🔴 Error
        logger.registrarEvento("ERROR", "Datos de slot corruptos: " + data);
      }
    }
  }
}

// ============================================================================
// CLASE: ListaPosiciones
// ============================================================================
/**
 * 🔵 Clase que implementa una Lista Enlazada simple
 * Administra el conjunto de Nodos de Posición (slots)
 * Se encarga de dibujarlos, gestionar clics, y guardar/cargar
 */
class ListaPosiciones {
  NodoPosicion cabeza; //  Puntero al primer nodo de la lista
  int capacidad;       // Número total de slots a crear
  
  // Variables de UI para dibujar los slots
  float slotWidth = 180;
  float slotHeight = 160;
  float espaciado = 10;
  
  /**
   * Constructor de la lista.
   * Crea una lista enlazada con 'cap' nodos vacíos
   * @param cap - La capacidad (número de slots)
   */
  ListaPosiciones(int cap) {
    this.capacidad = cap;
    this.cabeza = null;
    
    // Crear los 'cap' nodos vacíos y enlazarlos
    for (int i = 0; i < capacidad; i++) {
      agregar(new NodoPosicion(i + 1));
    }
  }
  
  /**
   * Agrega un nuevo nodo al final de la lista
   * @param nuevo - El NodoPosicion a agregar
   */
  void agregar(NodoPosicion nuevo) {
    if (cabeza == null) {
      cabeza = nuevo; //  Si es el primero, se convierte en la cabeza
    } else {
      NodoPosicion actual = cabeza;
      // Recorrer hasta el final de la lista
      while (actual.siguiente != null) {
        actual = actual.siguiente;
      }
      actual.siguiente = nuevo; //  Enlazar el último con el nuevo
    }
  }
  
  /**
   * Obtiene un nodo por su índice (no implementado en el código)
   * (El código original no usa esta función, pero está definida)
   * @param indice - El índice (1-based) a buscar
   * @return NodoPosicion - El nodo encontrado o null
   */
  NodoPosicion obtener(int indice) {
    NodoPosicion actual = cabeza;
    int contador = 1;
    
    while (actual != null) {
      if (contador == indice) {
        return actual;
      }
      actual = actual.siguiente;
      contador++;
    }
    return null;
  }
  
  /**
   * Guarda todos los nodos de la lista en un archivo .dat
   * @param filename - El nombre del archivo
   */
  void guardarEnArchivo(String filename) {
    ArrayList<String> lineas = new ArrayList<String>(); //  Buffer de líneas
    NodoPosicion actual = cabeza;
    
    // Recorrer la lista y serializar cada nodo
    while (actual != null) {
      lineas.add(actual.serializar());
      actual = actual.siguiente;
    }
    
    String[] data = lineas.toArray(new String[lineas.size()]);
    saveStrings(filename, data); // Guardar en archivo
    println("✓ Archivo guardado: " + filename); //  Evento
    println("  Slots guardados: " + lineas.size());
  }
  
  /**
   * Carga los datos de los slots desde un archivo .dat
   * @param filename - El nombre del archivo
   */
  void cargarDesdeArchivo(String filename) {
    File f = new File(sketchPath(filename));
    if (!f.exists()) {
      println("Archivo no encontrado: " + filename); //  Advertencia
      return;
    }
    
    String[] lineas = loadStrings(filename);
    if (lineas == null || lineas.length == 0) {
      println("Archivo vacío o error al leer: " + filename); //  Advertencia
      return;
    }
    
    println("Cargando archivo: " + filename);
    NodoPosicion actual = cabeza;
    int lineaIdx = 0;
    
    // Recorrer la lista y el archivo simultáneamente
    while (actual != null && lineaIdx < lineas.length) {
      actual.deserializar(lineas[lineaIdx]); // Cargar datos en el nodo
      if (actual.ocupado) {
        println("  Slot " + actual.indice + ": " + actual.nombre + 
                " (X:" + actual.posX + ", Y:" + actual.posY + ")");
      }
      actual = actual.siguiente;
      lineaIdx++;
    }
    
    println("✓ Archivo cargado exitosamente"); // Evento
    logger.registrarEvento("SISTEMA", "Archivo de slots cargado: " + lineas.length + " slots");
  }
  
  /**
   * Dibuja todos los slots en la interfaz
   * @param startX - Posición X inicial del primer slot
   * @param startY - Posición Y inicial de los slots
   */
  void dibujar(float startX, float startY) {
    NodoPosicion actual = cabeza;
    int contador = 0;
    
    // Recorrer la lista y dibujar cada nodo
    while (actual != null) {
      float x = startX + (contador * (slotWidth + espaciado));
      float y = startY;
      
      dibujarSlot(actual, x, y);
      
      actual = actual.siguiente;
      contador++;
    }
  }
  
  /**
   * Dibuja un slot individual
   * @param nodo - El nodo (slot) a dibujar
   * @param x - Posición X del slot
   * @param y - Posición Y del slot
   */
  void dibujarSlot(NodoPosicion nodo, float x, float y) {
    // Color del borde y fondo según estado
    if (nodo.ocupado) {
      if (nodo.fueraLimites) {
        stroke(255, 100, 100); //  Borde rojo (fuera de límites)
        fill(70, 40, 40);
      } else {
        stroke(100, 255, 100); //  Borde verde (ocupado y válido)
        fill(60);
      }
    } else {
      stroke(100); // Borde gris (vacío)
      fill(45);
    }
    strokeWeight(2);
    rect(x, y, slotWidth, slotHeight, 8);
    
    // Título del slot ("Slot 1", "Slot 2", ...)
    if (nodo.ocupado) {
      if (nodo.fueraLimites) {
        fill(255, 100, 100); 
      } else {
        fill(100, 255, 100); 
      }
    } else {
      fill(150); // Gris
    }
    textAlign(CENTER);
    textSize(16);
    text("Slot " + nodo.indice, x + slotWidth/2, y + 25);
    
    // Contenido del slot
    if (nodo.ocupado) {
      // Nombre
      if (nodo.fueraLimites) {
        fill(255, 150, 100);
      } else {
        fill(255, 200, 100);
      }
      textSize(13);
      textAlign(CENTER);
      String nombreMostrar = nodo.nombre;
      if (nombreMostrar.length() > 18) { // Acortar nombre si es muy largo
        nombreMostrar = nombreMostrar.substring(0, 15) + "...";
      }
      text(nombreMostrar, x + slotWidth/2, y + 50);
      
      // Mensaje de Fuera de Límites
      if (nodo.fueraLimites) {
        fill(255, 100, 100); 
        textSize(11);
        text("FUERA DE LÍMITES", x + slotWidth/2, y + 68);
      }
      
      // Coordenadas
      fill(200);
      textSize(11);
      textAlign(CENTER);
      int offsetY = nodo.fueraLimites ? 15 : 0; // Desplazar si hay mensaje de error
      text("X: " + nodo.posX + " pasos", x + slotWidth/2, y + 75 + offsetY);
      text("Y: " + nodo.posY + " pasos", x + slotWidth/2, y + 92 + offsetY);
      
      // Botón "IR A POSICIÓN" (si es válido)
      if (nodo.fueraLimites) {
        // Botón deshabilitado
        fill(100);
        noStroke();
        rect(x + 10, y + 120, slotWidth - 20, 28, 5);
        fill(150);
        textAlign(CENTER);
        textSize(11);
        text("NO DISPONIBLE", x + slotWidth/2, y + 137);
      } else {
        // Botón habilitado
        fill(100, 200, 255);
        noStroke();
        rect(x + 10, y + 105, slotWidth - 20, 28, 5);
        fill(0);
        textAlign(CENTER);
        textSize(12);
        text("IR A POSICIÓN", x + slotWidth/2, y + 122);
      }
      
      // Botón "BORRAR"
      int btnBorrarY = nodo.fueraLimites ? 153 : 138;
      fill(255, 100, 100); // 🔴
      rect(x + 10, y + btnBorrarY, slotWidth - 20, 18, 5);
      fill(0);
      textSize(10);
      text("BORRAR", x + slotWidth/2, y + btnBorrarY + 13);
      
    } else {
      // Slot vacío - mostrar botón de guardar
      fill(100, 255, 100); // 🟢
      noStroke();
      rect(x + 10, y + 70, slotWidth - 20, 35, 5);
      fill(0);
      textAlign(CENTER);
      textSize(12);
      text("GUARDAR", x + slotWidth/2, y + 87);
      text("POS. ACTUAL", x + slotWidth/2, y + 101);
    }
    
    strokeWeight(1);
  }
  
  /**
   * Verifica si un clic del mouse (mx, my) ocurrió sobre un
   * botón dentro de algún slot de la lista
   * @param mx - Posición X del mouse
   * @param my - Posición Y del mouse
   * @return int - El índice del slot clickeado, o -1 si no hubo clic
   */
  int verificarClick(float mx, float my) {
    NodoPosicion actual = cabeza;
    int contador = 0;
    float startX = 45; // Coordenadas del panel de slots (debe coincidir con drawPosicionesPanel)
    float startY = 420;
    
    while (actual != null) {
      float x = startX + (contador * (slotWidth + espaciado));
      float y = startY;
      
      // 1. Verificar si el clic fue dentro de este slot
      if (mx > x && mx < x + slotWidth && my > y && my < y + slotHeight) {
        
        if (actual.ocupado) {
          // 2. Clic en slot ocupado: ¿Fue en "IR" o "BORRAR"?
          
          // Botón IR A POSICIÓN
          if (!actual.fueraLimites) {
            if (mx > x + 10 && mx < x + slotWidth - 10 && my > y + 105 && my < y + 133) {
              actual.irAPosicion();
              return actual.indice;
            }
          }
          
          // Botón BORRAR
          int btnBorrarY = actual.fueraLimites ? 153 : 138;
          if (mx > x + 10 && mx < x + slotWidth - 10 && my > y + btnBorrarY && my < y + btnBorrarY + 18) {
            actual.limpiar();
            guardarEnArchivo(ARCHIVO_SLOTS); // Auto-guardar al borrar
            return actual.indice;
          }
          
        } else {
          // 3. Clic en slot vacío: ¿Fue en "GUARDAR"?
          if (mx > x + 10 && mx < x + slotWidth - 10 && my > y + 70 && my < y + 105) {
            guardarPosicionActualEnSlot(actual);
            return actual.indice;
          }
        }
      }
      
      actual = actual.siguiente;
      contador++;
    }
    
    return -1; // No se hizo clic en ningún botón de slot
  }
  
  /**
   * Guarda la posición actual (posX, posY globales) en un nodo
   * Muestra un diálogo para pedir un nombre
   * @param nodo - El nodo (slot) donde se guardarán los datos
   */
  void guardarPosicionActualEnSlot(NodoPosicion nodo) {
    // Pedir nombre para la posición usando un diálogo de Swing
    String nombre = javax.swing.JOptionPane.showInputDialog(
      null,
      "Ingrese un nombre para esta posición:",
      "Slot " + nodo.indice,
      javax.swing.JOptionPane.PLAIN_MESSAGE
    );
    
    if (nombre != null && nombre.trim().length() > 0) {
      // Si el usuario ingresó un nombre válido
      nodo.actualizarPosicion(nombre.trim(), posX, posY);
      println("✓ Posición guardada en Slot " + nodo.indice); // 🟢 Evento
      println("  Nombre: " + nombre);
      println("  X: " + posX + ", Y: " + posY);
      
      // Guardar automáticamente en archivo
      guardarEnArchivo(ARCHIVO_SLOTS);
    } else {
      println("Guardado cancelado (nombre vacío)"); // 🟡 Advertencia
    }
  }
}

// ============================================================================
// EVENTO: CERRAR APLICACIÓN
// ============================================================================

/**
 * Se llama automáticamente cuando se cierra la aplicación
 * Se usa para guardar los slots y el buffer de log
 */
void exit() {
  // Guardar el archivo de slots
  if (listaPosiciones != null) {
    println("Guardando cambios al cerrar...");
    listaPosiciones.guardarEnArchivo(ARCHIVO_SLOTS);
  }
  
  // Guardar el buffer de log
  if (logger != null) {
    logger.registrarEvento("SISTEMA", "Aplicación cerrada");
    logger.guardarBuffer();
  }
  
  super.exit(); // Continuar con el cierre normal
}

/*
 * ============================================================================
 * DOCUMENTACIÓN ADICIONAL
 * ============================================================================
 *
 *
 * ============================================================================
 * PROTOCOLOS DE COMUNICACIÓN SERIAL (Arduino <-> Processing)
 * ============================================================================
 *
 * Todos los comandos terminan con '\n' (salto de línea)
 *
 * ----------------------------------------------------------------------------
 * PROCESSING -> ARDUINO (Comandos enviados)
 * ----------------------------------------------------------------------------
 *
 * "A\n" - Mover Motor X (Adelante/Positivo)
 * "B\n" - Mover Motor X (Atrás/Negativo)
 * "D\n" - Mover Motor Y (Adelante/Positivo)
 * "E\n" - Mover Motor Y (Atrás/Negativo)
 *
 * "C\n" - Iniciar calibración (Homing) del Motor X
 * "F\n" - Iniciar calibración (Homing) del Motor Y (Enviado por Processing
 * después de recibir "X Calibrado")
 *
 * "G:X,Y\n" - GoTo (Ir a posición absoluta). 
 * Ej: "G:1500,3000\n"
 *
 * "P\n" - Pedir Posición (Solicita un reporte "POS:X,Y" al Arduino)
 *
 * ----------------------------------------------------------------------------
 * ARDUINO -> PROCESSING (Mensajes recibidos)
 * ----------------------------------------------------------------------------
 *
 * "X Calibrado" - Mensaje de confirmación. Indica que el homing de X finalizó.
 * "Y Calibrado" - Mensaje de confirmación. Indica que el homing de Y finalizó.
 *
 * "POS:X,Y" - Reporte de posición actual.
 * Ej: "POS:1500,3000"
 *
 * "DHT:TEMP,HUM,HEAT_INDEX" - Reporte del sensor DHT11.
 * Ej: "DHT:25.50,45.00,26.10"
 *
 * "DHT:ERROR" - Indica un error de lectura o desconexión del sensor DHT11.
 *
 *
 * ============================================================================
 * FORMATO DE ARCHIVOS
 * ============================================================================
 *
 * 1. ARCHIVO DE LOG ("historico_eventos.csv")
 * - Formato: CSV (Valores Separados por Comas)
 * - Encabezado: TIMESTAMP,FECHA,HORA,TIPO_EVENTO,DESCRIPCION
 * - Ejemplo: 1678886400000,15/3/2025,10:00:00,INICIO,"Aplicación iniciada"
 * - Nota: La descripción se guarda entre comillas ("") para permitir
 * comas internas.
 *
 * 2. ARCHIVO DE SLOTS ("slots_posiciones.dat")
 * - Formato: Archivo de texto plano, delimitado por '|' (pipe)
 * - Estructura por línea: indice|nombre|posX|posY|ocupado
 * - Ejemplo (ocupado): 1|Posición A|12000|5000|true
 * - Ejemplo (vacío):   2||0|0|false
 *
 *
 * ============================================================================
 * LISTA DE TIPOS DE EVENTOS (LOGGING)
 * ============================================================================
 *
 * - INICIO: Aplicación iniciada
 * - SISTEMA: Eventos generales (cierre, apertura de log, carga de slots)
 * - CONEXION: Conexión exitosa al puerto serial
 * - ERROR: Errores (falla de conexión, datos corruptos, fuera de límites)
 * - CALIBRACION: Eventos del proceso (iniciado, X calibrado, Y calibrado, completado)
 * - MOVIMIENTO: Movimiento manual (X/Y adelante/atrás)
 * - POSICION_ALEATORIA: Se generó y envió un comando de pos. aleatoria
 * - MOVIMIENTO_SLOT: Se activó un "Ir a Posición" desde un slot
 * - SLOT_GUARDADO: Se guardó una nueva posición en un slot
 * - SLOT_BORRADO: Se limpió un slot
 * - SENSOR: Primera lectura exitosa del DHT11
 * - ALERTA: Eventos de sensor fuera de rango (Temp alta, Humedad elevada)
 *
 */
