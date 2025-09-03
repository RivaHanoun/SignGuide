//
//  BluetoothManager.swift
//  signguide
//
//  Created by Riva on 1/9/25.
//
/*import CoreBluetooth
import SwiftUI

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    var centralManager: CBCentralManager!
    var connectedPeripheral: CBPeripheral?
    
    var messageBuffer: String = ""

    @Published var isConnected: Bool = false
    //@Published var receivedMessage: String = "Waiting for message ..."
    @Published var touchMessage: String = ""
    @Published var flexMessage: String = ""


    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is powered on. Scanning for peripherals...")
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            print("Bluetooth is not available.")
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        if let peripheralName = peripheral.name, peripheralName == "DSD TECH" {
            centralManager.stopScan()
            connectedPeripheral = peripheral
            centralManager.connect(peripheral, options: nil)
            print("Found DSD TECH! Connecting...")
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        print("Connected to \(peripheral.name ?? "Unknown")")
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        print("Failed to connect to \(peripheral.name ?? "Unknown")")
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }

        for service in peripheral.services ?? [] {
            peripheral.discoverCharacteristics(nil, for: service)
            print("Discovered services for \(peripheral.name ?? "Unknown")")
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("Error discovering characteristics: \(error.localizedDescription)")
            return
        }

        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == CBUUID(string: "FFE1") {
                print("Found FFE1 characteristic, checking properties...")

                if characteristic.properties.contains(.notify) {
                    print("FFE1 supports notifications, subscribing...")
                    peripheral.setNotifyValue(true, for: characteristic)
                } else {
                    print("FFE1 does not support notifications.")
                }
            }
        }
    }

    /*func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value for characteristic: \(error.localizedDescription)")
            return
        }

        if let value = characteristic.value {
            //print("Received raw data (hex): \(value.hexEncodedString())")
            if let message = String(data: value, encoding: .utf8) {
                print("Received data: \(message)")
                receivedMessage = message
            } else {
                print("Received data doesn't match UTF-8 encoding")
            }
        }
    }*/
    
    /*func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
       /* if let error = error {
            print("Error updating value for characteristic: (error.localizedDescription)")
            return
        }*/

        if let value = characteristic.value {
            // Convert the received data to a UTF-8 string
            if let message = String(data: value, encoding: .utf8) {
                print("Received data: \(message)") // Print received data
                messageBuffer += message

                // Check if the message contains "Touch detected"
                if message.contains("Pointer touched") {
                    DispatchQueue.main.async {
                        self.touchMessage = message // Update touchMessage
                    }
                }
                // Check if the message contains "Flex:"
                else if message.contains("Flex: ") {
                    DispatchQueue.main.async {
                        self.flexMessage = message // Update flexMessage
                    }
                } else {
                    print("Received message doesn't match touch or flex pattern.")
                }
            } else {
                print("Received data doesn't match UTF-8 encoding")
            }
        }
    }*/
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
           if let value = characteristic.value, let message = String(data: value, encoding: .utf8) {
               // Accumulate the data into the buffer
               messageBuffer += message

               // Check if the message has a complete line (ending with \n)
               if messageBuffer.contains("\n") {
                   // Split the buffer by newline and process each message separately
                   let messages = messageBuffer.split(separator: "\n")
                   for message in messages {
                       if message.contains("Pointer touched") {
                           // Process touch message
                           touchMessage = String(message)
                       } else if message.contains("Flex: ") {
                           // Process flex message
                           flexMessage = String(message)
                       }
                       print("Received data: (message)")  // Debugging
                   }
                   // Clear the buffer after processing the messages
                   messageBuffer = ""
               }
           }
       }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "%02x", $0) }.joined()
    }
}*/

import CoreBluetooth
import SwiftUI

class BluetoothManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, ObservableObject {
    @Published var isConnected = false
    @Published var receivedFlexValue: Int?  // Latest flex value
    @Published var receivedTouchMessage: String?  // Latest touch message
    @Published var latestReceivedMessage: String? = nil

    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?

    private var collectingValues = false
    private var valueHandler: ((Int) -> Void)?

    private var fullyFlexedRange: ClosedRange<Int>?
    private var halfFlexedRange: ClosedRange<Int>?
    private var unflexedRange: ClosedRange<Int>?
    
