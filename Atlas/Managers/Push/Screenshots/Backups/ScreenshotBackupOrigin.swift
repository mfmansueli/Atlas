//
//  ScreenshotBackupOrigin.swift
//  Atlas
//

import Foundation

/// How a kept screenshot had been made, for the restore sheet's "5 + 5
/// screenshots · added by hand".
enum ScreenshotBackupOrigin: String, Codable, Hashable, Sendable {
    /// Atlas had pushed it from the template.
    case template
    /// Someone uploaded it in App Store Connect.
    case uploadedByHand

    var title: String {
        switch self {
        case .template: String(localized: "from the template")
        case .uploadedByHand: String(localized: "added by hand")
        }
    }
}
