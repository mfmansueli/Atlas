//
//  ReleaseActionError.swift
//  Atlas
//

import Foundation

/// Why a version card action couldn't even be sent.
enum ReleaseActionError: LocalizedError {
    /// What the button acts on is gone: the status is out of date.
    case nothingToAct

    var errorDescription: String? {
        switch self {
        case .nothingToAct: String(localized: "This changed in App Store Connect. Refresh (⌘R) and try again.")
        }
    }
}
