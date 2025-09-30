//
//  ContentView.swift
//  birdy
//
//  Created by Chenge Zhang on 9/29/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }

                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                ProfileView()
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
            }

            MusicPlayerView(audio: audioManager)
                .padding(.bottom, 48)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AudioManager(filename: "background", autoplay: false))
}
