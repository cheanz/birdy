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
        // Configure RevenueCat if API key is present in Info.plist under REVENUECAT_API_KEY
        if let key = Bundle.main.object(forInfoDictionaryKey: "REVENUECAT_API_KEY") as? String, !key.isEmpty {
            Purchases.configure(withAPIKey: key)
        } else {
            // If you don't want to configure in some builds, leave the key out and this will be a no-op
            print("REVENUECAT_API_KEY missing in Info.plist — RevenueCat not configured")
        }
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
