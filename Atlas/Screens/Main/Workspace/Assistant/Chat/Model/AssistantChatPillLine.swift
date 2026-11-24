//
//  AssistantChatPillLine.swift
//  Atlas
//

import Foundation

/// What the closed chat says in its one line (board 69): what's happening
/// right now, or the way to ask. In order: no assistant to ask, Claude
/// Code stopped, a push running, a step of the answer, a question that
/// waits for the person, an answer not seen yet, a kept draft, and else
/// “Ask about Lumen…”.
struct AssistantChatPillLine: Equatable, Sendable {
    enum Lead: Equatable, Sendable {
        /// Purple sparkles: ready to ask.
        case sparkles
        /// A dot in the colour of what's happening.
        case dot(Dot)
        /// A grey “Draft” tag.
        case draft
    }

    enum Dot: Equatable, Sendable {
        /// Purple and moving: the assistant works (Motion v2's one loop).
        case working
        /// Purple and still: something arrived.
        case arrived
        /// Amber: an AI failure.
        case failure
        /// Blue: a push, which isn't AI.
        case push
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

    var lead: Lead
    var text: String
    /// Grey like a field's placeholder.
    var isPlaceholder = false
    /// “Step 3”, “14 of 23”.
    var detail: String?
    /// A push's share sent, 0…1: counted, never timed.
    var progress: Double?
    var tag: Tag?
    var action: Action?
    var showsShortcut = false

    struct Inputs: Equatable, Sendable {
        var appName: String
        var client: String
        /// Atlas can start the assistant.
        var canAsk: Bool
        var chat: AssistantChat
        /// The working turn's steps so far.
        var steps: [AssistantChatStep] = []
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
        if last?.failure != nil {
            return AssistantChatPillLine(
                lead: .dot(.failure), text: String(localized: "\(inputs.client) stopped", comment: "kind:status · the chat's closed line"),
                action: .tryAgain
            )
        }
        if let push = inputs.push, push.total > 0 {
            return AssistantChatPillLine(
                lead: .dot(.push),
                text: push.total == 1
                    ? String(localized: "Pushing 1 change", comment: "kind:status · the chat's closed line")
                    : String(localized: "Pushing \(push.total) changes", comment: "kind:status · the chat's closed line"),
                detail: String(localized: "\(push.sent) of \(push.total)", comment: "kind:progress-step"),
                progress: Double(push.sent) / Double(push.total)
            )
        }
        if chat.isWorking {
            let step = inputs.steps.last?.text ?? String(localized: "Starting \(inputs.client)…", comment: "kind:status · the chat's closed line")
            let detail = inputs.steps.isEmpty
                ? nil : String(localized: "Step \(inputs.steps.count)", comment: "kind:progress-step · the chat's closed line")
            return AssistantChatPillLine(lead: .dot(.working), text: step, detail: detail)
        }
        if let question = chat.question {
            return AssistantChatPillLine(lead: .dot(.arrived), text: question.text, tag: .needsYou)
        }
        if chat.isUnseen, let last, case let .answered(text, suggestions) = last.state {
            return AssistantChatPillLine(
                lead: .dot(.arrived), text: firstSentence(of: text),
                tag: suggestions.map { .suggestions($0.count) } ?? .answer
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

    /// VoiceOver: name, state, count.
    func accessibilityLabel(client: String) -> String {
        [client, text, detail, tagText].compactMap(\.self).joined(separator: ", ")
    }

    /// The answer's first sentence, for the one line.
    static func firstSentence(of text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        guard let end = line.firstIndex(where: { ".?!".contains($0) }) else { return line }
        return String(line[...end])
    }
}
