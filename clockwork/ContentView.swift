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

struct ContentView: View {
    @StateObject private var spotifyManager = SpotifyManager()
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
                    VStack {
                        if !spotifyManager.isAuthenticated {
                            ModernButton(title: "Connect to Spotify") {
                                spotifyManager.signIn()
                            }
                        } else if let track = spotifyManager.currentTrack, spotifyManager.isPlaying {
                            Text("\(track.title)")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                            Text("by \(track.artist)")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            Text("Play some music on Spotify for it to show up here")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onReceive(timer) { input in
            currentTime = input
        }
        .onAppear {
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
