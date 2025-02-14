//
//  clockworkApp.swift
//  clockwork
//
//  Created by James on 2/13/25.
//

import SwiftUI
import AppKit

@main
struct clockworkApp: App {
    @StateObject private var spotifyManager = SpotifyManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
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

class AppDelegate: NSObject, NSApplicationDelegate {
    @objc func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: urlString) else {
            return
        }
        
        if url.scheme == "clockwork" {
            NotificationCenter.default.post(name: NSNotification.Name("SpotifyCallback"), object: url)
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
}
