//
//  birdyApp.swift
//  birdy
//
//  Created by Chenge Zhang on 9/29/25.
//

import SwiftUI
import RevenueCat

@main
struct birdyApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var audioManager = AudioManager(filename: "background", fileExtension: "m4a", autoplay: false, loop: true, fadeInDuration: 2.0, fadeOutDuration: 2.0)

    init() {
        // Configure RevenueCat with your public API key. Replace the placeholder below
        // with your RevenueCat public API key (not a secret key).
        Purchases.configure(withAPIKey: "appl_USUvmLvlMTJwZgOzFfYhxpykLmv")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Start playback when the app is opened (foreground)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        audioManager.play()
                    }
                }
                .onChange(of: scenePhase) { newPhase in
                    switch newPhase {
                    case .active:
                        // Resume playback when app becomes active
                        audioManager.play()
                    case .background:
                        // Pause playback when the app goes to background (user requested music only while app is open)
                        audioManager.pause()
                    default:
                        break
                    }
                }
        }
    }
}
