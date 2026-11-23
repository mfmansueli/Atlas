//
//  EncryptionKeyProjectState.swift
//  Atlas
//

import Foundation

/// What Atlas read of the export compliance key in the app's project
/// folder itself, without an assistant: the app target building the app's
/// bundle ID, its Release build settings
/// (`INFOPLIST_KEY_ITSAppUsesNonExemptEncryption`) and its Info.plist.
/// Settings kept in .xcconfig files aren't read, so not finding it isn't
/// proof it's missing.
enum EncryptionKeyProjectState: Hashable, Sendable {
    /// Where the key is set, and what it says.
    struct Key: Hashable, Sendable {
        var value: EncryptionKeyValue
        var code: String?
        var target: String
        /// The build setting's name, or the Info.plist's path.
        var location: String
        var isBuildSetting: Bool

        /// "Lumen's build settings", "Lumen/Info.plist (Lumen)".
        var whereText: String {
            isBuildSetting ? String(localized: "\(target)’s build settings") : String(localized: "\(location) (\(target))")
        }
    }

    /// Not read yet.
    case unknown
    /// No project folder in Settings → AI Assistants.
    case noFolder
    /// No Xcode project or app target for the bundle ID, or no access.
    case unreadable(reason: String)
    case found(Key)
    /// The app targets read have no key in their Release settings or
    /// Info.plist.
    case notFound(targets: [String])

    var key: Key? {
        if case let .found(key) = self { return key }
        return nil
    }
}
