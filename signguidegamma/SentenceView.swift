//
//  SentenceView.swift
//  signguide
//
//  Created by Riva on 10/19/24.
//
import SwiftUI

struct SentenceView: View {
    var body: some View {
        NavigationView {
            ZStack {
                //backgroud pic
                Image("backgroundmenu")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                VStack {
                    Text("Coming Soon ...")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                }
                Spacer()
            }
        }
    }
}

struct SentenceView_Previews: PreviewProvider {
    static var previews: some View {
        SentenceView()
    }
}
