import processing.serial.*;

Serial puerto;
boolean conectado = false;

// Estados de la aplicación
enum Estado {
  CALIBRANDO,
  OPERACIONAL
}

Estado estadoActual = Estado.CALIBRANDO;

// Variables de calibración
boolean calibracionIniciada = false;
boolean motorXCalibrado = false;
boolean motorYCalibrado = false;
float progresoCalibracion = 0;
String mensajeCalibracion = "Presiona el botón para iniciar";
Button btnIniciarCalibracion;

// Límites máximos FIJOS
final long LIMITE_MAX_X = 27000;
final long LIMITE_MAX_Y = 17000;

// Posiciones
long posX = 0;
long posY = 0;
//Posicion imagen
int px,py;
PImage P;
// Datos del sensor DHT11
float temperatura = 0;
float humedad = 0;
float sensacionTermica = 0;
boolean dhtValido = false;

// Timer para actualización automática
int ultimaActualizacion = 0;
int intervaloActualizacion = 2000;

// Lista enlazada de posiciones
ListaPosiciones listaPosiciones;

// Botones de control
Button btnXAdelante;
Button btnXAtras;
Button btnYAdelante;
Button btnYAtras;

// Botón de guardado
Button btnGuardarPos;

// Control de botones presionados continuamente
boolean btnXAdelantePresionado = false;
boolean btnXAtrasPresionado = false;
boolean btnYAdelantePresionado = false;
boolean btnYAtrasPresionado = false;
int ultimoEnvioMovimiento = 0;
int intervaloMovimiento = 100; // Enviar comando cada 100ms mientras esté presionado

void setup() {
  size(1220, 650);
  P = loadImage("utn_logo.png");
  // Inicializar lista de posiciones
  listaPosiciones = new ListaPosiciones(6);
  
  // Conectar con Arduino
  try {
    println("Puertos disponibles:");
    printArray(Serial.list());
    puerto = new Serial(this, Serial.list()[0], 9600);
    puerto.bufferUntil('\n');
    conectado = true;
  } catch (Exception e) {
    println("Error: No se pudo conectar al puerto serial");
  }
  
  // Botón de calibración inicial
  btnIniciarCalibracion = new Button(460, 350, 300, 80, "INICIAR CALIBRACIÓN", color(100, 200, 255));
  
  // Botones de movimiento
  btnXAdelante = new Button(100, 250, 80, 50, "X →", color(100, 200, 255));
  btnXAtras = new Button(100, 310, 80, 50, "X ←", color(100, 200, 255));
  btnYAdelante = new Button(450, 250, 80, 50, "Y →", color(100, 255, 100));
  btnYAtras = new Button(450, 310, 80, 50, "Y ←", color(100, 255, 100));
  
  // Botón de guardado
  btnGuardarPos = new Button(900, 50, 270, 50, "GUARDAR POSICIÓN", color(255, 200, 100));
}

void draw() {
  background(50);
  
  if (estadoActual == Estado.CALIBRANDO) {
    dibujarPantallaCalibracion();
  } else {
    dibujarInterfazPrincipal();
    manejarBotonesPresionados();
  }
}

void manejarBotonesPresionados() {
  if (!conectado) return;
  
  int tiempoActual = millis();
  if (tiempoActual - ultimoEnvioMovimiento < intervaloMovimiento) return;
  
  if (btnXAdelantePresionado && posX < LIMITE_MAX_X) {
    puerto.write("A\n");
    ultimoEnvioMovimiento = tiempoActual;
  } else if (btnXAtrasPresionado && posX > 0) {
    puerto.write("B\n");
    ultimoEnvioMovimiento = tiempoActual;
  } else if (btnYAdelantePresionado && posY < LIMITE_MAX_Y) {
    puerto.write("D\n");
    ultimoEnvioMovimiento = tiempoActual;
  } else if (btnYAtrasPresionado && posY > 0) {
    puerto.write("E\n");
    ultimoEnvioMovimiento = tiempoActual;
  }
}

