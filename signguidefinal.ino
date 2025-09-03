#include <SoftwareSerial.h> 
#include <SoftwareWire.h>  // <-- Make sure the "SoftwareWire" library is installed

// -------------------- BLUETOOTH SETUP --------------------
SoftwareSerial BTSerial(10, 11); // RX, TX on pins 10/11

// -------------------- SOFTWARE I2C SETUP --------------------
SoftwareWire swWire(8, 9); // SDA=8, SCL=9

// -------------------- MPU-6050 DEFINES --------------------
const uint8_t MPU_ADDR = 0x68;
int16_t AcX, AcY, AcZ, Tmp, GyX, GyY, GyZ;

float pitch = 0.0;  // Computed pitch angle
float roll  = 0.0;  // Computed roll angle

// -------------- J DETECTION: ACCUMULATE ROTATION AROUND Z --------------
float rotationZ = 0.0;         
unsigned long lastTimeJ = 0;   // For timing between reads
bool jMotionFlag = false;  // global flag

// -------------- Z DETECTION: ACCELEROMETER STATE MACHINE --------------
enum ZState { WAITING_FOR_SEG1, WAITING_FOR_SEG2, WAITING_FOR_SEG3, Z_COMPLETE };
ZState zState = WAITING_FOR_SEG1;
unsigned long lastMotionTime = 0; // track time for Z segments

// Tuning constants for Z detection
const float ACCEL_THRESHOLD = 0.25;   // g threshold
const unsigned long RESET_TIMEOUT = 3000; // ms to reset if no progress

// -------------------- FLEX & TOUCH SENSORS --------------------
const int numSensors = 5;
const int sensorPins[numSensors] = {A1, A2, A3, A4, A5};
const int touchPins[numSensors]  = {2, 3, 4, 5, 6};

// Additional flags and variables
bool okSent = false; 
bool calibrationStarted = false;
bool isCalibratingStep = false;
bool calibrationCompleted = false;
char currentLesson = '\0'; // 'A', 'B', 'C', ...
int tickrate = 60;

// Calibration arrays
int currentStep = -1;      
unsigned long calibrationStepStartTime = 0;
const unsigned long calibrationDuration = 5000; // 5 seconds
long sensorSum[numSensors];
int sensorCount[numSensors];
int calibrationAvg[4][numSensors];  // 0=others flexed, 1=thumb flexed, 2=half, 3=unflexed
int tolerance = 20;

// For command buffering
String commandBuffer = "";
unsigned long lastCommandTime = 0;
const unsigned long commandTimeout = 100; // ms

//Flex Sensors
#define FT 0  // Thumb
#define FI 1  // Index
#define FM 2  // Middle
#define FR 3  // Ring
#define FP 4  // Pinky

//Touch Sensors
#define TT 0  // Touch Thumb
#define TI 1  // Touch Index
#define TM 2  // Touch Middle
#define TR 3  // Touch Ring
#define TP 4  // Touch Pinky

// -------------------- 3D DISTANCE CLASSIFICATION ARRAYS --------------------
// Replace these placeholder averages with your real measured values!
float avgAx[5] = {
  -0.10, // (0) Palm forward, up
  -0.16, // (1) Palm left, up
  -0.92, // (2) Palm left, forward
  -0.20, // (3) Palm down, forward
   0.01  // (4) Palm down, fingers down
};
float avgAy[5] = {
  -0.99, // (0)
  -0.91, // (1)
  -0.15, // (2)
  -0.42, // (3)
   0.36  // (4)
};
float avgAz[5] = {
  -0.02, // (0)
  -0.26, // (1)
  -0.09, // (2)
  -0.78, // (3)
  -0.82  // (4)
};

const char* orientationNames[5] = {
  "FORWARD_UP",
  "LEFT_UP",
  "LEFT_FORWARD",
  "DOWN_FORWARD",
  "DOWN_DOWN"
};

// Single threshold for all
const float DISTANCE_THRESHOLD = 0.25;

// -------------------- SETUP --------------------
void setup() {
  Serial.begin(9600);
  BTSerial.begin(9600);

  // Initialize flex & touch pins
  for (int i = 0; i < numSensors; i++) {
    pinMode(sensorPins[i], INPUT);
    pinMode(touchPins[i], INPUT_PULLUP);
  }

  Serial.println("Waiting for app commands...");

  // Initialize software I2C + MPU-6050
  swWire.begin(); 
  // Wake up MPU-6050
  swWire.beginTransmission(MPU_ADDR);
  swWire.write(0x6B); 
  swWire.write(0);    // Clear sleep bit
  swWire.endTransmission(true);

  // Initialize timers for J & Z detection
  lastTimeJ = millis();
  lastMotionTime = millis();
  
}

