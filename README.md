![MATRIXLED.Wallpaper](assets/MATRIX.LED.jpeg)


# MATRIX LED Controller

High-Performance LED Controller System bestehend aus einem ESP32 (Web UI & Effekte) und einem Teensy 4.0 (LED Treiber & USB Interface).

## Features

*   **Dual-Core Architektur:**
*   **ESP32:** Webinterface, WiFi-Management, Matrix-Regen-Berechnung.
*   **Teensy 4.0:** High-Speed APA102 Treiber (SPI @ 16MHz), USB Adalight Interface, OLED Status-Display.
*   **Web Interface:** Modernes React-basiertes UI zur Steuerung von Effekten, Farben und Helligkeit.
*   **Effekte:** Matrix Rain (3D/2D), Fire, Plasma, Rainbow, und mehr.
*   **Ambilight:** Unterstützt PC-Synchronisation via USB (Adalight Protokoll, z.B. Prismatik/Hyperion).
*   **OLED Display:** Zeigt FPS, Systemstatus und IP-Adresse am Controller an.

## Installation

Die kompilierten Firmware-Dateien befinden sich im Ordner `Firmware`.

### 1. Teensy 4.0 flashen
*   Benötigte Software: Teensy Loader
*   Datei: `Firmware/Teensy_Matrix.hex`
*   Verbinde den Teensy per USB, drücke den Reset-Knopf am Teensy und lade die .hex Datei hoch.

### 2. ESP32 flashen
*   Benötigte Software: Esptool oder ESP Download Tool.
*   **Partitionstabelle:** `Firmware/partitions.bin` an Adresse `0x8000`
*   **Firmware:** `Firmware/ESP32_Matrix.bin` an Adresse `0x10000`

## Erste Schritte

1.  **Hardware verbinden:** Stelle sicher, dass ESP32 und Teensy korrekt verbunden sind (RX/TX für Kommunikation, Trigger-Pin).
2.  **WiFi Setup:**
    *   Beim ersten Start (oder nach Reset) erstellt der ESP32 einen Access Point namens **MATRIX-SETUP**.
    *   Verbinde dich mit dem WLAN.
    *   Öffne `192.168.4.1` im Browser.
    *   Gib deine WLAN-SSID und das Passwort ein.
    *   Das System startet neu und verbindet sich mit deinem Heimnetzwerk.
3.  **LED Konfiguration:**
    *   Der Teensy lernt die Anzahl der LEDs automatisch beim ersten Kontakt mit der PC-Software (Adalight Header) oder kann manuell über das Webinterface konfiguriert werden.

## Hardware Specs

*   **Controller 1:** Teensy 4.0 (übertaktet auf 696 MHz)
*   **Controller 2:** ESP32 DevKit V4
*   **LEDs:** APA102C (SPI)
*   **Display:** SH1106 OLED (I2C) = Teensy 4.0
*   **Display:** ST7789V 240x320 (SPI) = ESP32 DevKit V4




   
## [ HIGH-PERFORMANCE PIPELINE ARCHITECTURE Teensy 4.0 ]
    
    1. CORE ARCHITECTURE  (Teensy 4.0) (Cortex-M7)
      - High-performance NXP i.MX RT1062 crossover MCU delivers real-time operation 
      - Clock: 696 MHz (Overclocked via CCM registers)
      - VCore: 1.200V (Dynamic Voltage Scaling via PMU_REG_CORE 0x14)
      - FPU:   Double Precision Hardware Floating Point Unit enabled
   
   2. MEMORY HIERARCHY (Tightly Coupled Memory)
      - ITCM (Instruction TCM): 64-bit Bus, 0 Wait-States.
        -> Hält "Hot Path" Code: processLEDs(), sendOutBuffer(), readExact().
        -> Verhindert Cache-Misses und Pipeline-Stalls bei kritischen Loops.
        - DTCM (Data TCM): 64-bit Bus, 0 Wait-States.
        -> Hält Stack, Frame-Buffer (rgbIn, outBufA/B) und globale Variablen.
        -> Ermöglicht Single-Cycle Zugriff auf LED-Daten.
   
## [ DATA PIPELINE: "ZERO-COPY" DOUBLE BUFFERING ]
   -------------------------------------------------------------------------
   STAGE 1: INGEST (USB High-Speed 480 Mbit/s)
      - Hardware: USB PHY -> Internal 512 Byte DMA Ring Buffer.
      - Software: readExact() (ITCM) liest Block-weise in 'rgbIn' (DTCM).
      - Protocol: Adalight Header Check ("Ada") + Checksum/Timeout Logic.
   
   STAGE 2: PROCESSING (SIMD-like Integer Math)
      - Function: processLEDs() (ITCM, FASTRUN).
      - Input:    8-Bit RGB Array (rgbIn).
      - Op:       Bit-Shifting & Masking (keine Divisionen).
      - Scaling:  Fixed-Point Helligkeitsberechnung ((val * brightness) >> 8).
      - Feature:  Color Clustering (Smart Downsampling) for ESP32 Preview.
      - Output:   32-Bit APA102 Frames (0xFF | B | G | R) direkt in 'backBuf'.
   
   STAGE 3: SWAP (Atomic Transition)
      - Trigger:  Sobald Frame vollständig verarbeitet ist.
      - Action:   Pointer Swap (frontBuf <-> backBuf).
      - Cost:     Nahezu 0 CPU-Zyklen (nur Zeiger-Adressen tauschen).
   
   STAGE 4: PRIMARY EGEST (LPSPI Output @ 16 MHz)
      - Hardware: Low Power SPI (LPSPI) Modul.
      - Function: sendOutBuffer() (ITCM).
      - Data:     Liest von 'frontBuf' (DTCM).
      - Timing:   Asynchron zur USB-Eingabe (entkoppelt durch Buffer).
   
   STAGE 5: SECONDARY EGEST (UART @ 4 Mbit/s)
      - Hardware: High-Speed UART (Serial1).
      - Target:   ESP32 Web Controller (Telemetry & Preview).
      - Data:     Cluster-Downsampled RGB + Status (Binary Protocol).

## [ TELEMETRY & SUPERVISOR ]
   -------------------------------------------------------------------------
   - LPI2C (OLED): Overclocked auf 1 MHz (Fast Mode Plus) für min. Latenz.
   - FPS Engine:   Exponential Moving Average (EMA) Filter für glatte Anzeige.
   - 3D Engine:    Real-time FPU projection engine (Boot Animations).
   - Diagnostics:  Startup Benchmarking (I2C Latency Check).
   - Thermal:      Überwachung der Die-Temperatur (tempmon).
   - Load Monitor: Messung der aktiven CPU-Zyklen vs. Idle-Time.
   - Watchdogs:    Screensaver (20s Idle) & Deep Standby (10min Idle).
