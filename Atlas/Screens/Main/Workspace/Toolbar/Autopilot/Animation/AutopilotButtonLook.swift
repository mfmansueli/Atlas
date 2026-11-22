//
//  AutopilotButtonLook.swift
//  Atlas
//

import Foundation

/// What the toolbar's Autopilot button draws (board 57, “While it works”):
/// still while idle, needing the person or stopped; the light along its
/// edge and the twinkling sparkle only while something really runs for the
/// app, with a bar when the run counts its steps; and a green check for
/// about 2 s once it's done. Pure, from the button's state.
enum AutopilotButtonLook: Equatable {
    /// The purple sparkle and the section's action.
    case idle
    /// What runs, and its progress (0–1) when it's counted; nil draws no
    /// bar rather than a made-up one.
    case working(String, progress: Double?)
    /// “Done · Store Page · German”, after a run ended by itself.
    case done(String)
    /// Solid purple with what the run waits for: still.
    case needsYou(String)
    /// What stopped the last run: still; a click opens the reason.
    case failed(String)
    /// Reviews with Reply Automatically on: the green dot.
    case autoReplyOn(String)

    /// How long the check stays before the button is idle again.
    static let doneDuration: Duration = .seconds(2)

    /// The look for `state`; `done` while the check shows, and the guided
    /// run's progress while it works.
    init(state: WorkspaceAutopilotState, done: String?, runProgress: GuidedRunProgress?) {
        switch state {
        case let .running(text, isScreenshotRun):
            let counted = isScreenshotRun ? runProgress.flatMap { $0.isCounted ? $0.fraction : nil } : nil
            self = .working(text, progress: counted.map { min(max($0, 0), 1) })
        case let .needsYou(text):
            self = .needsYou(text)
        case let .failed(text):
            self = .failed(text)
        case let .autoReplyOn(text):
            self = done.map(Self.done) ?? .autoReplyOn(text)
        case .idle:
            self = done.map(Self.done) ?? .idle
        }
    }

    /// The light runs and the stars twinkle.
    var isWorking: Bool {
        if case .working = self { return true }
        return false
    }

    /// What the button says instead of its action; nil while idle.
    var text: String? {
        switch self {
        case .idle: nil
        case let .working(text, _), let .done(text), let .needsYou(text), let .failed(text), let .autoReplyOn(text): text
        }
    }

    /// The 2 pt bar's value; nil draws none.
    var progress: Double? {
        if case let .working(_, progress) = self { return progress }
        return nil
    }

    /// “55 percent”, after what runs, for VoiceOver; nil without a counted
    /// progress.
    var spokenProgress: String? {
        guard let progress else { return nil }
        return String(localized: "\(Int((progress * 100).rounded())) percent")
    }
}
