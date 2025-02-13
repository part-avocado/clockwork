//
//  clockworkApp.swift
//  clockwork
//
//  Created by James on 2/13/25.
//

import SwiftUI

@main
struct clockworkApp: App {
    @StateObject private var spotifyManager = SpotifyManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(spotifyManager)
                .onOpenURL { url in
                    if url.scheme == "clockwork" {
                        spotifyManager.handleCallback(url: url)
                    }
                }
                .onAppear {
                    if let window = NSApplication.shared.windows.first {
                        window.toggleFullScreen(nil)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
