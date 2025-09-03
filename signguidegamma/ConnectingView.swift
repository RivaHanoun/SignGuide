//
//  ConnectingView.swift
//  signguide
//
//  Created by Riva on 10/19/24.
//

import SwiftUI

struct ConnectingView: View {
    //@StateObject private var bluetoothManager = BluetoothManager()
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    @State private var isNavigatingToCalibration = false
    
    var body: some View {
        //NavigationView {
            ZStack {
                //backgroud pic
                Image("backgroundmenu")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                VStack {
                    Text("Lets connect your glove!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    Text("Status: \(bluetoothManager.isConnected ? "Connected" : "Not Connected")")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                        .padding(.top, 50)
                    
                    Spacer()
                    
                    if bluetoothManager.isConnected {
                        
                        // Button only appears when connected
                        NavigationLink(
                            destination: Calibration()
                                .environmentObject(bluetoothManager),
                            isActive: $isNavigatingToCalibration
                        ) {
                            Button(action: {
                                bluetoothManager.sendStartCalibrationSignal()
                                isNavigatingToCalibration = true
                            }){
                                Text("Go to Calibration")
                                    .font(.title2)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .padding(100)
                                
                            }
                            .padding()
                        }
                    }
                }
            }
        }
    //}
}

struct Calibration: View {
    //@ObservedObject var bluetoothManager: BluetoothManager // Use passed instance of BluetoothManager
    @EnvironmentObject var bluetoothManager: BluetoothManager

    @State private var currentStep = 0  // Tracks the current calibration step
    @State private var collectedValues: [Int] = []  // Stores flex sensor values
    @State private var fullyFlexedRange: ClosedRange<Int>?
    @State private var halfFlexedRange: ClosedRange<Int>?
    @State private var unflexedRange: ClosedRange<Int>?
    @State private var showNextButton = false  // Controls the visibility of the button

    var body: some View {
        //NavigationView {
            ZStack {
                // Background image
                Image("backgroundmenu")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()


                VStack {
                    Text("Calibration Step: \(currentStep + 1) of 4")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                    
                    Spacer()
                    
                    Text(currentStepText())
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                    
                    
                    Image(currentStepImage())
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200, height: 200)
                        .padding()
                    
                    Spacer()
                    
                    if showNextButton {
                        Button(action: nextStep) {
                            if currentStep < 3{
                            Text("Next Step")
                                .font(.title2)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            else {
                                // Only show Calibration Complete after the last step is finished
                                NavigationLink(destination: ContentView()
                                                .environmentObject(bluetoothManager)) {
                                    Text("Calibration Complete")
                                        .font(.title2)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                                .padding(.top, 50)
                            }
                        }
                    }
                    Spacer()
                }
                .onAppear {
                            startCalibration()  // Start collecting values after the signal is sent
                    }
                //.navigationBarBackButtonHidden(true)
                .navigationBarHidden(true)
            }
        //}
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }

    private func currentStepText() -> String {
        switch currentStep {
        case 0:
            return "Give a thumbs up and hold for 5 seconds"
        case 1:
            return "Hold up four fingers for 5 second (making sure to bend your thumb)"
        case 2:
            return "Pretend to hold a ball for 5 seconds"
        case 3:
            return "Give a high-five for 5 seconds"
        default:
            return "Calibration complete! Returning to the main menu."
        }
    }

    private func currentStepImage() -> String {
        switch currentStep {
        case 0:
            return "thumb"  // Name of the fist image in your assets
        case 1:
            return "four"  // Name of the fist image in your assets
        case 2:
            return "throw"  // Name of the throwing image in your assets
        case 3:
            return "highfive"  // Name of the high-five image in your assets
        default:
            return "checkmark"  // Optional fallback image
        }
    }

    private func nextStep() {
        if currentStep < 3 {
            //calculateRange()
            collectedValues = []  // Clear collected values for the next step
            currentStep += 1
            showNextButton = false
            startCalibration()
        } else {
            //calculateRange()
            // Save the ranges or use them in the app
           /* bluetoothManager.setCalibrationRanges(
                fullyFlexed: fullyFlexedRange!,
                halfFlexed: halfFlexedRange!,
                unflexed: unflexedRange!
            )*/
            //currentStep += 1
            showNextButton = false
        }
        print("Current Step: \(currentStep + 1)")
    }

    private func startCalibration() {
        // Begin calibration only after the button press, not immediately
      //  isCalibrationStarted = true
        if currentStep == 0 {
            bluetoothManager.sendStartCalibrationSignal()
        }

        // Add a 2-second delay before starting the calibration
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            bluetoothManager.sendCalibrationStep(step: currentStep)
            // Start collecting the flex sensor values after the delay
            bluetoothManager.startCollectingValues { value in
                collectedValues.append(value)
            }

            // After collecting values for the step, show the "Next" button after the delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showNextButton = true
            }
        }
    }

}
    
struct ConnectingView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectingView()
    }
}

