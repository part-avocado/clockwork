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

struct ContentView: View {
    @StateObject private var spotifyManager = SpotifyManager()
    @StateObject private var updateManager = UpdateManager()
    @State private var currentTime = Date()
    @State private var isMouseHidden = false
    @State private var backgroundKey = UUID()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DynamicBackground()
                    .id(backgroundKey)
                
                VStack(spacing: 20) {
                    // Clock
                    Text(timeString)
                        .font(.system(size: 96, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Spotify Section
                    VStack(spacing: 10) {
                        if !spotifyManager.isAuthenticated {
                            ModernButton(title: "Connect to Spotify") {
                                spotifyManager.signIn()
                            }
                        } else {
                            HStack {
                                Spacer()
                                Button(action: {
                                    spotifyManager.signOut()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(PlainButtonStyle())
                                .padding(.trailing, 20)
                            }
                            
                            if let track = spotifyManager.currentTrack, spotifyManager.isPlaying {
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
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Update Button
                if updateManager.updateAvailable && updateManager.downloadComplete {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            UpdateButton {
                                updateManager.installUpdate()
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .onReceive(timer) { input in
            currentTime = input
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
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: currentTime)
    }
}

#Preview {
    ContentView()
}
