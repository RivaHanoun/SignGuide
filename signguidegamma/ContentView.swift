//
//  ContentView.swift
//  signguide
//
//  Created by Riva on 10/18/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    var body: some View{
        NavigationView {
            ZStack {
                //backgroud pic
                Image("backgroundmenu")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                
                //buttons
                VStack{
                    
                    //title
                    Text("SIGN GUIDE")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .padding(.top,50)
                    
                    Spacer()
                    
                    Text("Choose an Option")
                        .font(.body)
                        .foregroundColor(.black)
                        .padding(.bottom)
                    
                    NavigationLink(destination: ConnectingView()
                                    .environmentObject(bluetoothManager)){
                        Text("Connect your Sign Guide")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 250)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 10)
                    
                    NavigationLink(destination: LearningView()
                                        .environmentObject(bluetoothManager)){
                        Text("Start Learning")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 250)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 10)
                    NavigationLink(destination: SentenceView()
                                   .environmentObject(bluetoothManager)){
                        Text("Make Your Own Sentence")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .frame(width: 250)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    
                    Spacer()
                }
                .padding()
                .navigationBarHidden(true)
                .navigationBarBackButtonHidden(true)
            }
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
        }
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
    }
}
