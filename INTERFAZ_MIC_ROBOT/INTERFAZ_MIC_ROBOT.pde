import processing.serial.*;

Serial puerto;
boolean conectado = false;

// Posiciones y límites
long posX = 0;
long posY = 0;
long limiteX = 10000;
long limiteY = 10000;

// Timer para actualización automática
int ultimaActualizacion = 0;
int intervaloActualizacion = 2000; // Actualizar cada 2 segundos

// Botones de control
Button btnCalibrarX;
Button btnCalibrarY;
Button btnXAdelante;
Button btnXAtras;
Button btnYAdelante;
Button btnYAtras;

// Botones de guardado/carga
Button btnGuardarPos;
Button btnCargarPos;
Button btnConfigLimites;

// Campo de texto para límites
boolean editandoLimiteX = false;
boolean editandoLimiteY = false;
String inputLimiteX = "10000";
String inputLimiteY = "10000";

void setup() {
  size(800, 600);
  
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
  
  // Crear botones de calibración
  btnCalibrarX = new Button(80, 50, 120, 50, "CALIBRAR X", color(100, 200, 255));
  btnCalibrarY = new Button(500, 50, 120, 50, "CALIBRAR Y", color(100, 255, 100));
  
  // Botones de movimiento
  btnXAdelante = new Button(100, 250, 80, 50, "X →", color(100, 200, 255));
  btnXAtras = new Button(100, 310, 80, 50, "X ←", color(100, 200, 255));
  btnYAdelante = new Button(520, 250, 80, 50, "Y →", color(100, 255, 100));
  btnYAtras = new Button(520, 310, 80, 50, "Y ←", color(100, 255, 100));
  
  // Botones de guardado/carga
  btnGuardarPos = new Button(300, 400, 200, 50, "GUARDAR POSICIÓN", color(255, 200, 100));
  btnCargarPos = new Button(300, 460, 200, 50, "CARGAR POSICIÓN", color(255, 150, 100));
  btnConfigLimites = new Button(300, 520, 200, 50, "CONFIGURAR LÍMITES", color(200, 150, 255));
}

void draw() {
  background(50);
  
  // Actualización automática de posición
  if (conectado && millis() - ultimaActualizacion > intervaloActualizacion) {
    puerto.write("P\n");
    ultimaActualizacion = millis();
  }
  
  // Título
  fill(255);
  textAlign(CENTER);
  textSize(24);
  text("Control Motores Paso a Paso", width/2, 30);
  
  // Estado conexión
  textSize(12);
  fill(conectado ? color(100, 255, 100) : color(255, 100, 100));
  text(conectado ? "● Conectado" : "● Desconectado", width/2, height-20);
  
  // Sección Motor X
  fill(255);
  textSize(18);
  textAlign(LEFT);
  text("Motor X", 80, 140);
  textSize(14);
  text("Posición: " + posX + " pasos", 80, 165);
  text("Límite: " + limiteX + " pasos", 80, 185);
  
  // Barra de progreso X
  drawProgressBar(80, 200, 200, 20, posX, limiteX, color(100, 200, 255));
  
  // Sección Motor Y
  textSize(18);
  textAlign(LEFT);
  text("Motor Y", 500, 140);
  textSize(14);
  text("Posición: " + posY + " pasos", 500, 165);
  text("Límite: " + limiteY + " pasos", 500, 185);
  
  // Barra de progreso Y
  drawProgressBar(500, 200, 200, 20, posY, limiteY, color(100, 255, 100));
  
  // Dibujar botones
  btnCalibrarX.display();
  btnCalibrarY.display();
  btnXAdelante.display();
  btnXAtras.display();
  btnYAdelante.display();
  btnYAtras.display();
  btnGuardarPos.display();
  btnCargarPos.display();
  btnConfigLimites.display();
  
  // Diálogo de configuración de límites
  if (editandoLimiteX || editandoLimiteY) {
    drawConfigDialog();
  }
}

void drawProgressBar(float x, float y, float w, float h, long value, long max, color c) {
  // Borde
  noFill();
  stroke(255);
  rect(x, y, w, h);
  
  // Relleno
  noStroke();
  fill(c);
  float progress = constrain((float)value / max, 0, 1);
  rect(x + 2, y + 2, (w - 4) * progress, h - 4);
}

void drawConfigDialog() {
  // Fondo semi-transparente
  fill(0, 0, 0, 200);
  rect(0, 0, width, height);
  
  // Ventana de diálogo
  fill(70);
  stroke(255);
  strokeWeight(2);
  rect(200, 150, 400, 300, 10);
  
  // Título
  fill(255);
  textAlign(CENTER);
  textSize(20);
  text("Configurar Límites Máximos", 400, 190);
  
  // Campos de entrada
  textSize(16);
  textAlign(LEFT);
  text("Límite Motor X (pasos):", 230, 250);
  drawInputBox(230, 260, 340, 40, inputLimiteX, editandoLimiteX);
  
  text("Límite Motor Y (pasos):", 230, 330);
  drawInputBox(230, 340, 340, 40, inputLimiteY, editandoLimiteY);
  
  // Botones
  fill(100, 255, 100);
  rect(250, 390, 120, 40, 5);
  fill(255, 100, 100);
  rect(430, 390, 120, 40, 5);
  
  fill(0);
  textAlign(CENTER);
  textSize(16);
  text("APLICAR", 310, 415);
  text("CANCELAR", 490, 415);
  
  strokeWeight(1);
}