    private var messageBuffer = ""
    

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Central Manager Delegate
    
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        } else {
            isConnected = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if peripheral.name?.contains("DSD TECH") ?? false {
            self.peripheral = peripheral
            centralManager.stopScan()
            centralManager.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        self.peripheral = peripheral
        isConnected = true
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for char in characteristics {
            if char.properties.contains(.notify) {
                self.characteristic = char
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }

    /*func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let value = characteristic.value, let message = String(data: value, encoding: .utf8) {
            parseReceivedMessage(message)
        }
    }*/
    
    func peripheral(_ peripheral: CBPeripheral,
                        didUpdateValueFor characteristic: CBCharacteristic,
                        error: Error?) {
        if let error = error {
             print("Error updating value: \(error)")
             return
             }
             guard let data = characteristic.value else { return }
             updateReceivedMessage(with: data)
        }
    

    // MARK: - Message Parsing

    /*private func parseReceivedMessage(_ message: String) {
        if message.starts(with: "Flex:") {
            if let flexValue = Int(message.replacingOccurrences(of: "Flex: ", with: "")) {
                receivedFlexValue = flexValue
                if collectingValues {
                    valueHandler?(flexValue)
                }
            }
        } else if message.starts(with: "Touch:") {
            receivedTouchMessage = message.replacingOccurrences(of: "Touch: ", with: "")
        }
    }*/

    // MARK: - Calibration Functions

    func startCollectingValues(_ handler: @escaping (Int) -> Void) {
        collectingValues = true
        valueHandler = handler
    }

    func stopCollectingValues() {
        collectingValues = false
        valueHandler = nil
    }

    /*func setCalibrationRanges(fullyFlexed: ClosedRange<Int>, halfFlexed: ClosedRange<Int>, unflexed: ClosedRange<Int>) {
        self.fullyFlexedRange = fullyFlexed
        self.halfFlexedRange = halfFlexed
        self.unflexedRange = unflexed
    }

    // Use these ranges in your app logic if needed
    func flexState(for value: Int) -> String {
        if let range = fullyFlexedRange, range.contains(value) {
            return "Fully Flexed"
        } else if let range = halfFlexedRange, range.contains(value) {
            return "Half Flexed"
        } else if let range = unflexedRange, range.contains(value) {
            return "Unflexed"
        } else {
            return "Unknown"
        }
    }*/
    
    func sendStartCalibrationSignal() {
        guard let peripheral = self.peripheral, let characteristic = self.characteristic else {
            print("Peripheral or characteristic is nil!")
            return
        }

        let message = "START_CALIBRATION" // Custom message to trigger calibration
        print("Sending: \(message)")
        guard let data = message.data(using: .utf8) else {
            print("Failed to encode message to data.")
            return
        }

        if characteristic.properties.contains(.write) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        } else if characteristic.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        } else {
            print("Characteristic does not support write operations.")
        }
    }
    
    func sendCalibrationStep(step: Int) {
        guard let peripheral = self.peripheral, let characteristic = self.characteristic else {
            print("Peripheral or characteristic is nil!")
            return
        }

        let message = "STEP_\(step)" // Command to switch calibration steps
        guard let data = message.data(using: .utf8) else {
            print("Failed to encode message to data.")
            return
        }

        if characteristic.properties.contains(.write) {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        } else if characteristic.properties.contains(.writeWithoutResponse) {
            peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
        } else {
            print("Characteristic does not support write operations.")
        }
    }

    func updateReceivedMessage(with data: Data) {
        // Attempt to decode the incoming data.
        if let newChunk = String(data: data, encoding: .utf8) {
            //print("New chunk: \(newChunk)")
            // Append the new chunk to the buffer.
            messageBuffer += newChunk
            //print("Buffer now: \(messageBuffer)")

            // Split the buffer by newline.
            let lines = messageBuffer.components(separatedBy: "\n")

            // Process all complete lines (all but the last element).
            for line in lines.dropLast() {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    DispatchQueue.main.async {
                        self.latestReceivedMessage = trimmed
                        print("Processed complete message: \(trimmed)")
                    }
                }
            }
            // Keep the remaining part (which might be an incomplete message).
            messageBuffer = lines.last ?? ""
        } else {
            print("Failed to decode received data")
        }
    }
    
    // --- New function to process received data ---
        /* func updateReceivedMessage(with data: Data) {
            // Decode the received data as a UTF-8 string.
            if let message = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.latestReceivedMessage = message
                    print("Received message: \(message)")
                }
            } else {
                print("Failed to decode received data")
            }
        }*/
    
    func send( message: String) {
            guard let peripheral = self.peripheral, let characteristic = self.characteristic else {
                print("Peripheral or characteristic is nil!")
                return
            }
            //print("Sending: \(message)")
            guard let data = message.data(using: .utf8) else {
                print("Failed to encode message to data.")
                return
            }
            if characteristic.properties.contains(.write) {
                peripheral.writeValue(data, for: characteristic, type: .withResponse)
            } else if characteristic.properties.contains(.writeWithoutResponse) {
                peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
            } else {
                print("Characteristic does not support write operations.")
            }
        }

        // New helper function to send a "Look<Letter>" command.
        func sendLetter(letter: String) {
            let command = "Look_\(letter)\n"
            //print("Actually sending \(command)")
            send(message: command)
        }
    
}

extension BluetoothManager {
    func hasCharacteristic() -> Bool {
        return characteristic != nil
    }
}
