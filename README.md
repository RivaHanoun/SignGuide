# SignGuide
ASL Letter Learning Glove & App (Capstone Project)

SignGuide is a wearable assistive technology project that teaches users American Sign Language (ASL) finger spelling through an interactive smart glove paired with a mobile application. By combining hardware sensors with real-time feedback in the app, SignGuide helps users learn, practice, and improve their signing skills.

---
## ✨ Features

- Interactive Glove – Equipped with flex sensors, touch sensors, and an accelerometer to detect finger and hand positions.

- Real-Time Feedback – The app analyzes hand movements and provides immediate feedback to ensure correct signing.

- Personalized Calibration – Each user can calibrate the glove to match their unique hand shape for accurate recognition.

- Learning Mode – Step-by-step lessons to practice ASL finger spelling.

- Practice Mode – Users can create custom sentences and test their skills.

---

## 🛠️ Hardware Components

- Arduino Nano – Collects and processes sensor data.

- Flex Sensors – Detect finger bends.

- Touch Sensors – Identify fingertip contact.

- Accelerometer – Tracks hand orientation and motion.
  
- HM-10 Bluetooth Module - Communication through App and Arduino
  
- Glove – Wearable base for sensors and electronics.

---
## 💻 Software Components

- Arduino Firmware – Captures sensor readings and transmits data via Bluetooth.

- iOS Application (Xcode) – Provides the interactive learning interface and feedback system.

- Detection Algorithm – Maps sensor values to ASL handshapes.

---
## Tech Stack
- Arduino (C/C++)
- SwiftUI (Xcode)
- Bluetooth HM-10
- Sensor integration (flex, touch, accelerometer/gryroscope)

---
## 🚀 Installation & Setup
### Hardware Setup

1. Solder flex sensors, touch sensors, and accelerometer onto the glove.

2. Connect sensors to the Arduino Nano according to the provided wiring diagram (coming soon in repo).

3. Place the Arduino into the plastic case for protection.

4. Ensure Bluetooth module is connected for communication with the app.

### Arduino Firmware

1. Install the Arduino IDE

2. Open the firmware/SignGuide.ino file (once added to repo).

3. Select Arduino Nano under Board Manager.

4. Upload the code to your Arduino Nano.

### iOS Application

1. Install Xcode

2. Open the SignGuideApp.xcodeproj file.

3. Pair your iPhone/iPad with the Arduino Nano via Bluetooth.

4. Build and run the app on your device.

--- 

## 📊 Results

- Fully operational glove with real-time ASL handshape recognition.

- Functional algorithm capable of detecting finger spelling gestures.

- Integrated app that connects with the glove over Bluetooth to provide lessons and feedback.

---
## 📸 Screenshots & Demo
![Sign Guide Prototype](https://github.com/user-attachments/assets/64e529b9-ece2-4406-a0d6-2315883789ca)

https://youtu.be/MtStc8kh0Go?feature=shared
---
## 🎯 Objectives

- Bridge the communication gap by helping more people learn ASL.

- Provide an intuitive, accessible, and engaging way to practice finger spelling.

- Support personalization for different hand shapes and sizes.

---
## Future Improvements

- Add support for full ASL words
  
- Improve accuracy with ML model

- Add Text-to-Sign (Practice Users can type a word or sentence, and the app will
guide the user step-by-step through each handshape.)

---
## 📚 References

- ACM Code of Ethics

- Freenove Raspberry Pi Starter Kit

Advised by Professor Hung Cao and Dr. Amir Naderi at University of California, Irvine.
