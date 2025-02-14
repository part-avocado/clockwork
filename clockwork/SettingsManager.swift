import Foundation
import SwiftUI

class SettingsManager: ObservableObject {
    @Published var showSeconds: Bool {
        didSet {
            UserDefaults.standard.set(showSeconds, forKey: "showSeconds")
        }
    }
    
    @Published var use24HourTime: Bool {
        didSet {
            UserDefaults.standard.set(use24HourTime, forKey: "use24HourTime")
        }
    }
    
    init() {
        self.showSeconds = UserDefaults.standard.bool(forKey: "showSeconds", defaultValue: true)
        self.use24HourTime = UserDefaults.standard.bool(forKey: "use24HourTime", defaultValue: true)
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