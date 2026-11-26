//
//  AutopilotBarStrip.swift
//  Atlas
//

import Foundation

/// The strip the closed Autopilot bar grows above its field when something
/// happens (board 80), or nil while nothing does. In order: what needs the
/// person (the assistant's question with its answers as buttons, purple;
/// a guided run's step), what works (the step, its count and a bar from
/// counted units, Stop), what stopped (amber, the reason, Try Again), and
/// what's done (one line, Show, ✕). Open, the bar shows the conversation
/// instead, so there's no strip. Its ✦ is the one loop on screen while
/// work runs (Motion v2).
struct AutopilotBarStrip: Equatable {
    enum Kind: Equatable {
        case working
        case needsYou
        case stopped
        case done
    }

    /// Who it's about, so the bar knows what its buttons do.
    enum Source: Equatable {
        /// A question asked in the bar's field: Stop, its answers, Try
        /// Again and Open act on the conversation.
        case chat
        /// A request from one of the bar's actions or a page's asking
        /// button.
        case ask
        /// A guided run, Make Review Screenshots… or Reply Automatically:
        /// Show opens where it waits.
        case run
        /// Something the assistant works on with no place of its own
        /// (Suggest Everything, a client working over MCP).
        case assistant
        /// The app's last Claude Code run stopped with a problem.
        case failedRun
    }

    /// The button on its first line.
    enum Action: Equatable {
        case show
        case open
        case tryAgain
        case details
    }

    var kind: Kind
    var source: Source
    /// What ✕ and its arrival refer to: “chat.<turn>”, “ask.<id>”.
    var key: String
    var title: String
    /// “2 of 3”.
    var detail: String?
    /// The line under it: the request quoted, where to look, the reason.
    var subtitle: String?
    /// The bar's share, from counted units only; nil draws no bar.
    var progress: Double?
    /// The assistant's answers to choose from, as buttons.
    var choices: [String] = []
    var action: Action?
    var canStop = false
    var canDismiss = false

    struct Inputs: Equatable {
        var client = MCPClientKind.claudeCode.title
        /// The app's runs, as the menu bar icon reads them too.
        var state: WorkspaceAutopilotState = .idle
        /// The guided run's progress while it works.
        var runProgress: GuidedRunProgress?
        /// The guided or review screenshot run can be cancelled.
        var canCancelRun = false
        /// A request from a button, while it runs, and how far its run came.
        var ask: AssistantAsk?
        var askProgress = AssistantChatProgress()
        /// What the person sent from the bar, quoted while it works.
        var sent: AutopilotBarRequest?
        var chat = AssistantChat()
        var chatProgress = AssistantChatProgress()
        /// The request that just finished.
        var done: AutopilotBarFinished?
        /// The strips closed with ✕.
        var dismissed: Set<String> = []
        /// The failed run's request can be sent again.
        var canRetryFailure = false
        var isOpen = false
    }

    static func make(_ inputs: Inputs) -> AutopilotBarStrip? {
        guard !inputs.isOpen else { return nil }
        if let needs = needsYou(inputs) { return needs }
        if let working = working(inputs) { return working }
        if let stopped = stopped(inputs), !inputs.dismissed.contains(stopped.key) { return stopped }
        if let done = done(inputs), !inputs.dismissed.contains(done.key) { return done }
        return nil
    }

    // MARK: - Needs you

    private static func needsYou(_ inputs: Inputs) -> AutopilotBarStrip? {
        if let last = inputs.chat.last, let question = inputs.chat.question {
            return AutopilotBarStrip(
                kind: .needsYou, source: .chat, key: "chat.\(last.id.uuidString)", title: question.text, choices: question.choices
            )
        }
        if case let .needsYou(text) = inputs.state {
            return AutopilotBarStrip(kind: .needsYou, source: .run, key: "needs.\(text)", title: text, action: .show)
        }
        return nil
    }

    // MARK: - Working

    private static func working(_ inputs: Inputs) -> AutopilotBarStrip? {
        if let ask = inputs.ask {
            let progress = inputs.askProgress
            let quote = inputs.sent?.text(subject: ask.subject) ?? ask.subject
            return AutopilotBarStrip(
                kind: .working, source: .ask, key: "ask.\(ask.id.uuidString)", title: askTitle(progress, client: ask.client),
                detail: progress.countLabel,
                subtitle: String(localized: "“\(quote)” · they show up in purple", comment: "kind:status · under the Autopilot bar's working strip"),
                progress: progress.fraction, canStop: ask.runID != nil
            )
        }
        if inputs.chat.isWorking, let last = inputs.chat.last {
            let progress = inputs.chatProgress
            return AutopilotBarStrip(
                kind: .working, source: .chat, key: "chat.\(last.id.uuidString)", title: progress.text(client: inputs.client),
                detail: progress.countLabel, subtitle: "“\(last.text)”", progress: progress.fraction, canStop: true
            )
        }
        switch inputs.state {
        case let .running(text, isScreenshotRun):
            guard isScreenshotRun else {
                return AutopilotBarStrip(kind: .working, source: .assistant, key: "working.\(text)", title: text)
            }
            let counted = inputs.runProgress.flatMap { $0.isCounted ? $0.fraction : nil }
            return AutopilotBarStrip(
                kind: .working, source: .run, key: "working.\(text)", title: text, subtitle: inputs.runProgress?.line,
                progress: counted.map(clamped), action: .show, canStop: inputs.canCancelRun
            )
        case let .capturing(text, progress):
            return AutopilotBarStrip(
                kind: .working, source: .run, key: "working.\(text)", title: text, progress: clamped(progress), action: .show,
                canStop: inputs.canCancelRun
            )
        case .idle, .needsYou, .finished, .autoReplyOn, .failed:
            return nil
        }
    }

