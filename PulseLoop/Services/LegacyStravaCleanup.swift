import Foundation
import Security

/// Strava was removed from Kinnora. Older builds stored its OAuth tokens in the Keychain (which
/// survives app updates and deletes) and upload preferences in UserDefaults; this clears both.
/// Cheap and idempotent, so it runs at every launch and on "reset app data".
enum LegacyStravaCleanup {
    nonisolated static func run() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.pulseloop.strava",
        ]
        SecItemDelete(query as CFDictionary)
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.lowercased().contains("strava") {
            defaults.removeObject(forKey: key)
        }
    }
}