void dibujarPantallaCalibracion() {
  // Estado de conexión en la esquina superior derecha
  textAlign(RIGHT);
  textSize(18);
  if (conectado) {
    fill(100, 255, 100);
    text("CONECTADO  :)", width - 30, 30);
  } else {
    fill(255, 100, 100);
    text("DESCONECTADO  :/", width - 30, 30);
  }
  
  // Título principal
  fill(255);
  textAlign(CENTER);
  textSize(48);
  text("Calibración Requerida", width/2, 150);
  
  // Subtítulo
  textSize(20);
  fill(200);
  text("Los motores deben ser calibrados antes de operar", width/2, 200);
  
  if (!calibracionIniciada) {
    // Mostrar botón de iniciar calibración solo si está conectado
    if (conectado) {
      btnIniciarCalibracion.display();
      
      // Instrucciones
      fill(150);
      textSize(16);
      text("La calibración moverá los motores hasta los finales de carrera", width/2, 500);
      text("Asegúrate de que el área esté despejada", width/2, 525);
    } else {
      // Mensaje de advertencia si no está conectado
      fill(255, 100, 100);
      textSize(24);
      text("Arduino no conectado  :(", width/2, 350);
      
      fill(200);
      textSize(16);
      text("Conecta el Arduino y reinicia la aplicación", width/2, 390);
    }
  } else {
    // Mostrar progreso de calibración
    fill(255);
    textSize(24);
    text(mensajeCalibracion, width/2, 280);
    
    // Barra de progreso
    float barWidth = 600;
    float barHeight = 40;
    float barX = (width - barWidth) / 2;
    float barY = 320;
    
    // Fondo de la barra
    noFill();
    stroke(255);
    strokeWeight(3);
    rect(barX, barY, barWidth, barHeight, 5);
    
    // Relleno de progreso
    noStroke();
    if (motorXCalibrado && motorYCalibrado) {
      fill(100, 255, 100);
    } else if (motorXCalibrado) {
      fill(100, 200, 255);
    } else {
      fill(255, 200, 100);
    }
    rect(barX + 3, barY + 3, (barWidth - 6) * progresoCalibracion, barHeight - 6, 5);
    
    // Porcentaje
    fill(255);
    textSize(20);
    text(int(progresoCalibracion * 100) + "%", width/2, barY + barHeight + 35);
    
    // Estado de motores
    textSize(16);
    fill(motorXCalibrado ? color(100, 255, 100) : color(150));
    text("Motor X: " + (motorXCalibrado ? "✓ Calibrado" : "En proceso..."), width/2 - 150, 420);
    
    fill(motorYCalibrado ? color(100, 255, 100) : color(150));
    text("Motor Y: " + (motorYCalibrado ? "✓ Calibrado" : "En proceso..."), width/2 + 150, 420);
    
    // Actualizar progreso
    actualizarProgresoCalibracion();
  }
  
  strokeWeight(1);
}

void actualizarProgresoCalibracion() {
  if (motorXCalibrado && motorYCalibrado) {
    progresoCalibracion = 1.0;
    mensajeCalibracion = "¡Calibración completada!";
    
    // Transición al estado operacional después de 1 segundo
    if (progresoCalibracion >= 1.0 && millis() % 2000 < 50) {
      estadoActual = Estado.OPERACIONAL;
      println("Sistema listo para operar");
    }
  } else if (motorXCalibrado) {
    progresoCalibracion = 0.5;
    mensajeCalibracion = "Calibrando Motor Y...";
  } else if (calibracionIniciada) {
    progresoCalibracion = 0.25;
    mensajeCalibracion = "Calibrando Motor X...";
  }
}

void dibujarInterfazPrincipal() {
  // Actualización automática de posición
  if (conectado && millis() - ultimaActualizacion > intervaloActualizacion) {
    puerto.write("P\n");
    ultimaActualizacion = millis();
  }
  //Título 1
  fill(255);
  textAlign(CENTER);
  textSize(24);
  text("Trabajo Final Informática II - Robot para micrófono", 300, 50);
  
  // Título 2
  fill(255);
  textAlign(CENTER);
  textSize(24);
  text("Control Motores Paso a Paso", 300, 100);
  
  // Estado conexión
  textSize(20);
  fill(conectado ? color(100, 255, 100) : color(255, 100, 100));
  text(conectado ? "Estado: Conectado" : "Estado: Desconectado", 1030, 30);
  //Imagen logo UTN FRM
  image(P,887,150);
  //Nombre
  fill(255);
  textSize(20);
  text("Realizado por",1030,250);
  fill(255);
  textSize(20);
  text("Dalmaso Sebastián Martín",1030,275);
  fill(255);
  textSize(20);
  text("Legajo: 50864 - Ciclo Lectivo 2025",1030,300);
  // Sección Motor X
  fill(255);
  textSize(18);
  textAlign(LEFT);
  text("Motor X", 80, 140);
  textSize(14);
  text("Posición: " + posX + " pasos", 80, 165);
  text("Límite: " + LIMITE_MAX_X + " pasos", 80, 185);
  
  // Barra de progreso X
  drawProgressBar(80, 200, 180, 20, posX, LIMITE_MAX_X, color(100, 200, 255));
  
  // Sección Motor Y
  textSize(18);
  textAlign(LEFT);
  text("Motor Y", 430, 140);
  textSize(14);
  text("Posición: " + posY + " pasos", 430, 165);
  text("Límite: " + LIMITE_MAX_Y + " pasos", 430, 185);
  
  // Barra de progreso Y
  drawProgressBar(430, 200, 180, 20, posY, LIMITE_MAX_Y, color(100, 255, 100));
  
  // Panel del sensor DHT11
  drawSensorPanel();
  
  // Panel de posiciones guardadas
  drawPosicionesPanel();
  
  // Dibujar botones
  btnXAdelante.display();
  btnXAtras.display();
  btnYAdelante.display();
  btnYAtras.display();
  btnGuardarPos.display();
}