// -------------------- LOOP --------------------
void loop() {
  // 1) Read incoming Bluetooth data
  while (BTSerial.available() > 0) {
    char c = BTSerial.read();
    commandBuffer += c;
    lastCommandTime = millis();
  }
  
  if (commandBuffer.length() > 0 && (millis() - lastCommandTime > commandTimeout)) {
    Serial.print("Received raw command: ");
    Serial.println(commandBuffer);
    processCommands(commandBuffer);
    commandBuffer = "";
  }
  
  // 2) Handle calibration if needed
  if (isCalibratingStep) {
    handleCalibration();
  }
  
  // 3) If calibration is done, check for lesson conditions
  if (calibrationCompleted && !isCalibratingStep) {
    // Read raw data from MPU
    float ax, ay, az;
    readMPU6050(ax, ay, az); // updates AcX, AcY, AcZ, GyX, GyY, GyZ
    //computePitchRoll(); 

    // Classify palm orientation
    //String palmOrientation = getPalmOrientation(pitch, roll);

    // Convert raw to "g"
    /*float ax = AcX / 16384.0;
    float ay = AcY / 16384.0;
    float az = AcZ / 16384.0;*/

    // Classify orientation via 3D distance
    String orientation = classifyOrientation(ax, ay, az);

    // If the user selected lesson J or Z, we update the gesture detection
    // if (!okSent) {
    //   //if (currentLesson == 'J') {
    //    // updateJDetection();  // accumulates rotationZ
    //   //}
    //   if (currentLesson == 'Z') {
    //     updateZDetection();  // uses accelerometer state machine
    //   }
    // }

    // Read flex & touch sensors
    int sensorValues[numSensors];
    for (int i = 0; i < numSensors; i++) {
      sensorValues[i] = analogRead(sensorPins[i]);
    }
    int touchValues[numSensors];
    for (int i = 0; i < numSensors; i++) {
      touchValues[i] = digitalRead(touchPins[i]);
    }

    // Define booleans for flex sensor states.
    // For THUMB (FT): fully flexed from Step 2, half flexed from Step 3, unflexed from Step 4.
    bool ftFull = (sensorValues[FT] >= (calibrationAvg[1][FT] - tolerance) && sensorValues[FT] <= (calibrationAvg[1][FT] + tolerance));
    bool ftHalf = (sensorValues[FT] >= (calibrationAvg[2][FT] - tolerance) && sensorValues[FT] <= (calibrationAvg[2][FT] + tolerance));
    bool ftUnf  = (sensorValues[FT] >= (calibrationAvg[3][FT] - tolerance) && sensorValues[FT] <= (calibrationAvg[3][FT] + tolerance));
    
    // For other fingers: fully flexed from Step 1, half flexed from Step 3, unflexed from Step 4.
    bool fiFull = (sensorValues[FI] >= (calibrationAvg[0][FI] - tolerance) && sensorValues[FI] <= (calibrationAvg[0][FI] + tolerance));
    bool fiHalf = (sensorValues[FI] >= (calibrationAvg[2][FI] - tolerance) && sensorValues[FI] <= (calibrationAvg[2][FI] + tolerance));
    bool fiUnf  = (sensorValues[FI] >= (calibrationAvg[3][FI] - tolerance) && sensorValues[FI] <= (calibrationAvg[3][FI] + tolerance));
    
    bool fmFull = (sensorValues[FM] >= (calibrationAvg[0][FM] - tolerance) && sensorValues[FM] <= (calibrationAvg[0][FM] + tolerance));
    bool fmHalf = (sensorValues[FM] >= (calibrationAvg[2][FM] - tolerance) && sensorValues[FM] <= (calibrationAvg[2][FM] + tolerance));
    bool fmUnf  = (sensorValues[FM] >= (calibrationAvg[3][FM] - tolerance) && sensorValues[FM] <= (calibrationAvg[3][FM] + tolerance));
    
    bool frFull = (sensorValues[FR] >= (calibrationAvg[0][FR] - tolerance) && sensorValues[FR] <= (calibrationAvg[0][FR] + tolerance));
    bool frHalf = (sensorValues[FR] >= (calibrationAvg[2][FR] - tolerance) && sensorValues[FR] <= (calibrationAvg[2][FR] + tolerance));
    bool frUnf  = (sensorValues[FR] >= (calibrationAvg[3][FR] - tolerance) && sensorValues[FR] <= (calibrationAvg[3][FR] + tolerance));
    
    bool fpFull = (sensorValues[FP] >= (calibrationAvg[0][FP] - tolerance) && sensorValues[FP] <= (calibrationAvg[0][FP] + tolerance));
    bool fpHalf = (sensorValues[FP] >= (calibrationAvg[2][FP] - tolerance) && sensorValues[FP] <= (calibrationAvg[2][FP] + tolerance));
    bool fpUnf  = (sensorValues[FP] >= (calibrationAvg[3][FP] - tolerance) && sensorValues[FP] <= (calibrationAvg[3][FP] + tolerance));
    
    // Define booleans for touch sensors.
    // Assume INPUT_PULLUP: not touched = LOW, touched = HIGH.
    bool ttTouched = (touchValues[TT] == HIGH);
    bool tiTouched = (touchValues[TI] == HIGH);
    bool tmTouched = (touchValues[TM] == HIGH);
    bool trTouched = (touchValues[TR] == HIGH);
    bool tpTouched = (touchValues[TP] == HIGH);

    // Example condition for "OK_A":
    // THUMB unflexed and other fingers fully flexed,
    // with THUMB NOT touched and other fingers touched.
    // --- Check conditions for each lesson ---
    if (currentLesson == 'A' && !okSent) {
      // THUMB unflexed, others fully flexed, THUMB not touched, others touched
      if (orientation == "FORWARD_UP" && ftUnf && fiFull && fmFull && frFull && fpFull &&
          !ttTouched && tiTouched && tmTouched && trTouched) { //&& tpTouched //orientation == "FORWARD_UP" &&
        BTSerial.println("OK_A");
        Serial.println("OK_A sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'B' && !okSent) {
      if (orientation == "FORWARD_UP" && ftFull && fiUnf && fmUnf && frUnf && fpUnf && !tiTouched && 
          !tmTouched && !trTouched && !tpTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_B");
        Serial.println("OK_B sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'C' && !okSent) {
      if (orientation == "LEFT_UP" && ftHalf && fiHalf && fmHalf && frHalf && fpHalf && !ttTouched &&
          !tiTouched && !tmTouched && !trTouched && !tpTouched){ //orientation == "LEFT_UP" && 
        BTSerial.println("OK_C");
        Serial.println("OK_C sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'D' && !okSent) {
      if (orientation == "FORWARD_UP" && ftHalf && fiUnf && fmHalf && frHalf && fpHalf && ttTouched && 
          !tiTouched && tmTouched && !trTouched && !tpTouched){ //orientation == "LEFT_UP" && 
        BTSerial.println("OK_D");
        Serial.println("OK_D sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'E' && !okSent) {
      if (orientation == "FORWARD_UP" && ftFull && fiFull && fmFull && frFull && fpFull){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_E");
        Serial.println("OK_E sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'F' && !okSent) {
      if (orientation == "FORWARD_UP" && ftHalf && fiHalf && fmUnf && frUnf && fpUnf && ttTouched && 
          tiTouched && !tmTouched && !trTouched && !tpTouched){
        BTSerial.println("OK_F");
        Serial.println("OK_F sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'G' && !okSent) { 
      if (orientation == "LEFT_FORWARD" && ftUnf && fiUnf && fmFull && frFull && fpFull && !ttTouched &&
          !tiTouched){
        BTSerial.println("OK_G");
        Serial.println("OK_G sent");
        okSent = true; 
      }
    }
    else if (currentLesson == 'H' && !okSent) {
      if (orientation == "LEFT_FORWARD" && ftHalf && fiUnf && fmUnf && frHalf && fpHalf && !tiTouched &&  
            !tmTouched){ //orientation == "LEFT_FORWARD" && 
        BTSerial.println("OK_H");
        Serial.println("OK_H sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'I' && !okSent) {
      if (orientation == "FORWARD_UP" && ftHalf && fiFull && fmFull && frFull && !fpFull && !tpTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_I");
        Serial.println("OK_I sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'J' && !okSent) {
      // For letter J, we do a dynamic check with the MPU-6050
      if (ftHalf && fiFull && fmFull && frFull && !fpFull && !tpTouched) { //checkForJGesture() && 
        updateJDetection();
        if (jMotionFlag){
          BTSerial.println("OK_J");
          Serial.println("OK_J sent");
          okSent = true;
        }
      }
    }
    else if (currentLesson == 'K' && !okSent) {
      if (orientation == "FORWARD_UP" && ftUnf && fiUnf && fmUnf && frFull && fpFull && !tiTouched && !tmTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_K");
        Serial.println("OK_K sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'L' && !okSent) {
      if (orientation == "FORWARD_UP" && ftUnf && fiUnf && fmFull && frFull && fpFull && !ttTouched && !tiTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_L");
        Serial.println("OK_L sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'M' && !okSent) {
      if (orientation == "FORWARD_UP" && ftUnf && fiHalf && fmHalf && frHalf && !fpUnf && tpTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_M");
        Serial.println("OK_M sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'N' && !okSent) {
      if (orientation == "FORWARD_UP" && !ftFull && fiHalf && fmHalf && !frUnf && !fpUnf && trTouched && tpTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_N");
        Serial.println("OK_N sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'O' && !okSent) {
      if (orientation == "LEFT_UP" && ftHalf && fiHalf && fmHalf && frHalf && fpHalf && ttTouched &&
        tiTouched && !tmTouched && !trTouched && !tpTouched){ //orientation == "LEFT_UP" && 
        BTSerial.println("OK_O");
        Serial.println("OK_O sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'P' && !okSent) {
      if (orientation == "DOWN_DOWN" &&  ftUnf && fiUnf && fmUnf && frHalf && fpHalf && !tiTouched &&
          !tmTouched){ //orientation == "DOWN_FORWARD" && 
        BTSerial.println("OK_P");
        Serial.println("OK_P sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'Q' && !okSent) {
      if (orientation == "DOWN_DOWN" && ftUnf && fiUnf && fmFull && frFull && fpFull && !ttTouched &&
          !tiTouched){
        BTSerial.println("OK_Q");
        Serial.println("OK_Q sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'R' && !okSent) {
      if (orientation == "FORWARD_UP" && ftHalf && fiUnf && !fmFull && frFull && fpFull && !tiTouched && !tmTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_R");
        Serial.println("OK_R sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'S' && !okSent) {
      if (orientation == "FORWARD_UP" && ftHalf && fiFull && fmFull && frFull && fpFull && tiTouched &&
          tmTouched && trTouched && tpTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_S");
        Serial.println("OK_S sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'T' && !okSent) {
      if (orientation == "FORWARD_UP" && ftUnf && fiHalf && !fmUnf && !frUnf && !fpUnf && tmTouched &&
        trTouched && tpTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_T");
        Serial.println("OK_T sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'U' && !okSent) {
      if (orientation == "FORWARD_UP" && ftHalf && fiUnf && fmUnf && frHalf && fpHalf && !tiTouched && 
            !tmTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_U");
        Serial.println("OK_U sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'V' && !okSent) {
      if (orientation == "FORWARD_UP" && ftHalf && fiUnf && fmUnf && frHalf && fpHalf && 
            !tiTouched && !tmTouched){ //orientation == "FORWARD_UP" &&  
        BTSerial.println("OK_V");
        Serial.println("OK_V sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'W' && !okSent) {
      if (orientation == "FORWARD_UP" && ftHalf && fiUnf && fmUnf && frUnf && fpFull && 
          !tiTouched && !tmTouched && !trTouched){ //orientation == "FORWARD_UP" 
        BTSerial.println("OK_W");
        Serial.println("OK_W sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'X' && !okSent) {
      if (orientation == "FORWARD_UP" && ftHalf && fiHalf && fmFull && frFull && fpFull && !tiTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_X");
        Serial.println("OK_X sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'Y' && !okSent) {
      if (orientation == "FORWARD_UP" && ftUnf && fiFull && fmFull && frFull && fpUnf && !ttTouched && !tpTouched){ //orientation == "FORWARD_UP" && 
        BTSerial.println("OK_Y");
        Serial.println("OK_Y sent");
        okSent = true;
      }
    }
    else if (currentLesson == 'Z' && !okSent) {
      if (!ftUnf && fiUnf && !fmUnf && !frUnf && !fpUnf && !tiTouched){  
        /*tickrate -= 1;
        if (tickrate == 0){
          Serial.println("1");
          tickrate = 60;
        }*/
        updateZDetection();
        if(zState == Z_COMPLETE){
          BTSerial.println("OK_Z");
          Serial.println("OK_Z sent");
          okSent = true;
        }
      }
    }
  }
}

/***** J DETECTION: Accumulate Rotation Around Z *****/
void updateJDetection() {
  unsigned long now = millis();
  float dt = (now - lastTimeJ) / 1000.0;
  lastTimeJ = now;

  // Convert raw gyroZ to deg/s (±250 => 1°/s=131 LSB)
  float gyroZdeg = (float)GyZ / 131.0;
  if (gyroZdeg > 0) {
    rotationZ += gyroZdeg * dt;
  } 
  else {
    rotationZ = 0.0;
  }

  // If rotationZ passes some threshold, we might set a flag
  // For example:
  if (!jMotionFlag && rotationZ > 35.0) {
    Serial.println("J motion threshold triggered!");
    jMotionFlag = true; 
    rotationZ = 0.0;     
  }
}

/***** Z DETECTION: Accelerometer State Machine *****/
void updateZDetection() {
  unsigned long now = millis();
  // If too long passes, reset
  if ((now - lastMotionTime) > RESET_TIMEOUT && zState != WAITING_FOR_SEG1) {
    zState = WAITING_FOR_SEG1;
    Serial.println("Z detection reset (timeout).");
  }
  //remember it is flipped 180 deg
  // Convert raw to g
  float ax = AcX / 16384.0;
  float ay = AcY / 16384.0;
  float az = (AcZ / 16384.0) - 1.0; // assume ~1g vertical

  switch (zState) {
    case WAITING_FOR_SEG1:
      // For example: left flick => ax < -0.25
      if (ax < -ACCEL_THRESHOLD -0.30) {
        zState = WAITING_FOR_SEG2;
        lastMotionTime = now;
        Serial.println("Z seg1: left flick!");
      }
      break;

    case WAITING_FOR_SEG2:
      // diagonal => ax>0.25, ay<-0.25
      if (ax > ACCEL_THRESHOLD && ay < -ACCEL_THRESHOLD) {
        zState = WAITING_FOR_SEG3;
        lastMotionTime = now;
        Serial.println("Z seg2: diagonal flick!");
      }
      break;

    case WAITING_FOR_SEG3:
      // right flick => ax>0.25, ay ~0
      if (ax < -ACCEL_THRESHOLD -0.20 && fabs(ay) < 0.2) {
        zState = Z_COMPLETE;
        lastMotionTime = now;
        Serial.println("Z seg3: right flick => Z complete!");
      }
      break;

    case Z_COMPLETE:
      // Wait a short moment, then finalize
      if ((now - lastMotionTime) > 1000) {
        Serial.println("Z motion fully detected!");
        zState = WAITING_FOR_SEG1; 
      }
      break;
  }
}

// -------------------- HELPER FUNCTIONS --------------------                       

// -------------------- RECIEVE LETTER --------------------
// Process incoming commands (like Look_A, calibration, etc.)
void processCommands(String commands) {
  Serial.print("Inside processCommands, commands = [");
  Serial.print(commands);
  Serial.println("]");

  commands.trim();
  if (commands.length() == 0) return;

  // Check for "Look_X"
  for (char c = 'A'; c <= 'Z'; c++) {
    String cmd = "Look_";
    cmd += c;
    if (commands.indexOf(cmd) != -1) {
      currentLesson = c;
      okSent = false;

      // To reset J or Z detection each time:
      if (c == 'J') {
        rotationZ = 0.0;
        jMotionFlag = false;
        lastTimeJ = millis();
      } else if (c == 'Z') {
        zState = WAITING_FOR_SEG1;
        lastMotionTime = millis();
      }

      String logMsg = "Arduino: " + cmd + " received";
      BTSerial.println(logMsg);
      Serial.println(logMsg);
      break;
    }
  }

  // -------------------- CALIBRATION --------------------
  int startIdx = 0;
  while (startIdx < commands.length()) {
    int scPos = commands.indexOf("START_CALIBRATION", startIdx);
    int stepPos = commands.indexOf("STEP_", startIdx);
    
    // If no known command is found, break out.
    if (scPos == -1 && stepPos == -1)
      break;
    
    if (scPos != -1 && (scPos < stepPos || stepPos == -1)) {
      if (!calibrationStarted) {
        calibrationStarted = true;
        //BTSerial.println("Touch: Calibration started for all sensors");
        Serial.println("Calibration started for all sensors");
      }
      startIdx = scPos + String("START_CALIBRATION").length();
    }
    else if (stepPos != -1) {
      int nextPos = commands.indexOf("START_CALIBRATION", stepPos);
      int nextStepPos = commands.indexOf("STEP_", stepPos + 1);
      int endIdx = commands.length();
      if (nextPos != -1 && nextPos < endIdx) endIdx = nextPos;
      if (nextStepPos != -1 && nextStepPos < endIdx) endIdx = nextStepPos;
      
      String stepCommand = commands.substring(stepPos, endIdx);
      stepCommand.trim();
      if (stepCommand.length() > 5) {
        String numStr = stepCommand.substring(5);
        int step = numStr.toInt();
        handleStep(step);  // Expects step 0, 1, 2, or 3.
      }
      startIdx = endIdx;
    }
    else {
      break;
    }
  }
}

// Called when we see "STEP_X" in processCommands
void handleStep(int step) {
  if (step < 0 || step > 3) {
    Serial.println("Invalid step received");
    return;
  }
  currentStep = step;
  isCalibratingStep = true;
  calibrationStepStartTime = millis();

  // Reset accumulation
  for (int i = 0; i < numSensors; i++) {
    sensorSum[i] = 0;
    sensorCount[i] = 0;
  }
  
  // Provide feedback (steps displayed as 1 to 4)
  switch (currentStep) {
    case 0:
      // Step 1: calibrate OTHER FINGERS (indices 1-4) fully flexed.
     // BTSerial.println("Touch: Processing Step 1 (Fully flexed) for INDEX, MIDDLE, RING, & PINKY. Please hold a fist for 5 seconds.");
      Serial.println("Processing Step 1 (Fully flexed) for INDEX, MIDDLE, RING, & PINKY.");
      break;
    case 1:
      // Step 2: calibrate THUMB only.
      //BTSerial.println("Touch: Processing Step 2 (Fully flexed) for THUMB only. Please hold a fist for 5 seconds.");
      Serial.println("Processing Step 2 (Fully flexed) for THUMB only.");
      break;
    case 2:
      //BTSerial.println("Touch: Processing Step 3 (Half flexed) for all sensors. Please hold a ball for 5 seconds.");
      Serial.println("Processing Step 3 (Half flexed) for all sensors.");
      break;
    case 3:
      //BTSerial.println("Touch: Processing Step 4 (Unflexed) for all sensors. Please give a high-five for 5 seconds.");
      Serial.println("Processing Step 4 (Unflexed) for all sensors.");
      break;
  }
}

// Called each loop if isCalibratingStep == true
void handleCalibration() {
  unsigned long currentTime = millis();
  if (currentTime - calibrationStepStartTime < calibrationDuration) {
    // accumulate
    for (int i = 0; i < numSensors; i++) {
      int value = analogRead(sensorPins[i]);
      sensorSum[i] += value;
      sensorCount[i]++;
    }
  }
  else {
    // calibration step is over
    isCalibratingStep = false;
    if (currentStep == 0) {
        // Step 1: Calibrate OTHER FINGERS (indices 1-4) only.
        for (int i = 1; i < numSensors; i++) {
          int avg = (sensorCount[i] > 0) ? sensorSum[i] / sensorCount[i] : 0;
          calibrationAvg[currentStep][i] = avg;
          int rangeLow = avg - tolerance;
          int rangeHigh = avg + tolerance;
          Serial.print("Step 1 complete for sensor ");
          Serial.print(i + 1);
          Serial.print(" Range: ");
          Serial.print(rangeLow);
          Serial.print(" - ");
          Serial.println(rangeHigh);
        }
      } else if (currentStep == 1) {
        // Step 2: Calibrate ONLY the THUMB (index FT).
        int avg = (sensorCount[FT] > 0) ? sensorSum[FT] / sensorCount[FT] : 0;
        calibrationAvg[currentStep][FT] = avg;
        int rangeLow = avg - 15; //int rangeLow = avg - tolerance
        int rangeHigh = avg + 15; // trying to fix the thumb  int rangeHigh = avg + tolerance
        Serial.print("Step 2 complete for THUMB: ");
        Serial.print(rangeLow);
        Serial.print(" - ");
        Serial.println(rangeHigh);
      } else {
        // Steps 3 and 4: Calibrate all sensors.
        for (int i = 0; i < numSensors; i++) {
          int avg = (sensorCount[i] > 0) ? sensorSum[i] / sensorCount[i] : 0;
          calibrationAvg[currentStep][i] = avg;
          int rangeLow = avg - tolerance;
          int rangeHigh = avg + tolerance;
          Serial.print("Step ");
          Serial.print(currentStep + 1);
          Serial.print(" complete for sensor ");
          Serial.print(i + 1);
          Serial.print(" Range: ");
          Serial.print(rangeLow);
          Serial.print(" - ");
          Serial.println(rangeHigh);
        }
      }
      
      // After final calibration step (Step 4: currentStep == 3), print summary.
      if (currentStep == 3) {
        for (int i = 0; i < numSensors; i++) {
          int fullyLow, fullyHigh;
          if (i == FT) {
            // For THUMB, fully flexed comes from Step 2.
            fullyLow = calibrationAvg[1][i] - tolerance;
            fullyHigh = calibrationAvg[1][i] + tolerance;
          } else {
            // For other fingers, fully flexed comes from Step 1.
            fullyLow = calibrationAvg[0][i] - tolerance;
            fullyHigh = calibrationAvg[0][i] + tolerance;
          }
          int halfLow = calibrationAvg[2][i] - tolerance;
          int halfHigh = calibrationAvg[2][i] + tolerance;
          int unfLow = calibrationAvg[3][i] - tolerance;
          int unfHigh = calibrationAvg[3][i] + tolerance;
          
          Serial.print("Sensor ");
          Serial.print(i + 1);
          Serial.print(" Calibrated Ranges -> Fully flexed: ");
          Serial.print(fullyLow);
          Serial.print(" - ");
          Serial.print(fullyHigh);
          Serial.print(", Half flexed: ");
          Serial.print(halfLow);
          Serial.print(" - ");
          Serial.print(halfHigh);
          Serial.print(", Unflexed: ");
          Serial.print(unfLow);
          Serial.print(" - ");
          Serial.println(unfHigh);
        }
        calibrationCompleted = true; // Mark calibration complete
        calibrationStarted = false;  // Allow new rounds if desired
      }
    }
}

// -------------------- READ MPU & 3D DISTANCE CLASSIFICATION --------------------

// Reads raw data from MPU into AcX,AcY,AcZ (and GyX,GyY,GyZ)
void readMPU6050(float &ax, float &ay, float &az) {
  swWire.beginTransmission(MPU_ADDR);
  swWire.write(0x3B);
  swWire.endTransmission(false);
  swWire.requestFrom(MPU_ADDR, (uint8_t)14);

  if (swWire.available() == 14) {
    AcX = (swWire.read() << 8) | swWire.read();
    AcY = (swWire.read() << 8) | swWire.read();
    AcZ = (swWire.read() << 8) | swWire.read();
    Tmp = (swWire.read() << 8) | swWire.read(); // not used
    GyX = (swWire.read() << 8) | swWire.read();
    GyY = (swWire.read() << 8) | swWire.read();
    GyZ = (swWire.read() << 8) | swWire.read();

    //AcX = -AcX; 
    //AcY = -AcY;
    ax = AcX / 16384.0;
    ay = AcY / 16384.0;
    az = AcZ / 16384.0;
  } 
  else {
    ax = ay = az = 0;
  }
}

// Classify by finding which average is closest in 3D
String classifyOrientation(float ax, float ay, float az) {
  int bestIndex = -1;
  float bestDist = 999999.0;

  // 1) Compute distance to each orientation's average
  for (int i = 0; i < 5; i++) {
    float dx = ax - avgAx[i];
    float dy = ay - avgAy[i];
    float dz = az - avgAz[i];
    float dist = sqrt(dx*dx + dy*dy + dz*dz);

    if (dist < bestDist) {
      bestDist = dist;
      bestIndex = i;
    }
  }

  // 2) Check if best distance is below threshold
  if (bestDist < DISTANCE_THRESHOLD) {
    return orientationNames[bestIndex];
  } else {
    return "Unknown";
  }
}

