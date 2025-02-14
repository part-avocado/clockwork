import Foundation
import SwiftUI

class UpdateManager: ObservableObject {
    @Published var updateAvailable = false
    @Published var downloadComplete = false
    @Published var errorMessage: String?
    
    private let repoOwner = "part-avocado"
    private let repoName = "clockwork"
    private var downloadedAppPath: String?
    private var currentVersion: String
    private var checkTimer: Timer?
    
    init() {
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        setupPeriodicCheck()
    }
    
    private func setupPeriodicCheck() {
        // Check for updates every 6 hours
        checkTimer = Timer.scheduledTimer(withTimeInterval: 6 * 60 * 60, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
    }
    
    func checkForUpdates() {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Failed to check for updates: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data,
                      let release = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = release["tag_name"] as? String,
                      let assets = release["assets"] as? [[String: Any]] else {
                    self.errorMessage = "Failed to parse update information"
                    return
                }
                
                // Remove 'v' prefix if present
                let remoteVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
                
                if self.isNewerVersion(current: self.currentVersion, new: remoteVersion) {
                    if let asset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".app.zip") == true }),
                       let downloadUrl = asset["browser_download_url"] as? String {
                        self.downloadUpdate(from: downloadUrl)
                        self.updateAvailable = true
                    }
                } else {
                    self.updateAvailable = false
                    self.downloadComplete = false
                }
            }
        }.resume()
    }
    
    private func isNewerVersion(current: String, new: String) -> Bool {
        let currentComponents = current.split(separator: "-")[0].split(separator: ".").compactMap { Int($0) }
        let newComponents = new.split(separator: "-")[0].split(separator: ".").compactMap { Int($0) }
        
        // Ensure we have valid version numbers
        guard !currentComponents.isEmpty, !newComponents.isEmpty else {
            return false
        }
        
        // Compare version numbers
        for i in 0..<min(currentComponents.count, newComponents.count) {
            if newComponents[i] > currentComponents[i] {
                return true
            } else if newComponents[i] < currentComponents[i] {
                return false
            }
        }
        
        // If all components are equal, the longer version is newer
        return newComponents.count > currentComponents.count
    }
    
    private func downloadUpdate(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] localUrl, response, error in
            guard let self = self,
                  let localUrl = localUrl,
                  error == nil else {
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to download update: \(error?.localizedDescription ?? "Unknown error")"
                }
                return
            }
            
            let fileManager = FileManager.default
            let tempDirectory = fileManager.temporaryDirectory
            let appDirectory = tempDirectory.appendingPathComponent("ClockworkUpdate")
            
            do {
                // Clean up any existing update files
                if fileManager.fileExists(atPath: appDirectory.path) {
                    try fileManager.removeItem(at: appDirectory)
                }
                
                try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
                let zipPath = appDirectory.appendingPathComponent("update.zip")
                
                try fileManager.moveItem(at: localUrl, to: zipPath)
                
                // Unzip the downloaded file
                let process = Process()
                process.launchPath = "/usr/bin/unzip"
                process.arguments = ["-o", zipPath.path, "-d", appDirectory.path]
                try process.run()
                process.waitUntilExit()
                
                // Find the .app file
                if let appFile = try fileManager.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                    .first(where: { $0.pathExtension == "app" }) {
                    self.downloadedAppPath = appFile.path
                    DispatchQueue.main.async {
                        self.downloadComplete = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to prepare update: \(error.localizedDescription)"
                }
            }
        }
        
        downloadTask.resume()
    }
    
    func installUpdate() {
        guard let downloadedAppPath = downloadedAppPath else { return }
        
        let currentAppPath = Bundle.main.bundlePath
        let parentDirectory = (currentAppPath as NSString).deletingLastPathComponent
        
        // Create an AppleScript to handle the update after the app quits
        let script = """
        do shell script "sleep 2; rm -rf '\(currentAppPath)'; cp -R '\(downloadedAppPath)' '\(parentDirectory)'; open '\(currentAppPath)'"
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
            
            if error == nil {
                NSApplication.shared.terminate(nil)
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to install update: \(error?.description ?? "Unknown error")"
                }
            }
        }
    }
    
    deinit {
        checkTimer?.invalidate()
    }
}