void drawPosicionesPanel() {
  stroke(255);
  strokeWeight(2);
  fill(40);
  rect(30, 380, 1165, 240, 10);
  
  fill(200, 150, 255);
  textAlign(CENTER);
  textSize(18);
  text("POSICIONES GUARDADAS", 600, 405);
  
  listaPosiciones.dibujar(45, 420);
  
  strokeWeight(1);
}

void drawSensorPanel() {
  stroke(255);
  strokeWeight(2);
  fill(40);
  rect(640, 50, 230, 280, 10);
  
  fill(255, 200, 100);
  textAlign(CENTER);
  textSize(20);
  text("Sensor DHT11", 755, 85);
  
  stroke(100);
  line(660, 100, 850, 100);
  
  noStroke();
  textSize(12);
  fill(dhtValido ? color(100, 255, 100) : color(255, 100, 100));
  text(dhtValido ? "Activo" : "Sin datos", 755, 120);
  
  if (dhtValido) {
    fill(255);
    textSize(14);
    text("Temperatura:", 696, 160);
    textSize(22);
    textAlign(RIGHT);
    text(nf(temperatura, 0, 1) + "°C", 850, 165);
    
    drawTempBar(660, 175, 180, 15, temperatura);
    
    fill(255);
    textSize(14);
    textAlign(LEFT);
    text("Humedad:", 658, 220);
    textSize(22);
    textAlign(RIGHT);
    text(nf(humedad, 0, 1) + "%", 850, 225);
    
    drawHumidityBar(660, 235, 180, 15, humedad);
    
    fill(255, 200, 100);
    textAlign(LEFT);
    textSize(14);
    text("Sensación térmica:", 660, 275);
    textSize(18);
    textAlign(RIGHT);
    text(nf(sensacionTermica, 0, 1) + "°C", 850, 280);
    
    if (temperatura > 35) {
      fill(255, 100, 100);
      textAlign(CENTER);
      textSize(12);
      text("Temperatura alta", 755, 310);
    } else if (humedad > 80) {
      fill(255, 200, 100);
      textAlign(CENTER);
      textSize(12);
      text("Humedad elevada", 755, 310);
    }
  } else {
    fill(150);
    textAlign(CENTER);
    textSize(14);
    text("Esperando datos\ndel sensor...", 755, 200);
  }
  
  strokeWeight(1);
}

void drawTempBar(float x, float y, float w, float h, float temp) {
  noFill();
  stroke(255, 100, 100);
  rect(x, y, w, h);
  
  noStroke();
  float progress = constrain(temp / 50.0, 0, 1);
  
  if (temp < 20) {
    fill(100, 150, 255);
  } else if (temp < 28) {
    fill(100, 255, 100);
  } else if (temp < 35) {
    fill(255, 200, 100);
  } else {
    fill(255, 100, 100);
  }
  
  rect(x + 2, y + 2, (w - 4) * progress, h - 4);
}

void drawHumidityBar(float x, float y, float w, float h, float hum) {
  noFill();
  stroke(100, 200, 255);
  rect(x, y, w, h);
  
  noStroke();
  float progress = constrain(hum / 100.0, 0, 1);
  fill(100, 200, 255);
  rect(x + 2, y + 2, (w - 4) * progress, h - 4);
}

void drawProgressBar(float x, float y, float w, float h, long value, long max, color c) {
  noFill();
  stroke(255);
  rect(x, y, w, h);
  
  noStroke();
  fill(c);
  float progress = constrain((float)value / max, 0, 1);
  rect(x + 2, y + 2, (w - 4) * progress, h - 4);
}

