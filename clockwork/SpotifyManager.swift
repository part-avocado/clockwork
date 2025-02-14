import Foundation
import SwiftUI
import Combine

class SpotifyManager: ObservableObject {
    static let clientId = "8744406d02204ba4801b793d06399194"
    static let clientSecret = "f11433c902de44399aab43ac38e35ceb"
    static let redirectUri = "clockwork://spotifyauth"
    
    @Published var isAuthenticated = false
    @Published var currentTrack: (title: String, artist: String)?
    @Published var isPlaying = false
    
    private var authToken: String?
    private var refreshToken: String?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupTimer()
        setupNotificationObserver()
        
        // Check if we have stored credentials
        if let token = UserDefaults.standard.string(forKey: "SpotifyAuthToken") {
            authToken = token
            refreshToken = UserDefaults.standard.string(forKey: "SpotifyRefreshToken")
            isAuthenticated = true
        }
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.publisher(for: NSNotification.Name("SpotifyCallback"))
            .compactMap { $0.object as? URL }
            .sink { [weak self] url in
                self?.handleCallback(url: url)
            }
            .store(in: &cancellables)
    }
    
    private func setupTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateNowPlaying()
        }
    }
    
    func signIn() {
        let scope = "user-read-playback-state"
        let authUrlString = "https://accounts.spotify.com/authorize" +
            "?client_id=\(SpotifyManager.clientId)" +
            "&response_type=code" +
            "&redirect_uri=\(SpotifyManager.redirectUri.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")" +
            "&scope=\(scope)" +
            "&show_dialog=true"
        
        if let url = URL(string: authUrlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    func handleCallback(url: URL) {
        guard let code = URLComponents(url: url, resolvingAgainstBaseURL: true)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value else { return }
        
        exchangeCodeForToken(code: code)
    }
    
    private func exchangeCodeForToken(code: String) {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let authString = "\(SpotifyManager.clientId):\(SpotifyManager.clientSecret)"
            .data(using: .utf8)?
            .base64EncodedString()
        
        request.setValue("Basic \(authString ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": SpotifyManager.redirectUri
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Error exchanging code for token: \(error)")
                return
            }
            
            guard let data = data else {
                print("No data received from token exchange")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let error = json["error"] as? String {
                        print("Spotify API error: \(error)")
                        return
                    }
                    
                    if let accessToken = json["access_token"] as? String {
                        DispatchQueue.main.async {
                            self?.authToken = accessToken
                            self?.refreshToken = json["refresh_token"] as? String
                            self?.isAuthenticated = true
                            
                            // Store credentials
                            UserDefaults.standard.set(accessToken, forKey: "SpotifyAuthToken")
                            if let refreshToken = json["refresh_token"] as? String {
                                UserDefaults.standard.set(refreshToken, forKey: "SpotifyRefreshToken")
                            }
                            
                            // Immediately fetch current playback state
                            self?.updateNowPlaying()
                        }
                    }
                }
            } catch {
                print("Error parsing token response: \(error)")
            }
        }
        
        task.resume()
    }
    
    private func refreshAccessToken() {
        guard let refreshToken = refreshToken,
              let url = URL(string: "https://accounts.spotify.com/api/token") else {
            isAuthenticated = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let authString = "\(SpotifyManager.clientId):\(SpotifyManager.clientSecret)"
            .data(using: .utf8)?
            .base64EncodedString()
        
        request.setValue("Basic \(authString ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = json["access_token"] as? String {
                DispatchQueue.main.async {
                    self?.authToken = accessToken
                    UserDefaults.standard.set(accessToken, forKey: "SpotifyAuthToken")
                    if let newRefreshToken = json["refresh_token"] as? String {
                        self?.refreshToken = newRefreshToken
                        UserDefaults.standard.set(newRefreshToken, forKey: "SpotifyRefreshToken")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self?.isAuthenticated = false
                    UserDefaults.standard.removeObject(forKey: "SpotifyAuthToken")
                    UserDefaults.standard.removeObject(forKey: "SpotifyRefreshToken")
                }
            }
        }.resume()
    }
    
    private func updateNowPlaying() {
        guard isAuthenticated, let authToken = authToken,
              let url = URL(string: "https://api.spotify.com/v1/me/player/currently-playing") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 204:
                        // No content - no active playback
                        self.currentTrack = nil
                        self.isPlaying = false
                    case 401:
                        // Unauthorized - token expired
                        self.refreshAccessToken()
                    case 200:
                        // Success - parse the response
                        guard let data = data,
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                            return
                        }
                        
                        if let item = json["item"] as? [String: Any],
                           let name = item["name"] as? String,
                           let artists = item["artists"] as? [[String: Any]],
                           let artistName = artists.first?["name"] as? String {
                            self.currentTrack = (title: name, artist: artistName)
                            self.isPlaying = json["is_playing"] as? Bool ?? false
                        }
                    default:
                        print("Unexpected status code: \(httpResponse.statusCode)")
                    }
                }
            }
        }.resume()
    }
    
    func signOut() {
        isAuthenticated = false
        authToken = nil
        refreshToken = nil
        currentTrack = nil
        isPlaying = false
        UserDefaults.standard.removeObject(forKey: "SpotifyAuthToken")
        UserDefaults.standard.removeObject(forKey: "SpotifyRefreshToken")
    }
    
    deinit {
        timer?.invalidate()
    }
}
