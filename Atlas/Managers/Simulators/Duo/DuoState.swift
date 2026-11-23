//
//  DuoState.swift
//  Atlas
//

import Foundation

/// iPhone Duo's simulator as Atlas last saw it (`DuoWatcher`).
enum DuoState: Hashable, Sendable {
    /// Not looked at yet.
    case unknown
    /// No helper to ask.
    case noHelper
    /// A helper from before it could look at the Duo: it needs saving again.
    case oldHelper
    /// No iPhone Duo simulator on this Mac.
    case noSimulator
    case notRunning
    /// Atlas is starting it.
    case starting
    /// Its inner display is black: Atlas opens it during a run.
    case closed
    /// Closed for its closed screenshots, on the cover display.
    case closedForScreens
    /// Open while its closed screenshots are next: Atlas is
    /// restarting it, which closes it.
    case closing
    /// Atlas is opening it in Device Hub.
    case opening
    /// Closed, and Atlas needs Accessibility to open it.
    case needsAccessibility
    /// Closed, and the helper is from before it could open it.
    case helperCantOpen
    /// Closed, and Atlas couldn't open it: why.
    case couldntOpen(String)
    /// Its inner display shows only a spinner, for now.
    case spinner
    /// It's stuck, and Atlas is restarting it.
    case restarting(DuoStep.Reason)
    /// Still stuck after restarting it: the person erases it.
    case stuck(DuoStep.Reason)
    /// Its inner display shows the Home Screen or an app.
    case open
    /// The helper couldn't read it: why.
    case failed(String)

    init(_ inner: DuoInnerDisplay) {
        switch inner {
        case .black: self = .closed
        case .spinner: self = .spinner
        case .showing: self = .open
        }
    }

    /// Atlas is starting, opening or restarting it.
    var isWorking: Bool {
        switch self {
        case .starting, .opening, .closing, .restarting: true
        default: false
        }
    }

    /// Closed, and Atlas won't open it by itself: the person opens it
    /// in Device Hub, or does what lets Atlas.
    var waitsForPerson: Bool {
        switch self {
        case .needsAccessibility, .helperCantOpen, .couldntOpen, .stuck: true
        default: false
        }
    }

    /// Atlas can see it, so a stuck one is restarted and an opened
    /// one goes on by itself.
    var isWatched: Bool {
        switch self {
        case .unknown, .noHelper, .oldHelper, .noSimulator, .failed: false
        default: true
        }
    }

    /// "Closed: Atlas opens it in Device Hub."
    var summary: String {
        switch self {
        case .unknown:
            String(localized: "Looking at iPhone Duo…")
        case .noHelper:
            String(localized: "Install the helper so Atlas can open and check iPhone Duo.")
        case .oldHelper:
            String(localized: "Save the helper again so Atlas can open, check and restart iPhone Duo.")
        case .noSimulator:
            String(localized: "There’s no iPhone Duo simulator on this Mac yet.")
        case .notRunning:
            String(localized: "Not running: Atlas starts and opens it when the run needs it.")
        case .starting:
            String(localized: "Starting iPhone Duo…")
        case .closed:
            String(localized: "Closed: Atlas opens it in Device Hub.")
        case .closedForScreens:
            String(localized: "Closed for the cover-display screenshots. Atlas opens it for the rest.")
        case .closing:
            String(localized: "Restarting it to close it for the closed screenshots…")
        case .opening:
            String(localized: "Opening iPhone Duo in Device Hub…")
        case .needsAccessibility:
            String(localized: """
            Closed. Allow Atlas in Privacy & Security › Accessibility; it only presses Open in Device Hub.
            """)
        case .helperCantOpen:
            String(localized: "Closed: save the helper again so Atlas can open it itself, or open it in Device Hub.")
        case let .couldntOpen(reason):
            String(localized: "Closed: Atlas couldn’t open it (\(reason)). Open it in Device Hub.")
        case .spinner:
            String(localized: "Its inner display shows a spinner while it starts.")
        case .restarting(.springBoardCrashed):
            String(localized: "SpringBoard crashed. Restarting iPhone Duo…")
        case .restarting(.spinner):
            String(localized: "Stuck on a spinner. Restarting it…")
        case .stuck:
            String(localized: "Still stuck after restarting it twice: erase it in Device Hub, start it, then open it.")
        case .open:
            String(localized: "Open.")
        case let .failed(reason):
            reason
        }
    }
}
