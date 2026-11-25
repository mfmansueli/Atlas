//
//  AssistantChatPillLine.swift
//  Atlas
//

import Foundation

/// What the closed chat says in its one line (board 69): what's happening
/// right now, or the way to ask. In order: no assistant to ask, Claude
/// Code stopped, a push running, the answer being sent, worked on or
/// written, a question that waits for the person, an answer not seen yet,
/// a kept draft, and else “Ask about Lumen…”. Its motion is Motion v2's,
/// through the DesignSystem's modifiers: the ✦ breathes and the step's
/// text sweeps while the assistant works, the ✦ blooms and the pill ticks
/// in when the answer arrives, “Needs you” nudges once, a failure slides
/// in 4 pt.
struct AssistantChatPillLine: Equatable, Sendable {
    enum Lead: Equatable, Sendable {
        /// The purple ✦, still: ready to ask, or waiting for the person.
        case sparkles
        /// The ✦ breathing: the answer is sent or worked on (part of the
        /// one loop on screen).
        case breathing
        /// The ✦ that blooms once: an answer arrived.
        case arrived
        /// Amber warning: an AI failure.
        case failure
        /// The push symbol in blue: a push, which isn't AI.
        case push
        /// A grey “Draft” tag.
        case draft
    }

    enum Tag: Equatable, Sendable {
        /// Filled purple: the only time the chat is filled, the assistant waits.
        case needsYou
        /// Tinted purple, “1 suggestion”.
        case suggestions(Int)
        /// Grey: an answer without suggestions.
        case answer
    }

    enum Action: Equatable, Sendable {
        case connect
        case tryAgain
    }

    /// The small bar after the count: counted, never timed.
    struct Meter: Equatable, Sendable {
        /// 0…1.
        var fraction: Double
        /// Purple with the sweep (the assistant's steps), else blue (a push).
        var isAI: Bool
    }

    /// What the line shows arrived, and when: the ✦ blooms and the tag
    /// ticks in only when it lands while the person looks.
    struct Arrival: Equatable, Sendable {
        var key: String
        var arrivedAt: Date?
    }

    var lead: Lead
    var text: String
    /// Grey like a field's placeholder.
    var isPlaceholder = false
    /// One sweep passes over the text: the assistant works on it.
    var sweeps = false
    /// “2 of 3”, “14 of 23”.
    var detail: String?
    var meter: Meter?
    var tag: Tag?
    var action: Action?
    var showsShortcut = false
    var arrival: Arrival?
    /// The failure shown, so a new one slides in.
    var failureKey: String?

    struct Inputs: Equatable, Sendable {
        var appName: String
        var client: String
        /// Atlas can start the assistant.
        var canAsk: Bool
        var chat: AssistantChat
        /// How far the working turn's answer has come.
        var progress = AssistantChatProgress()
        var push: PushProgress?
    }

    struct PushProgress: Equatable, Sendable {
        var sent: Int
        var total: Int
    }

    static func make(_ inputs: Inputs) -> AssistantChatPillLine {
        let chat = inputs.chat
        let last = chat.last
        if !inputs.canAsk, !chat.isWorking {
            return AssistantChatPillLine(
                lead: .sparkles, text: String(localized: "No assistant connected", comment: "kind:status · the chat's closed line"),
                isPlaceholder: true, action: .connect
            )
        }
        if let last, last.failure != nil {
            return AssistantChatPillLine(
                lead: .failure, text: String(localized: "\(inputs.client) stopped", comment: "kind:status · the chat's closed line"),
                action: .tryAgain, failureKey: "chat.failure.\(last.id.uuidString)"
            )
        }
        if let push = inputs.push, push.total > 0 {
            return AssistantChatPillLine(
                lead: .push,
                text: push.total == 1
                    ? String(localized: "Pushing 1 change", comment: "kind:status · the chat's closed line")
                    : String(localized: "Pushing \(push.total) changes", comment: "kind:status · the chat's closed line"),
                detail: String(localized: "\(push.sent) of \(push.total)", comment: "kind:progress-step"),
                meter: Meter(fraction: Double(push.sent) / Double(push.total), isAI: false)
            )
        }
        if chat.isWorking {
            let progress = inputs.progress
            return AssistantChatPillLine(
                lead: .breathing, text: progress.text(client: inputs.client), sweeps: true, detail: progress.countLabel,
                meter: progress.fraction.map { Meter(fraction: $0, isAI: true) }
            )
        }
        if let last, let question = chat.question {
            return AssistantChatPillLine(lead: .sparkles, text: question.text, tag: .needsYou, arrival: arrival(of: last))
        }
        if chat.isUnseen, let last, case let .answered(text, suggestions) = last.state {
            return AssistantChatPillLine(
                lead: .arrived, text: firstSentence(of: text),
                tag: suggestions.map { .suggestions($0.count) } ?? .answer, arrival: arrival(of: last)
            )
        }
        if chat.hasDraft {
            return AssistantChatPillLine(lead: .draft, text: chat.draft.trimmingCharacters(in: .whitespacesAndNewlines), showsShortcut: true)
        }
        return AssistantChatPillLine(
            lead: .sparkles, text: String(localized: "Ask about \(inputs.appName)…", comment: "kind:placeholder · the chat's closed line"),
            isPlaceholder: true, showsShortcut: true
        )
    }

    /// The pill's own key for a turn's arrival: the panel's reply has
    /// another, so each plays its own.
    private static func arrival(of turn: AssistantChatTurn) -> Arrival {
        Arrival(key: "chat.pill.\(turn.id.uuidString)", arrivedAt: turn.endedAt)
    }

    /// The tag's words: “Needs you”, “1 suggestion”, “Answer”.
    var tagText: String? {
        switch tag {
        case .needsYou: String(localized: "Needs you", comment: "kind:pill")
        case .suggestions(1): String(localized: "1 suggestion", comment: "kind:pill")
        case let .suggestions(count): String(localized: "\(count) suggestions", comment: "kind:pill")
        case .answer: String(localized: "Answer", comment: "kind:pill")
        case nil: nil
        }
    }

    /// The button's words: “Connect…”, “Try Again”.
    var actionTitle: String? {
        switch action {
        case .connect: String(localized: "Connect…", comment: "kind:button")
        case .tryAgain: String(localized: "Try Again", comment: "kind:button")
        case nil: nil
        }
    }

    /// VoiceOver: “Claude Code: Ask about Lumen…”, then the tag; the count
    /// is the value.
    func accessibilityLabel(client: String) -> String {
        [Self.named(client, text), tagText].compactMap(\.self).joined(separator: ", ")
    }

    /// VoiceOver's value: the count, “2 of 3”.
    var accessibilityValue: String {
        detail ?? ""
    }

    /// “Claude Code: Writing the answer…”.
    static func named(_ client: String, _ text: String) -> String {
        String(localized: "\(client): \(text)", comment: "kind:accessibility · the assistant's name, then what its chat says")
    }

    /// The answer's first sentence, for the one line.
    static func firstSentence(of text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        guard let end = line.firstIndex(where: { ".?!".contains($0) }) else { return line }
        return String(line[...end])
    }
}