void mousePressed() {
  if (estadoActual == Estado.CALIBRANDO) {
    if (!calibracionIniciada && btnIniciarCalibracion.isPressed(mouseX, mouseY)) {
      iniciarCalibracion();
    }
    return;
  }
  
  if (!conectado) return;
  
  int slotIndex = listaPosiciones.verificarClick(mouseX, mouseY);
  if (slotIndex >= 0) {
    return;
  }
  
  // Detectar presión de botones de movimiento
  if (btnXAdelante.isPressed(mouseX, mouseY)) {
    btnXAdelantePresionado = true;
    if (posX < LIMITE_MAX_X) {
      puerto.write("A\n");
      ultimoEnvioMovimiento = millis();
    }
  } else if (btnXAtras.isPressed(mouseX, mouseY)) {
    btnXAtrasPresionado = true;
    if (posX > 0) {
      puerto.write("B\n");
      ultimoEnvioMovimiento = millis();
    }
  } else if (btnYAdelante.isPressed(mouseX, mouseY)) {
    btnYAdelantePresionado = true;
    if (posY < LIMITE_MAX_Y) {
      puerto.write("D\n");
      ultimoEnvioMovimiento = millis();
    }
  } else if (btnYAtras.isPressed(mouseX, mouseY)) {
    btnYAtrasPresionado = true;
    if (posY > 0) {
      puerto.write("E\n");
      ultimoEnvioMovimiento = millis();
    }
  } else if (btnGuardarPos.isPressed(mouseX, mouseY)) {
    puerto.write("P\n");
    guardarPosicion();
  }
}

void mouseReleased() {
  // Liberar todos los botones de movimiento
  btnXAdelantePresionado = false;
  btnXAtrasPresionado = false;
  btnYAdelantePresionado = false;
  btnYAtrasPresionado = false;
}

void iniciarCalibracion() {
  calibracionIniciada = true;
  motorXCalibrado = false;
  motorYCalibrado = false;
  progresoCalibracion = 0;
  
  if (conectado) {
    println("Iniciando calibración...");
    puerto.write("C\n");
  } else {
    println("ERROR: No hay conexión con Arduino");
  }
}

void guardarPosicion() {
  selectOutput("Guardar posición como:", "archivoGuardado");
}

void archivoGuardado(File selection) {
  if (selection == null) {
    println("Guardado cancelado");
  } else {
    String filename = selection.getAbsolutePath();
    if (!filename.endsWith(".pos")) {
      filename += ".pos";
    }
    
    String[] data = {
      "X:" + posX,
      "Y:" + posY,
      "LX:" + LIMITE_MAX_X,
      "LY:" + LIMITE_MAX_Y
    };
    
    saveStrings(filename, data);
    println("Posición guardada: " + filename);
  }
}

void serialEvent(Serial p) {
  String data = p.readStringUntil('\n');
  if (data != null) {
    data = trim(data);
    println("Arduino: " + data);
    
    if (data.equals("X Calibrado")) {
      motorXCalibrado = true;
      if (calibracionIniciada && !motorYCalibrado) {
        puerto.write("F\n");
      }
    } else if (data.equals("Y Calibrado")) {
      motorYCalibrado = true;
    } else if (data.startsWith("POS:")) {
      String[] pos = split(data.substring(4), ',');
      if (pos.length == 2) {
        posX = Long.parseLong(pos[0]);
        posY = Long.parseLong(pos[1]);
      }
    } else if (data.startsWith("DHT:")) {
      String[] valores = split(data.substring(4), ',');
      if (valores.length == 3) {
        temperatura = Float.parseFloat(valores[0]);
        humedad = Float.parseFloat(valores[1]);
        sensacionTermica = Float.parseFloat(valores[2]);
        dhtValido = true;
      }
    } else if (data.equals("DHT:ERROR")) {
      dhtValido = false;
    }
  }
}

// ============ CLASES ============

class Button {
  float x, y, w, h;
  String label;
  color c;
  
  Button(float x, float y, float w, float h, String label, color c) {
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.label = label;
    this.c = c;
  }
  
  void display() {
    boolean hover = isPressed(mouseX, mouseY);
    fill(hover ? color(red(c)+30, green(c)+30, blue(c)+30) : c);
    stroke(255);
    strokeWeight(2);
    rect(x, y, w, h, 8);
    fill(0);
    textAlign(CENTER, CENTER);
    textSize(14);
    text(label, x+w/2, y+h/2);
    strokeWeight(1);
  }
  