void drawInputBox(float x, float y, float w, float h, String text, boolean active) {
  if (active) {
    fill(255, 255, 200);
    stroke(255, 200, 0);
  } else {
    fill(255);
    stroke(200);
  }
  rect(x, y, w, h, 5);
  
  fill(0);
  textAlign(LEFT);
  text(text + (active ? "|" : ""), x + 10, y + h/2 + 6);
}

void mousePressed() {
  if (!conectado && !editandoLimiteX && !editandoLimiteY) return;
  
  // Manejo del diálogo de configuración
  if (editandoLimiteX || editandoLimiteY) {
    // Botón APLICAR
    if (mouseX > 250 && mouseX < 370 && mouseY > 390 && mouseY < 430) {
      aplicarLimites();
      editandoLimiteX = false;
      editandoLimiteY = false;
      return;
    }
    // Botón CANCELAR
    if (mouseX > 430 && mouseX < 550 && mouseY > 390 && mouseY < 430) {
      editandoLimiteX = false;
      editandoLimiteY = false;
      return;
    }
    // Campo X
    if (mouseX > 230 && mouseX < 570 && mouseY > 260 && mouseY < 300) {
      editandoLimiteX = true;
      editandoLimiteY = false;
      return;
    }
    // Campo Y
    if (mouseX > 230 && mouseX < 570 && mouseY > 340 && mouseY < 380) {
      editandoLimiteX = false;
      editandoLimiteY = true;
      return;
    }
    return;
  }
  
  // Botones normales
  if (btnCalibrarX.isPressed(mouseX, mouseY)) {
    puerto.write("C\n");
  } else if (btnCalibrarY.isPressed(mouseX, mouseY)) {
    puerto.write("F\n");
  } else if (btnXAdelante.isPressed(mouseX, mouseY)) {
    puerto.write("A\n");
  } else if (btnXAtras.isPressed(mouseX, mouseY)) {
    puerto.write("B\n");
  } else if (btnYAdelante.isPressed(mouseX, mouseY)) {
    puerto.write("D\n");
  } else if (btnYAtras.isPressed(mouseX, mouseY)) {
    puerto.write("E\n");
  } else if (btnGuardarPos.isPressed(mouseX, mouseY)) {
    puerto.write("P\n");
    guardarPosicion();
  } else if (btnCargarPos.isPressed(mouseX, mouseY)) {
    cargarPosicion();
  } else if (btnConfigLimites.isPressed(mouseX, mouseY)) {
    editandoLimiteX = true;
    editandoLimiteY = false;
    inputLimiteX = str(limiteX);
    inputLimiteY = str(limiteY);
  }
}

void keyPressed() {
  if (editandoLimiteX) {
    if (key == BACKSPACE && inputLimiteX.length() > 0) {
      inputLimiteX = inputLimiteX.substring(0, inputLimiteX.length() - 1);
    } else if (key >= '0' && key <= '9') {
      inputLimiteX += key;
    } else if (key == TAB || key == ENTER) {
      editandoLimiteX = false;
      editandoLimiteY = true;
    }
  } else if (editandoLimiteY) {
    if (key == BACKSPACE && inputLimiteY.length() > 0) {
      inputLimiteY = inputLimiteY.substring(0, inputLimiteY.length() - 1);
    } else if (key >= '0' && key <= '9') {
      inputLimiteY += key;
    } else if (key == ENTER) {
      aplicarLimites();
      editandoLimiteY = false;
    }
  }
}

void aplicarLimites() {
  if (inputLimiteX.length() > 0) {
    limiteX = Long.parseLong(inputLimiteX);
    puerto.write("LX:" + limiteX + "\n");
  }
  if (inputLimiteY.length() > 0) {
    limiteY = Long.parseLong(inputLimiteY);
    puerto.write("LY:" + limiteY + "\n");
  }
  println("Límites aplicados: X=" + limiteX + ", Y=" + limiteY);
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
      "LX:" + limiteX,
      "LY:" + limiteY
    };
    
    saveStrings(filename, data);
    println("Posición guardada: " + filename);
  }
}

void cargarPosicion() {
  selectInput("Seleccionar archivo de posición:", "archivoCargado");
}

void archivoCargado(File selection) {
  if (selection == null) {
    println("Carga cancelada");
  } else {
    String[] data = loadStrings(selection.getAbsolutePath());
    
    long targetX = 0;
    long targetY = 0;
    
    for (String line : data) {
      if (line.startsWith("X:")) {
        targetX = Long.parseLong(line.substring(2));
      } else if (line.startsWith("Y:")) {
        targetY = Long.parseLong(line.substring(2));
      } else if (line.startsWith("LX:")) {
        limiteX = Long.parseLong(line.substring(3));
      } else if (line.startsWith("LY:")) {
        limiteY = Long.parseLong(line.substring(3));
      }
    }
    
    println("Moviendo a posición: X=" + targetX + ", Y=" + targetY);
    puerto.write("G:" + targetX + "," + targetY + "\n");
  }
}

void serialEvent(Serial p) {
  String data = p.readStringUntil('\n');
  if (data != null) {
    data = trim(data);
    println("Arduino: " + data);
    
    if (data.startsWith("POS:")) {
      String[] pos = split(data.substring(4), ',');
      if (pos.length == 2) {
        posX = Long.parseLong(pos[0]);
        posY = Long.parseLong(pos[1]);
      }
    } else if (data.startsWith("LIMITES:")) {
      String[] lim = split(data.substring(8), ',');
      if (lim.length == 2) {
        limiteX = Long.parseLong(lim[0]);
        limiteY = Long.parseLong(lim[1]);
      }
    }
  }
}

// Clase botón
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
