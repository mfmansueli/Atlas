//
//  WelcomeStage.swift
//  Atlas
//

import Foundation

/// Where the first run is before a key is saved: Welcome, then Connect
/// (Get Started). Reading your apps comes once the key is saved, from the
/// main window.
enum WelcomeStage: Hashable, Sendable {
    case welcome
    case connect

    /// Welcome first, unless there's something to say about the saved
    /// keys (they couldn't be read), which only Connect shows.
    static func initial(hasNotice: Bool) -> WelcomeStage {
        hasNotice ? .connect : .welcome
    }
}
