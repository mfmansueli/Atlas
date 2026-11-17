//
//  PageTextState.swift
//  Atlas
//

import Foundation

/// How a territory's App Store page text came to be.
enum PageTextState: String, Hashable, Sendable, Codable {
    /// The app has no page in the territory's language; it shows the
    /// primary language's.
    case noPage
    /// Mostly machine-translated and not reviewed.
    case machineTranslated
    case written

    var title: String {
        switch self {
        case .noPage: String(localized: "No page in this language")
        case .machineTranslated: String(localized: "Machine-translated")
        case .written: String(localized: "Written or reviewed")
        }
    }
}
