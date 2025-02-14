//
//  ContentView.swift
//  clockwork
//
//  Created by James on 2/13/25.
//

import SwiftUI

struct ModernButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "music.note")
                Text(title)
            }
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct UpdateButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                Text("Restart to update")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.blue.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
    }
}

// Settings button and menu
struct SettingsButton: View {
    @Binding var showSettings: Bool
    
    var body: some View {
        Button(action: {
            showSettings.toggle()
        }) {
            Image(systemName: "gear")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.6))
        }
        .buttonStyle(PlainButtonStyle())
        .padding()
    }
}

struct SettingsMenu: View {
    @ObservedObject var spotifyManager: SpotifyManager
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $settingsManager.showSeconds) {
                Label("Show seconds", systemImage: "clock")
            }
            
            Toggle(isOn: $settingsManager.use24HourTime) {
                Label("24-hour time", systemImage: "clock.fill")
            }
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            Button(action: {
                spotifyManager.signOut()
            }) {
                Label("Sign out of Spotify", systemImage: "music.note")
            }
        }
        .padding()
        .frame(width: 200)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
        .foregroundColor(.white)
        .font(.system(size: 14))
    }
}

struct ContentView: View {
    @StateObject private var spotifyManager = SpotifyManager()
    @StateObject private var updateManager = UpdateManager()
    @StateObject private var settingsManager = SettingsManager()
    @State private var currentTime = Date()
    @State private var isMouseHidden = false
    @State private var backgroundKey = UUID()
    @State private var mouseLocation: CGPoint = .zero
    @State private var showSettings = false
    
    private let timer = Timer.publish(every: 0.5, on: RunLoop.main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DynamicBackground()
                    .id(backgroundKey)
                
                VStack(spacing: 20) {
                    // Clock
                    TimeDisplayView(showSeconds: settingsManager.showSeconds,
                                  use24HourTime: settingsManager.use24HourTime)
                        .font(.system(size: 96, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Spotify Section
                    VStack(spacing: 10) {
                        if !spotifyManager.isAuthenticated {
                            ModernButton(title: "Connect to Spotify") {
                                spotifyManager.signIn()
                            }
                        } else if let track = spotifyManager.currentTrack, spotifyManager.isPlaying {
                            Text(track.title)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            Text("by \(track.artist)")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Play some music on Spotify for it to show up here")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Settings Button and Menu
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        ZStack(alignment: .topTrailing) {
                            if showSettings {
                                SettingsMenu(spotifyManager: spotifyManager,
                                           settingsManager: settingsManager)
                                    .offset(y: -120) // Move menu up above the gear icon
                            }
                            SettingsButton(showSettings: $showSettings)
                        }
                        .opacity(isMouseInBottomRight(geometry: geometry) || showSettings ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isMouseInBottomRight(geometry: geometry))
                    }
                }
                
                // Update Button and Error Message
                if updateManager.updateAvailable && updateManager.downloadComplete {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack {
                                if let errorMessage = updateManager.errorMessage {
                                    Text(errorMessage)
                                        .font(.system(size: 14))
                                        .foregroundColor(.red.opacity(0.8))
                                        .padding(.horizontal)
                                } else {
                                    UpdateButton {
                                        updateManager.installUpdate()
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            currentTime = Date()
        }
        .onAppear {
            updateManager.checkForUpdates()
            
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.modifierFlags.contains(.command) && event.keyCode == 15 { // CMD+R
                    backgroundKey = UUID()
                    return nil
                } else if event.keyCode == 46 { // M key
                    isMouseHidden.toggle()
                    NSCursor.setHiddenUntilMouseMoves(isMouseHidden)
                    return nil
                }
                return event
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                mouseLocation = location
            case .ended:
                mouseLocation = .zero
            }
        }
    }
    
    private func isMouseInBottomRight(geometry: GeometryProxy) -> Bool {
        let threshold: CGFloat = 100
        let isInBottomRight = mouseLocation.x > geometry.size.width - threshold &&
                            mouseLocation.y > geometry.size.height - threshold
        return isInBottomRight
    }
}

// Update TimeDisplayView to support formatting options
struct TimeDisplayView: View {
    @State private var currentTime = Date()
    var showSeconds: Bool
    var use24HourTime: Bool
    
    private let timer = Timer.publish(every: 0.5, on: RunLoop.main, in: .common).autoconnect()
    
    var body: some View {
        Text(timeString)
            .onReceive(timer) { _ in
                currentTime = Date()
            }
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = use24HourTime ? 
            (showSeconds ? "HH:mm:ss" : "HH:mm") :
            (showSeconds ? "h:mm:ss a" : "h:mm a")
        return formatter.string(from: currentTime)
    }
}

#Preview {
    ContentView()
}