    /// “Sending to Claude Code…”, the step, then “Writing suggestions…”.
    private static func askTitle(_ progress: AssistantChatProgress, client: String) -> String {
        guard progress.stage == .writing else { return progress.text(client: client) }
        return String(localized: "Writing suggestions…", comment: "kind:loading · a request's last step: the assistant writes what it suggests")
    }

    // MARK: - Stopped

    private static func stopped(_ inputs: Inputs) -> AutopilotBarStrip? {
        if let last = inputs.chat.last, let failure = last.failure {
            return AutopilotBarStrip(
                kind: .stopped, source: .chat, key: "chat.\(last.id.uuidString)",
                title: String(localized: "\(inputs.client) stopped", comment: "kind:status · the Autopilot bar's strip"),
                subtitle: stoppedLine(failure.detail), action: failure.canRetry ? .tryAgain : nil, canDismiss: true
            )
        }
        if case let .failed(text) = inputs.state {
            return AutopilotBarStrip(
                kind: .stopped, source: .failedRun, key: "failed.\(text)", title: text,
                subtitle: String(localized: "Nothing changed in Atlas.", comment: "kind:status · under the Autopilot bar's stopped strip"),
                action: inputs.canRetryFailure ? .tryAgain : .details, canDismiss: true
            )
        }
        return nil
    }

    /// The reason, then that nothing changed.
    private static func stoppedLine(_ reason: String) -> String {
        let nothing = String(localized: "Nothing changed in Atlas.", comment: "kind:status · under the Autopilot bar's stopped strip")
        return reason.isEmpty ? nothing : "\(reason) \(nothing)"
    }

    // MARK: - Done

    private static func done(_ inputs: Inputs) -> AutopilotBarStrip? {
        if inputs.chat.isUnseen, let last = inputs.chat.last, case let .answered(text, suggestions) = last.state {
            let open = String(localized: "Open to read the answer", comment: "kind:status · under the Autopilot bar's done strip")
            return AutopilotBarStrip(
                kind: .done, source: .chat, key: "chat.\(last.id.uuidString)",
                title: text.isEmpty ? String(localized: "Answer ready", comment: "kind:done-state · the Autopilot bar's strip") : firstSentence(of: text),
                subtitle: suggestions.map { "\($0.title) · \(open)" } ?? open, action: .open, canDismiss: true
            )
        }
        if let done = inputs.done {
            return AutopilotBarStrip(kind: .done, source: .ask, key: done.key, title: done.title, subtitle: done.text, action: .show, canDismiss: true)
        }
        if case let .finished(text) = inputs.state {
            return AutopilotBarStrip(kind: .done, source: .run, key: "ready.\(text)", title: text, action: .show, canDismiss: true)
        }
        return nil
    }

    // MARK: - Words

    /// The button's words: “Show”, “Open”, “Try Again”, “Details”.
    var actionTitle: String? {
        switch action {
        case .show: String(localized: "Show", comment: "kind:button · the Autopilot bar's strip")
        case .open: String(localized: "Open", comment: "kind:button · the Autopilot bar's strip")
        case .tryAgain: String(localized: "Try Again", comment: "kind:button")
        case .details: String(localized: "Details", comment: "kind:button · the Autopilot bar's strip: why the run stopped")
        case nil: nil
        }
    }

    /// VoiceOver: “Autopilot, Read store page…, 2 of 3”.
    var accessibilityLabel: String {
        var parts = [Self.announcement(title)]
        if kind == .needsYou { parts.append(String(localized: "Needs you", comment: "kind:pill")) }
        if let detail { parts.append(detail) }
        return parts.joined(separator: ", ")
    }

    /// What VoiceOver announces once when it changes: the kind and what
    /// it's about, not its count.
    var announcementKey: String {
        "\(kind):\(title.components(separatedBy: " · ").first ?? title)"
    }

    /// “Autopilot, Making screenshots, 5 of 10 captures”.
    nonisolated static func announcement(_ text: String) -> String {
        String(localized: "Autopilot, \(text.replacingOccurrences(of: " · ", with: ", "))", comment: "kind:accessibility · the Autopilot bar says what happens")
    }

    /// The answer's first sentence, for the one line.
    static func firstSentence(of text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        guard let end = line.firstIndex(where: { ".?!".contains($0) }) else { return line }
        return String(line[...end])
    }

    private static func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
