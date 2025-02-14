import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    @Published var showSeconds: Bool {
        didSet {
            UserDefaults.standard.set(showSeconds, forKey: "showSeconds")
            objectWillChange.send()
        }
    }
    
    @Published var use24HourTime: Bool {
        didSet {
            UserDefaults.standard.set(use24HourTime, forKey: "use24HourTime")
            objectWillChange.send()
        }
    }
    
    init() {
        // Load saved settings or use defaults
        self.showSeconds = UserDefaults.standard.object(forKey: "showSeconds") as? Bool ?? true
        self.use24HourTime = UserDefaults.standard.object(forKey: "use24HourTime") as? Bool ?? true
    }
}

extension UserDefaults {
    func bool(forKey key: String, defaultValue: Bool) -> Bool {
        if let _ = object(forKey: key) {
            return bool(forKey: key)
        }
        return defaultValue
    }
} 