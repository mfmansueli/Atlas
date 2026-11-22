//
//  AutopilotStripAction.swift
//  Atlas
//

import Foundation

/// A button on the Autopilot strip. None pushes: that's the toolbar's
/// Review & Push (board 57).
enum AutopilotStripAction: Hashable, Sendable {
    case runAutopilot
    case open
    case setUpAssistant
    case importCaptures

    var title: String {
        switch self {
        case .runAutopilot: String(localized: "Run Autopilot…")
        case .open: String(localized: "Open")
        case .setUpAssistant: String(localized: "Set Up Assistant…")
        case .importCaptures: String(localized: "Import Captures…")
        }
    }

    /// "Open Autopilot" when it sits next to another button.
    var secondaryTitle: String {
        self == .open ? String(localized: "Open Autopilot") : title
    }

    var identifier: String {
        switch self {
        case .runAutopilot: "studio.autopilot.run"
        case .open: "studio.autopilot.open"
        case .setUpAssistant: "studio.autopilot.setUp"
        case .importCaptures: "studio.autopilot.import"
        }
    }
}
