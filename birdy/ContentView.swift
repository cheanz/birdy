//
//  ContentView.swift
//  birdy
//
//  Created by Chenge Zhang on 9/29/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var routesStore = RoutesStore()

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }

            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }

            SavedRoutesView()
                .tabItem { Label("Routes", systemImage: "map") }
                .environmentObject(routesStore)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .environmentObject(routesStore)
    }
}

#Preview {
    ContentView()
}
