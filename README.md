# ASL Letter Learning Glove & App (Capstone Project)

A glove-based system that helps users learn the ASL alphabet.  
Built with Arduino Micro, flex sensors, pressure sensors, gyroscope/accelerometer, and Bluetooth.  
Connected to an iOS application (SwiftUI) that displays recognized letters in real-time.

## Tech Stack
- Arduino (C/C++)
- SwiftUI (Xcode)
- Bluetooth HM-10
- Sensor integration (flex, touch, accelerometer/gryroscope)

## How to Run
1. Connect Arduino Micro to glove sensors.
2. Upload Arduino sketch (`signguidefinal.ino`) via Arduino IDE.
3. Open the iOS app project in Xcode (`signguidegamma.xcodeproj`).
4. Pair Bluetooth module with iPhone and run the app.

## Demo
![Sign Guide Prototype](https://github.com/user-attachments/assets/64e529b9-ece2-4406-a0d6-2315883789ca)
https://youtu.be/MtStc8kh0Go?feature=shared

## Future Improvements
- Add support for full ASL words
- Improve accuracy with ML model
