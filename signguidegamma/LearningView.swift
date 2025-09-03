//
//  learning.swift
//  signguide
//
//  Created by Riva on 10/18/24.
//

import SwiftUI

// Sample data structure
struct Leason {
    let name: String
    let image: String
}
// MARK: - LEASON GRID
struct LearningView: View {
    //@StateObject private var bluetoothManager = BluetoothManager()
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    let leasons = [
        Leason(name: "A", image: "A"),
        Leason(name: "B", image: "B"),
        Leason(name: "C", image: "C"),
        Leason(name: "D", image: "D"),
        Leason(name: "E", image: "E"),
        Leason(name: "F", image: "F"),
        Leason(name: "G", image: "G2"),
        Leason(name: "H", image: "H"),
        Leason(name: "I", image: "I"),
        Leason(name: "J", image: "J"),
        Leason(name: "K", image: "K"),
        Leason(name: "L", image: "L"),
        Leason(name: "M", image: "M"),
        Leason(name: "N", image: "N"),
        Leason(name: "O", image: "O"),
        Leason(name: "P", image: "P"),
        Leason(name: "Q", image: "Q"),
        Leason(name: "R", image: "R"),
        Leason(name: "S", image: "S"),
        Leason(name: "T", image: "T"),
        Leason(name: "U", image: "U"),
        Leason(name: "V", image: "V"),
        Leason(name: "W", image: "W"),
        Leason(name: "X", image: "X"),
        Leason(name: "Y", image: "Y"),
        Leason(name: "Z", image: "Z")
    ]
    @State private var currentIndex = 0
    
    
    var body: some View {
        NavigationView {
            ZStack {
                //backgroud pic
                Image("backgroundmenu")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                VStack {
                    Text("Lets Start Learning!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    Spacer()
                    
                    ScrollView {
                        // Grid Layout
                        let columns = [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ]
                        
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(leasons, id: \.name) { item in
                                NavigationLink(destination: DetailView(item: item)
                                    .environmentObject(bluetoothManager)) {
                                    VStack {
                                        Image(item.image) // Ensure you have images named "image1", "image2", etc.
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 140, height: 100) // Adjust size as needed
                                            .cornerRadius(10)
                                        
                                        Text(item.name)
                                            .font(.headline)
                                            .foregroundColor(.black)
                                    }
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(10)
                                    .shadow(radius: 5)
                                }
                                
                            }
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
        }
    }
}

// MARK: - STEPS & BREAK SCREEN
struct DetailView: View {
    let item: Leason
    @State private var lessonStage: Int = 1     // 1 = full (image + text), 2 = text only, 3 = no instructions.
    @State private var commandSent = false
    @State private var goodJobVisible = false
    @State private var showBreakScreen = false
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    // Compute the next lesson (if available) by advancing the letter.
    var nextLesson: Leason? {
        guard let ascii = item.name.unicodeScalars.first?.value, ascii < 90 else { return nil }
        let nextLetter = String(UnicodeScalar(ascii + 1)!)
        return Leason(name: nextLetter, image: nextLetter)
    }
    
    var body: some View {
        ZStack {
            Image("backgroundmenu")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            if showBreakScreen{
                VStack(spacing: 20){
                    Text("You're doing GREAT!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Please relax your hand!")
                        .font(.title2)
                }
                .padding()
            }
            else{
                
                VStack(spacing: 20) {
                    Text("Lesson \(item.name)")
                        .font(.largeTitle)
                        .padding(.top)
                    
                    // Show image only in stage 1
                    if lessonStage == 1 {
                        Image(item.image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .padding()
                    }
                    
                    // Show instructions based on the stage.
                    if lessonStage == 1 {
                        // Stage 1: Full instructions (image already shown above)
                        instructionView(for: item.name)
                    } else if lessonStage == 2 {
                        // Stage 2: Only text instructions.
                        instructionView(for: item.name)
                    } else if lessonStage == 3 {
                        // Stage 3: No instructions.
                        EmptyView()
                    }
                    Spacer()
                    
                    // Good Job button area
                    if goodJobVisible {
                        if lessonStage < 3 {
                            Button(action: {
                                // Advance to next stage and resend the command.
                                goodJobVisible = false
                                showBreakScreen = true
                                commandSent = false
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3){
                                    showBreakScreen = false
                                    lessonStage += 1
                                }
                                Task { await sendCommandIfConnected() }
                            }) {
                                Text("Good job, let’s do it again")
                                    .font(.title2)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        } else {
                            // Stage 3: Show a Continue button.
                            Text("Good job!")
                                .font(.title2)
                            if let next = nextLesson{
                                NavigationLink(destination: DetailView(item: next)
                                    .environmentObject(bluetoothManager)) {
                                        Text("Continue to the next letter!")
                                            .font(.title2)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color.green)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .padding(.horizontal)
                            } else {
                                NavigationLink(destination: LearningView()
                                    .environmentObject(bluetoothManager)){
                                        // No next lesson, perhaps show a completion message.
                                        Text("All lessons completed!")
                                            .font(.title2)
                                    }
                            }
                        }
                    }
                    
                    Spacer()
                }
                //.navigationBarHidden(true)
                //.navigationBarBackButtonHidden(true)
            }
            }
            //.navigationBarHidden(true)
            //.navigationBarBackButtonHidden(true)
            // Force a new instance when either the lesson or stage changes so that state resets if needed.
                .id("\(item.name)_\(lessonStage)")
            //.navigationBarBackButtonHidden(true)// back button for lessons
                .task {
                    // Reset state when the view first appears.
                    lessonStage = 1
                    goodJobVisible = false
                    commandSent = false
                    showBreakScreen = false
                    await sendCommandIfConnected()
                }
                .onChange(of: bluetoothManager.latestReceivedMessage) { newMessage in
                    let trimmed = newMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    print("onChange got: \(trimmed)")
                    // Check for the corresponding OK response (e.g., OK_A, OK_B, etc.)
                    if trimmed == "OK_\(item.name)" {
                        goodJobVisible = true
                        bluetoothManager.latestReceivedMessage = nil
                    }
                }
        }
        
    // MARK: - LETTERS
        // A helper view that returns instructions based on the lesson letter.
        @ViewBuilder
        func instructionView(for letter: String) -> some View {
            if letter == "A" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Make a closed fist")
                    Text("• Fold all fingers against the palm (make sure to press firmly)")
                    Text("• Keep the thumb straight and alongside the index finger")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "B" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• All fingers are straight")
                    Text("• Thumb is folded across palm")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "C" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Curve all your fingers slightly, including your thumb")
                    Text("• Turn your hand slightly left so your thumb and index finger form a backward C shape")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "D" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Keep your index finger straight and pointing up")
                    Text("• Touch the tip of your thumb to the tip of your middle finger (make sure to press firmly)")
                    Text("• Bend your ring and pinky fingers")
                    Text("• Turn your hand slightly so the shape looks like a lowercase d")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "E" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your thumb across your palm")
                    Text("• Curl all four fingers inward so the tips of the index, middle, and ring fingers rest on the thumb")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }  else if letter == "F" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Touch the tip of your index finger to the tip of your thumb, forming a circle")
                    Text("• Keep the middle, ring, and pinky fingers straight and slightly spread")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }  else if letter == "G" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your middle, ring, and pinky fingers into your palm")
                    Text("• Keep your index finger and thumb straight and parallel with each other but dont touch them together, with the back of the index finger facing forward")
                    Text("• Turn your hand to the left")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "H" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your ring and pinky fingers into your palm")
                    Text("• Place your thumb over them")
                    Text("• Keep your index and middle fingers straight and together, pointing to the left")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "I" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Curl your index, middle, and ring fingers into your palm")
                    Text("• Fold your thumb across them")
                    Text("• Keep your pinky finger straight up")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "J" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Start with the I handshape (pinky up, other fingers curled)")
                    Text("• Move your pinky in a J shape, curving forward and then right as your hand turns")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "K" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your ring and pinky fingers into your palm")
                    Text("• Extend your index and middle fingers in a V shape")
                    Text("• Place your thumb inbetween them, touching the base of the middle finger")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "L" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your middle, ring, and pinky fingers into your palm")
                    Text("• Extend your index finger straight up")
                    Text("• Stick your thumb out sideways at a 90-degree angle, forming an L shape")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "M" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your pinky down (make sure to press firmly)")
                    Text("• Bring your thumb across your palm to touch your pinky")
                    Text("• Fold your index, middle, and ring fingers over your thumb")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "N" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your ring and pinky fingers into your palm (make sure to press firmly)")
                    Text("• Bring your thumb across to rest on top of them")
                    Text("• Fold your index and middle fingers over your thumb")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "O" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Curve all fingers slightly")
                    Text("• Touch the tip of your index finger to the tip of your thumb, forming an O shape")
                    Text("• Turn your hand slightly so the O is visible")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "P" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• (Similar to K) Fold your ring and pinky fingers into your palm")
                    Text("• Extend your index and middle fingers in a V shape")
                    Text("• Place your thumb inbetween them, touching the base of the middle finger")
                    Text("• Tilt you hand so that the index finger is horizontal")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "Q" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• (Similar to G) Fold your ring, pinky and middle fingers into your palm")
                    Text("• Keep your index finger and thumb straight but don't touch them together")
                    Text("• Tilt your hand down so your index and thumb are pointing straight down")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "R" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your ring and pinky fingers into your palm")
                    Text("• Cross your index and middle fingers, with the index in front")
                    Text("• Hold them down slightly with your thumb")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "S" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Make a tight fist (make sure to press firmly)")
                    Text("• Tuck your thumb across the front of your index and middle fingers")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "T" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your middle, ring, and pinky fingers into your palm (make sure to press firmly)")
                    Text("• Tuck your thumb over your middle finger")
                    Text("• Fold your index finger over your thumb")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "U" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your ring and pinky fingers into your palm, holding them down with your thumb")
                    Text("• Keep your index and middle fingers straight and together")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "V" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Similar to U, Fold your ring and pinky fingers into your palm, holding them down with your thumb")
                    Text("• Spread your index and middle fingers apart to form a V shape")
                    
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "W" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Keep your index, middle, and ring fingers straight and slightly spread")
                    Text("• Touch the tip of your pinky finger to the tip of your thumb")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "X" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your middle, ring, and pinky fingers into your palm")
                    Text("• Bend your index finger at both joints to form a hook shape")
                    Text("• Keep your thumb pulled in slightly")
                    Text("• Turn your hand left so the index and thumb are visible")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "Y" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your index, middle, and ring fingers into your palm")
                    Text("• Extend your pinky and thumb out, spreading them wide")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            } else if letter == "Z" {
                VStack(alignment: .center, spacing: 10) {
                    Text("• Fold your middle, ring, and pinky fingers into your palm")
                    Text("• Tuck your thumb over your middle and ring fingers")
                    Text("• Keep your index finger straight")
                    Text("• Move your hand to draw a Z shape in the air")
                }
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
            else {
                Text("Instructions for lesson \(letter)")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        
        // Async function that waits until Bluetooth is connected, then sends the command.
        func sendCommandIfConnected() async {
            while !bluetoothManager.isConnected || !bluetoothManager.hasCharacteristic() {
                print("Not connected/ready, waiting...")
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            }
            bluetoothManager.sendLetter(letter: item.name)
            commandSent = true
            print("Sent Look_\(item.name) to Arduino")
        }
    }

struct LearningView_Previews: PreviewProvider {
    static var previews: some View {
        LearningView()
    }
}

struct DetailView_Previews: PreviewProvider {
    static var previews: some View {
        DetailView(item: Leason(name: "Item 1", image: "image1"))
        
    }
}

