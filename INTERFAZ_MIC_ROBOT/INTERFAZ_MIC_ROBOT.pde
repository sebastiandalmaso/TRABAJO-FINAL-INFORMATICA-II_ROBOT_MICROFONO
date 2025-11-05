import processing.serial.*;

Serial puerto;
boolean conectado = false;

// Posiciones y límites
long posX = 0;
long posY = 0;
long limiteX = 10000;
long limiteY = 10000;

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
  size(1220, 650);
  
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
  
  // Crear botones de calibración
  btnCalibrarX = new Button(80, 50, 120, 50, "CALIBRAR X", color(100, 200, 255));
  btnCalibrarY = new Button(430, 50, 120, 50, "CALIBRAR Y", color(100, 255, 100));
  
  // Botones de movimiento
  btnXAdelante = new Button(100, 250, 80, 50, "X →", color(100, 200, 255));
  btnXAtras = new Button(100, 310, 80, 50, "X ←", color(100, 200, 255));
  btnYAdelante = new Button(450, 250, 80, 50, "Y →", color(100, 255, 100));
  btnYAtras = new Button(450, 310, 80, 50, "Y ←", color(100, 255, 100));
  
  // Botones de guardado/carga (movidos a la derecha del sensor DHT11)
  btnGuardarPos = new Button(900, 50, 270, 50, "GUARDAR POSICIÓN", color(255, 200, 100));
  btnCargarPos = new Button(900, 120, 270, 50, "CARGAR POSICIÓN", color(255, 150, 100));
  btnConfigLimites = new Button(900, 190, 270, 50, "CONFIGURAR LÍMITES", color(200, 150, 255));
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
  text("Control Motores Paso a Paso", 300, 30);
  
  // Estado conexión
  textSize(20);
  fill(conectado ? color(100, 255, 100) : color(255, 100, 100));
  text(conectado ? "Estado: Conectado" : "Estado: Desconectado", 1030, 30);
  
  // Sección Motor X
  fill(255);
  textSize(18);
  textAlign(LEFT);
  text("Motor X", 80, 140);
  textSize(14);
  text("Posición: " + posX + " pasos", 80, 165);
  text("Límite: " + limiteX + " pasos", 80, 185);
  
  // Barra de progreso X
  drawProgressBar(80, 200, 180, 20, posX, limiteX, color(100, 200, 255));
  
  // Sección Motor Y
  textSize(18);
  textAlign(LEFT);
  text("Motor Y", 430, 140);
  textSize(14);
  text("Posición: " + posY + " pasos", 430, 165);
  text("Límite: " + limiteY + " pasos", 430, 185);
  
  // Barra de progreso Y
  drawProgressBar(430, 200, 180, 20, posY, limiteY, color(100, 255, 100));
  
  // Panel del sensor DHT11
  drawSensorPanel();
  
  // Panel de posiciones guardadas
  drawPosicionesPanel();
  
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

void drawPosicionesPanel() {
  // Panel de posiciones guardadas (parte inferior)
  stroke(255);
  strokeWeight(2);
  fill(40);
  rect(30, 380, 1165, 240, 10);
  
  // Título
  fill(200, 150, 255);
  textAlign(CENTER);
  textSize(18);
  text("POSICIONES GUARDADAS", 600, 405);
  
  // Dibujar todas las posiciones
  listaPosiciones.dibujar(45, 420);
  
  strokeWeight(1);
}

