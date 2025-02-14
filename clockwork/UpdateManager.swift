import Foundation
import SwiftUI

class UpdateManager: ObservableObject {
    @Published var updateAvailable = false
    @Published var downloadComplete = false
    private let repoOwner = "part-avocado"
    private let repoName = "clockwork"
    private var downloadedAppPath: String?
    
    func checkForUpdates() {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let release = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = release["tag_name"] as? String,
                  let assets = release["assets"] as? [[String: Any]],
                  let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                return
            }
            
            // Compare versions
            if self?.isNewerVersion(current: currentVersion, new: tagName) == true {
                if let asset = assets.first(where: { ($0["name"] as? String)?.hasSuffix(".app.zip") == true }),
                   let downloadUrl = asset["browser_download_url"] as? String {
                    self?.downloadUpdate(from: downloadUrl)
                }
            }
        }.resume()
    }
    
    private func isNewerVersion(current: String, new: String) -> Bool {
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let newComponents = new.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<min(currentComponents.count, newComponents.count) {
            if newComponents[i] > currentComponents[i] {
                return true
            } else if newComponents[i] < currentComponents[i] {
                return false
            }
        }
        return newComponents.count > currentComponents.count
    }
    
    private func downloadUpdate(from urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        let downloadTask = URLSession.shared.downloadTask(with: url) { [weak self] localUrl, response, error in
            guard let localUrl = localUrl else { return }
            
            let fileManager = FileManager.default
            let tempDirectory = fileManager.temporaryDirectory
            let appDirectory = tempDirectory.appendingPathComponent("ClockworkUpdate")
            
            try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
            let zipPath = appDirectory.appendingPathComponent("update.zip")
            
            try? fileManager.moveItem(at: localUrl, to: zipPath)
            
            // Unzip the downloaded file
            let process = Process()
            process.launchPath = "/usr/bin/unzip"
            process.arguments = ["-o", zipPath.path, "-d", appDirectory.path]
            try? process.run()
            process.waitUntilExit()
            
            // Find the .app file
            if let appFile = try? fileManager.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "app" }) {
                self?.downloadedAppPath = appFile.path
                DispatchQueue.main.async {
                    self?.downloadComplete = true
                    self?.updateAvailable = true
                }
            }
        }
        
        downloadTask.resume()
    }
    
    func installUpdate() {
        guard let downloadedAppPath = downloadedAppPath else { return }
        
        let currentAppPath = Bundle.main.bundlePath
        let fileManager = FileManager.default
        let parentDirectory = (currentAppPath as NSString).deletingLastPathComponent
        
        // Create an AppleScript to handle the update after the app quits
        let script = """
        do shell script "sleep 2; rm -rf '\(currentAppPath)'; cp -R '\(downloadedAppPath)' '\(parentDirectory)'; open '\(currentAppPath)'"
        """
        
        var error: NSDictionary?
        let appleScript = NSAppleScript(source: script)
        appleScript?.executeAndReturnError(&error)
        
        // Quit the app
        NSApplication.shared.terminate(nil)
    }
} 