import Foundation

/// Stores the signed-in guest's user identifier so the app can tell
/// which courses the current user owns. The identifier is not a secret;
/// the bearer token stays in the Keychain.
enum CurrentUserID {
    private static let defaultsKey = "coco.currentUserID"

    static var value: UUID? {
        get {
            UserDefaults.standard.string(forKey: defaultsKey).flatMap(UUID.init)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }
    }
}

/// The current guest's display name, cached for profile UI.
enum CurrentUserName {
    private static let defaultsKey = "coco.currentUserName"

    static var value: String? {
        get {
            UserDefaults.standard.string(forKey: defaultsKey)
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: defaultsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            }
        }
    }
}
