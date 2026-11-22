//
//  WorkspaceAutopilotState.swift
//  Atlas
//

import Foundation

/// What the toolbar's Autopilot button says: the section's action while
/// nothing runs, what a run is doing (“Making screenshots · 5 of 10
/// captures”), or, in purple, what it needs from the person (“Choose the
/// Look”). The menu bar icon and notifications read the same runs, and
/// what's waiting is counted on Review & Push, not here.
enum WorkspaceAutopilotState: Equatable {
    case idle
    /// A ring and what's being done; `isScreenshotRun` when a click opens
    /// the guided run.
    case running(String, isScreenshotRun: Bool = false)
    /// Purple, with what the guided run or Reply Automatically needs; a
    /// click opens that step, or Reviews.
    case needsYou(String)
    /// Reviews with Reply Automatically on: a green dot, “Auto-reply on ·
    /// 2 sent today” (board 58 · 3); a click runs the section's action.
    case autoReplyOn(String)
    /// The app's last Claude Code run stopped with a problem: still, with
    /// what stopped (“Claude Code couldn’t reach Atlas”); a click opens the
    /// reason.
    case failed(String)

    /// What decides it, read from the run engines the menu bar icon reads.
    struct Inputs: Equatable {
        /// A request from an asking button being worked on: its subject.
        var askSubject: String?
        /// The client working on proposals over MCP.
        var workingClient: String?
        /// Suggest Everything is receiving.
        var isSuggestingEverything = false
        /// Claude Code runs Atlas started that haven't ended.
        var launchedRuns = 0
        /// The guided screenshot run's state line while it works, “Making
        /// screenshots · 5 of 10 captures”.
        var screenshotRunWorking: String?
        /// What the guided run waits for, “Choose the Look”.
        var screenshotRunNeeds: String?
        /// Reviews Reply Automatically left for the person.
        var autoReplyNeeds = 0
        /// “Auto-reply on · 2 sent today”, in Reviews while it's on.
        var autoReplyOn: String?
        /// What stopped the app's last Claude Code run, until the person
        /// opens or forgets it.
        var failure: String?
    }

    /// What needs the person first, then what runs, else idle.
    init(_ inputs: Inputs) {
        if let needs = inputs.screenshotRunNeeds {
            self = .needsYou(needs)
        } else if inputs.autoReplyNeeds > 0 {
            self = .needsYou(Self.reviewsNeedYou(inputs.autoReplyNeeds))
        } else if let working = inputs.screenshotRunWorking {
            self = .running(working, isScreenshotRun: true)
        } else if let subject = inputs.askSubject {
            self = .running(String(localized: "Working · \(subject)"))
        } else if inputs.isSuggestingEverything {
            self = .running(String(localized: "Suggesting everything"))
        } else if let client = inputs.workingClient {
            self = .running(String(localized: "\(client) is working"))
        } else if inputs.launchedRuns > 0 {
            self = .running(String(localized: "Claude Code is working"))
        } else if let failure = inputs.failure {
            self = .failed(failure)
        } else if let line = inputs.autoReplyOn {
            self = .autoReplyOn(line)
        } else {
            self = .idle
        }
    }

    var isOn: Bool {
        if case .autoReplyOn = self { return true }
        return false
    }

    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }

    /// What the button says instead of its action, if anything.
    var text: String? {
        switch self {
        case .idle: nil
        case let .running(text, _), let .needsYou(text), let .autoReplyOn(text), let .failed(text): text
        }
    }

    /// What the button says for about 2 s once a run ends by itself:
    /// “Done · Store Page · German” after “Working · Store Page · German”.
    /// Nil when it didn't just finish: it still runs, needs the person, or
    /// stopped with a problem.
    func doneText(becoming next: Self) -> String? {
        guard case let .running(text, _) = self else { return nil }
        switch next {
        case .idle, .autoReplyOn: break
        case .running, .needsYou, .failed: return nil
        }
        let working = String(localized: "Working · ")
        guard text.hasPrefix(working) else { return String(localized: "Done") }
        return String(localized: "Done · \(text.dropFirst(working.count))")
    }

    /// “1 Review Needs You”.
    static func reviewsNeedYou(_ count: Int) -> String {
        count == 1 ? String(localized: "1 Review Needs You") : String(localized: "\(count) Reviews Need You")
    }

    /// “Auto-reply on · 2 sent today”, “Auto-reply paused”.
    static func autoReplyLine(isPaused: Bool, sentToday: Int) -> String {
        if isPaused { return String(localized: "Auto-reply paused") }
        return sentToday > 0 ? String(localized: "Auto-reply on · \(sentToday) sent today") : String(localized: "Auto-reply on")
    }

    /// What VoiceOver announces a change of, once: the phase, not its
    /// progress (“Making screenshots”, not “5 of 10 captures”); nil while
    /// idle.
    var announcementKey: String? {
        switch self {
        case .idle, .autoReplyOn: nil
        case let .running(text, _): "running:" + (text.components(separatedBy: " · ").first ?? text)
        case let .needsYou(text): "needs:" + text
        case let .failed(text): "failed:" + text
        }
    }

    /// What the guided run waits for, as the button says it; nil while it
    /// works, or once its set was approved into Review & Push or pushed.
    static func screenshotNeeds(_ run: AutopilotRun) -> String? {
        guard !(run.stage.isRunning && run.finishedAt == nil), let turn = BackgroundNeedsBuilder.turn(for: run) else { return nil }
        return needs(turn)
    }

    /// What the guided run waits for, as the button says it.
    static func needs(_ turn: AutopilotTurn) -> String {
        switch turn {
        case .pick: String(localized: "Pick the Captures")
        case .choose: String(localized: "Choose the Look")
        case .review: String(localized: "Approve All")
        }
    }
}