void drawSensorPanel() {
  // Borde del panel
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
  
  // Estado del sensor
  noStroke();
  textSize(12);
  fill(dhtValido ? color(100, 255, 100) : color(255, 100, 100));
  text(dhtValido ? "Activo" : "Sin datos", 755, 120);
  
  if (dhtValido) {
    // Icono y dato de temperatura
    fill(255, 100, 100);
    textAlign(LEFT);
    textSize(16);
    fill(255);
    textSize(14);
    text("Temperatura:", 658, 160);
    textSize(22);
    textAlign(RIGHT);
    text(nf(temperatura, 0, 1) + "°C", 850, 165);
    
    // Barra de temperatura (0-50°C)
    drawTempBar(660, 175, 180, 15, temperatura);
    
    // Icono y dato de humedad
    fill(100, 200, 255);
    textAlign(LEFT);
    textSize(16);
    
    fill(255);
    textSize(14);
    text("Humedad:", 658, 220);
    textSize(22);
    textAlign(RIGHT);
    text(nf(humedad, 0, 1) + "%", 850, 225);
    
    // Barra de humedad (0-100%)
    drawHumidityBar(660, 235, 180, 15, humedad);
    
    // Sensación térmica
    fill(255, 200, 100);
    textAlign(LEFT);
    textSize(14);
    text("Sensación térmica:", 660, 275);
    textSize(18);
    textAlign(RIGHT);
    text(nf(sensacionTermica, 0, 1) + "°C", 850, 280);
    
    // Advertencias
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

void drawConfigDialog() {
  fill(0, 0, 0, 200);
  rect(0, 0, width, height);
  
  fill(70);
  stroke(255);
  strokeWeight(2);
  rect(300, 150, 400, 300, 10);
  
  fill(255);
  textAlign(CENTER);
  textSize(20);
  text("Configurar Límites Máximos", 500, 190);
  
  textSize(16);
  textAlign(LEFT);
  text("Límite Motor X (pasos):", 330, 250);
  drawInputBox(330, 260, 340, 40, inputLimiteX, editandoLimiteX);
  
  text("Límite Motor Y (pasos):", 330, 330);
  drawInputBox(330, 340, 340, 40, inputLimiteY, editandoLimiteY);
  
  fill(100, 255, 100);
  rect(350, 390, 120, 40, 5);
  fill(255, 100, 100);
  rect(530, 390, 120, 40, 5);
  
  fill(0);
  textAlign(CENTER);
  textSize(16);
  text("APLICAR", 410, 415);
  text("CANCELAR", 590, 415);
  
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
    if (mouseX > 350 && mouseX < 470 && mouseY > 390 && mouseY < 430) {
      aplicarLimites();
      editandoLimiteX = false;
      editandoLimiteY = false;
      return;
    }
    if (mouseX > 530 && mouseX < 650 && mouseY > 390 && mouseY < 430) {
      editandoLimiteX = false;
      editandoLimiteY = false;
      return;
    }
    if (mouseX > 330 && mouseX < 670 && mouseY > 260 && mouseY < 300) {
      editandoLimiteX = true;
      editandoLimiteY = false;
      return;
    }
    if (mouseX > 330 && mouseX < 670 && mouseY > 340 && mouseY < 380) {
      editandoLimiteX = false;
      editandoLimiteY = true;
      return;
    }
    return;
  }
  
  // Verificar clicks en slots de posiciones
  int slotIndex = listaPosiciones.verificarClick(mouseX, mouseY);
  if (slotIndex >= 0) {
    return; // El click fue manejado por la lista
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
  }
  if (inputLimiteY.length() > 0) {
    limiteY = Long.parseLong(inputLimiteY);
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

// Nodo de la lista enlazada
class NodoPosicion {
  int indice;
  String nombre;
  long posX;
  long posY;
  boolean ocupado;
  boolean fueraLimites; // Nueva bandera para indicar si excede límites
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
    
    // Extraer solo el nombre del archivo sin la ruta y sin extensión
    String nombreArchivo = archivo;
    
    // Separar por barras (Windows usa \ y Unix usa /)
    if (archivo.contains("\\")) {
      String[] partes = split(archivo, '\\');
      nombreArchivo = partes[partes.length - 1];
    } else if (archivo.contains("/")) {
      String[] partes = split(archivo, '/');
      nombreArchivo = partes[partes.length - 1];
    }
    
    // Quitar la extensión .pos
    nombre = nombreArchivo.replace(".pos", "");
    ocupado = true;
    
    // Verificar si está fuera de límites
    fueraLimites = (posX > limiteX || posY > limiteY || posX < 0 || posY < 0);
    
    if (fueraLimites) {
      println("¡ADVERTENCIA Slot!" + indice + ": ¡Posición fuera de límites!");
      println("  Archivo: " + nombre);
      println("  Posición: X=" + posX + " Y=" + posY);
      println("  Límites: X=" + limiteX + " Y=" + limiteY);
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
      println("  ERROR: No se puede ir a la posición del Slot " + indice);
      println("  La posición excede los límites configurados");
      println("  Posición: X=" + posX + " Y=" + posY);
      println("  Límites: X=" + limiteX + " Y=" + limiteY);
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

// Lista enlazada de posiciones
class ListaPosiciones {
  NodoPosicion cabeza;
  int capacidad;
  float slotWidth = 180;
  float slotHeight = 160;
  float espaciado = 10;
  
  ListaPosiciones(int cap) {
    this.capacidad = cap;
    this.cabeza = null;
    
    // Crear lista enlazada
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
    // Borde del slot
    if (nodo.ocupado) {
      if (nodo.fueraLimites) {
        stroke(255, 100, 100); // Rojo si está fuera de límites
        fill(70, 40, 40); // Fondo rojizo oscuro
      } else {
        stroke(100, 255, 100); // Verde si está OK
        fill(60);
      }
    } else {
      stroke(100);
      fill(45);
    }
    strokeWeight(2);
    rect(x, y, slotWidth, slotHeight, 8);
    
    // Número del slot
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
      // Nombre del archivo cargado
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
      
      // Advertencia si está fuera de límites
      if (nodo.fueraLimites) {
        fill(255, 100, 100);
        textSize(11);
        text("⚠ FUERA DE LÍMITES", x + slotWidth/2, y + 68);
      }
      
      // Datos de posición
      fill(200);
      textSize(11);
      textAlign(CENTER);
      int offsetY = nodo.fueraLimites ? 15 : 0;
      text("X: " + nodo.posX + " pasos", x + slotWidth/2, y + 75 + offsetY);
      text("Y: " + nodo.posY + " pasos", x + slotWidth/2, y + 92 + offsetY);
      
      if (nodo.fueraLimites) {
        // Botón deshabilitado si está fuera de límites
        fill(100); // Gris oscuro
        noStroke();
        rect(x + 10, y + 120, slotWidth - 20, 28, 5);
        fill(150);
        textAlign(CENTER);
        textSize(11);
        text("NO DISPONIBLE", x + slotWidth/2, y + 137);
      } else {
        // Botón IR A POSICIÓN habilitado
        fill(100, 200, 255);
        noStroke();
        rect(x + 10, y + 105, slotWidth - 20, 28, 5);
        fill(0);
        textAlign(CENTER);
        textSize(12);
        text("IR A POSICIÓN", x + slotWidth/2, y + 122);
      }
      
      // Botón BORRAR (siempre habilitado)
      int btnBorrarY = nodo.fueraLimites ? 153 : 138;
      fill(255, 100, 100);
      rect(x + 10, y + btnBorrarY, slotWidth - 20, 18, 5);
      fill(0);
      textSize(10);
      text("BORRAR", x + slotWidth/2, y + btnBorrarY + 13);
    } else {
      // Botón CARGAR
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
      
      // Verificar si el click está dentro del slot
      if (mx > x && mx < x + slotWidth && my > y && my < y + slotHeight) {
        if (actual.ocupado) {
          if (!actual.fueraLimites) {
            // Botón IR A POSICIÓN (solo si está dentro de límites)
            if (mx > x + 10 && mx < x + slotWidth - 10 && my > y + 105 && my < y + 133) {
              actual.irAPosicion();
              return actual.indice;
            }
          }
          
          // Botón BORRAR (siempre disponible)
          int btnBorrarY = actual.fueraLimites ? 153 : 138;
          if (mx > x + 10 && mx < x + slotWidth - 10 && my > y + btnBorrarY && my < y + btnBorrarY + 18) {
            actual.limpiar();
            return actual.indice;
          }
        } else {
          // Botón CARGAR (cuando el slot está vacío)
          if (mx > x + 40 && mx < x + 140 && my > y + 70 && my < y + 110) {
            final int indiceActual = actual.indice;
            selectInput("Cargar posición en Slot " + indiceActual, "archivoSeleccionadoEnSlot");
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

int slotClickeado = -1; // Variable global para rastrear el último slot clickeado

void archivoSeleccionadoEnSlot(File selection) {
  if (selection != null) {
    // Buscar el primer slot vacío y cargarlo
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
    
    // Si no hay slots vacíos, cargar en el primero
    if (listaPosiciones.cabeza != null) {
      listaPosiciones.cabeza.cargarArchivo(selection.getAbsolutePath());
      println("Todos los slots ocupados, reemplazando Slot 1");
    }
  }
}

void archivoSeleccionado(File selection) {
  if (selection != null) {
    // Encontrar el último slot clickeado
    NodoPosicion actual = listaPosiciones.cabeza;
    while (actual != null) {
      if (!actual.ocupado) {
        actual.cargarArchivo(selection.getAbsolutePath());
        break;
      }
      actual = actual.siguiente;
    }
  }
}
