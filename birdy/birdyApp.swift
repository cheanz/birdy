//
//  birdyApp.swift
//  birdy
//
//  Created by Chenge Zhang on 9/29/25.
//

import SwiftUI

@main
struct birdyApp: App {
    @StateObject private var audioManager = AudioManager(filename: "background", fileExtension: "m4a", autoplay: false)

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(audioManager)
        }
    }
}