  boolean isPressed(float mx, float my) {
    return mx > x && mx < x+w && my > y && my < y+h;
  }
}

class NodoPosicion {
  int indice;
  String nombre;
  long posX;
  long posY;
  boolean ocupado;
  boolean fueraLimites;
  NodoPosicion siguiente;
  
  NodoPosicion(int idx) {
    this.indice = idx;
    this.nombre = "";
    this.posX = 0;
    this.posY = 0;
    this.ocupado = false;
    this.fueraLimites = false;
    this.siguiente = null;
  }
  
  void cargarArchivo(String archivo) {
    String[] data = loadStrings(archivo);
    
    for (String line : data) {
      if (line.startsWith("X:")) {
        posX = Long.parseLong(line.substring(2));
      } else if (line.startsWith("Y:")) {
        posY = Long.parseLong(line.substring(2));
      }
    }
    
    String nombreArchivo = archivo;
    
    if (archivo.contains("\\")) {
      String[] partes = split(archivo, '\\');
      nombreArchivo = partes[partes.length - 1];
    } else if (archivo.contains("/")) {
      String[] partes = split(archivo, '/');
      nombreArchivo = partes[partes.length - 1];
    }
    
    nombre = nombreArchivo.replace(".pos", "");
    ocupado = true;
    
    fueraLimites = (posX > LIMITE_MAX_X || posY > LIMITE_MAX_Y || posX < 0 || posY < 0);
    
    if (fueraLimites) {
      println("¡ADVERTENCIA Slot " + indice + ": ¡Posición fuera de límites!");
      println("  Archivo: " + nombre);
      println("  Posición: X=" + posX + " Y=" + posY);
      println("  Límites: X=" + LIMITE_MAX_X + " Y=" + LIMITE_MAX_Y);
    } else {
      println("✓ Slot " + indice + " cargado: " + nombre + " (X:" + posX + ", Y:" + posY + ")");
    }
  }
  
  void irAPosicion() {
    if (!ocupado) {
      println("Error: Slot " + indice + " está vacío");
      return;
    }
    
    if (fueraLimites) {
      println("ERROR: No se puede ir a la posición del Slot " + indice);
      println("La posición excede los límites configurados");
      println("Posición: X=" + posX + " Y=" + posY);
      println("Límites: X=" + LIMITE_MAX_X + " Y=" + LIMITE_MAX_Y);
      return;
    }
    
    if (!conectado) {
      println("Error: No hay conexión con Arduino");
      return;
    }
    
    String comando = "G:" + posX + "," + posY + "\n";
    puerto.write(comando);
    println("Comando enviado: " + comando.trim());
    println("Yendo a posición Slot " + indice + ": " + nombre + " (X:" + posX + ", Y:" + posY + ")");
  }
  
  void limpiar() {
    nombre = "";
    posX = 0;
    posY = 0;
    ocupado = false;
    fueraLimites = false;
    println("Slot " + indice + " limpiado");
  }
}

class ListaPosiciones {
  NodoPosicion cabeza;
  int capacidad;
  float slotWidth = 180;
  float slotHeight = 160;
  float espaciado = 10;
  
  ListaPosiciones(int cap) {
    this.capacidad = cap;
    this.cabeza = null;
    
    for (int i = 0; i < capacidad; i++) {
      agregar(new NodoPosicion(i + 1));
    }
  }
  
  void agregar(NodoPosicion nuevo) {
    if (cabeza == null) {
      cabeza = nuevo;
    } else {
      NodoPosicion actual = cabeza;
      while (actual.siguiente != null) {
        actual = actual.siguiente;
      }
      actual.siguiente = nuevo;
    }
  }
  
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
  
  void dibujar(float startX, float startY) {
    NodoPosicion actual = cabeza;
    int contador = 0;
    
    while (actual != null) {
      float x = startX + (contador * (slotWidth + espaciado));
      float y = startY;
      
      dibujarSlot(actual, x, y);
      
      actual = actual.siguiente;
      contador++;
    }
  }
  
