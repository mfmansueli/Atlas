//
//  AutopilotButtonLook.swift
//  Atlas
//

import Foundation

/// What the toolbar's Autopilot button draws (board 57, “While it works”,
/// with motion v2, board 68): the still spark and what runs while
/// something really runs for the app, with a stepped bar when the run counts
/// its steps; filled purple when it needs the person; and a green check for
/// about 2 s once it's done. Pure, from the button's state.
enum AutopilotButtonLook: Hashable {
    /// The purple sparkle and the section's action.
    case idle
    /// What runs, and its progress (0–1) when it's counted; nil draws no
    /// bar rather than a made-up one.
    case working(String, progress: Double?)
    /// Like `working`, with its bar, while the spark sits on the card it
    /// works on (Make Review Screenshots…).
    case counting(String, progress: Double)
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
        case let .capturing(text, progress):
            self = .counting(text, progress: min(max(progress, 0), 1))
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

    /// Something runs for the app. Motion v2: the spark stays still; only
    /// a counted bar moves.
    var isWorking: Bool {
        if case .working = self { return true }
        return false
    }

    /// Filled purple, saying what it needs; it nudges once as it starts.
    var isNeedingYou: Bool {
        if case .needsYou = self { return true }
        return false
    }

    /// What the button says instead of its action; nil while idle.
    var text: String? {
        switch self {
        case .idle: nil
        case let .working(text, _), let .counting(text, _), let .done(text), let .needsYou(text), let .failed(text), let .autoReplyOn(text): text
        }
    }

    /// The 2 pt bar's value; nil draws none.
    var progress: Double? {
        switch self {
        case let .working(_, progress): progress
        case let .counting(_, progress): progress
        case .idle, .done, .needsYou, .failed, .autoReplyOn: nil
        }
    }

    /// “55 percent”, after what runs, for VoiceOver; nil without a counted
    /// progress.
    var spokenProgress: String? {
        guard let progress else { return nil }
        return String(localized: "\(Int((progress * 100).rounded())) percent")
    }
}