  void dibujarSlot(NodoPosicion nodo, float x, float y) {
    if (nodo.ocupado) {
      if (nodo.fueraLimites) {
        stroke(255, 100, 100);
        fill(70, 40, 40);
      } else {
        stroke(100, 255, 100);
        fill(60);
      }
    } else {
      stroke(100);
      fill(45);
    }
    strokeWeight(2);
    rect(x, y, slotWidth, slotHeight, 8);
    
    if (nodo.ocupado) {
      if (nodo.fueraLimites) {
        fill(255, 100, 100);
      } else {
        fill(100, 255, 100);
      }
    } else {
      fill(150);
    }
    textAlign(CENTER);
    textSize(16);
    text("Slot " + nodo.indice, x + slotWidth/2, y + 25);
    
    if (nodo.ocupado) {
      if (nodo.fueraLimites) {
        fill(255, 150, 100);
      } else {
        fill(255, 200, 100);
      }
      textSize(13);
      textAlign(CENTER);
      String nombreMostrar = nodo.nombre;
      if (nombreMostrar.length() > 18) {
        nombreMostrar = nombreMostrar.substring(0, 15) + "...";
      }
      text(nombreMostrar, x + slotWidth/2, y + 50);
      
      if (nodo.fueraLimites) {
        fill(255, 100, 100);
        textSize(11);
        text("FUERA DE LÍMITES", x + slotWidth/2, y + 68);
      }
      
      fill(200);
      textSize(11);
      textAlign(CENTER);
      int offsetY = nodo.fueraLimites ? 15 : 0;
      text("X: " + nodo.posX + " pasos", x + slotWidth/2, y + 75 + offsetY);
      text("Y: " + nodo.posY + " pasos", x + slotWidth/2, y + 92 + offsetY);
      
      if (nodo.fueraLimites) {
        fill(100);
        noStroke();
        rect(x + 10, y + 120, slotWidth - 20, 28, 5);
        fill(150);
        textAlign(CENTER);
        textSize(11);
        text("NO DISPONIBLE", x + slotWidth/2, y + 137);
      } else {
        fill(100, 200, 255);
        noStroke();
        rect(x + 10, y + 105, slotWidth - 20, 28, 5);
        fill(0);
        textAlign(CENTER);
        textSize(12);
        text("IR A POSICIÓN", x + slotWidth/2, y + 122);
      }
      
      int btnBorrarY = nodo.fueraLimites ? 153 : 138;
      fill(255, 100, 100);
      rect(x + 10, y + btnBorrarY, slotWidth - 20, 18, 5);
      fill(0);
      textSize(10);
      text("BORRAR", x + slotWidth/2, y + btnBorrarY + 13);
    } else {
      fill(150);
      noStroke();
      rect(x + 40, y + 70, 100, 40, 5);
      fill(255);
      textAlign(CENTER);
      textSize(14);
      text("CARGAR", x + 90, y + 93);
    }
    
    strokeWeight(1);
  }
  
  int verificarClick(float mx, float my) {
    NodoPosicion actual = cabeza;
    int contador = 0;
    float startX = 45;
    float startY = 420;
    
    while (actual != null) {
      float x = startX + (contador * (slotWidth + espaciado));
      float y = startY;
      
      if (mx > x && mx < x + slotWidth && my > y && my < y + slotHeight) {
        if (actual.ocupado) {
          if (!actual.fueraLimites) {
            if (mx > x + 10 && mx < x + slotWidth - 10 && my > y + 105 && my < y + 133) {
              actual.irAPosicion();
              return actual.indice;
            }
          }
          
          int btnBorrarY = actual.fueraLimites ? 153 : 138;
          if (mx > x + 10 && mx < x + slotWidth - 10 && my > y + btnBorrarY && my < y + btnBorrarY + 18) {
            actual.limpiar();
            return actual.indice;
          }
        } else {
          if (mx > x + 40 && mx < x + 140 && my > y + 70 && my < y + 110) {
            selectInput("Cargar posición en Slot " + actual.indice, "archivoSeleccionadoEnSlot");
            return actual.indice;
          }
        }
      }
      
      actual = actual.siguiente;
      contador++;
    }
    
    return -1;
  }
}

void archivoSeleccionadoEnSlot(File selection) {
  if (selection != null) {
    NodoPosicion actual = listaPosiciones.cabeza;
    int contador = 1;
    
    while (actual != null) {
      if (!actual.ocupado) {
        actual.cargarArchivo(selection.getAbsolutePath());
        println("Archivo cargado en Slot " + contador);
        return;
      }
      actual = actual.siguiente;
      contador++;
    }
    
    if (listaPosiciones.cabeza != null) {
      listaPosiciones.cabeza.cargarArchivo(selection.getAbsolutePath());
      println("Todos los slots ocupados, reemplazando Slot 1");
    }
  }
}
