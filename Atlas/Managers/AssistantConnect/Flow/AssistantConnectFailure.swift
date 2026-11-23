//
//  AssistantConnectFailure.swift
//  Atlas
//

import Foundation

/// Why Connect stopped before the hello: the assistant didn't answer in
/// time (the design's "didn't answer"), Atlas couldn't add itself, the app
/// couldn't be restarted, or Claude Code's run failed with its own reason.
enum AssistantConnectFailure: Hashable, Sendable {
    case noAnswer
    case couldNotAdd(String)
    /// The open app didn't quit, so it can't read Atlas's entry yet.
    case couldNotRestart
    case run(ClaudeCodeRunFailure)

    /// "Cursor didn't answer".
    func title(for assistant: ConnectableAssistant) -> String {
        switch self {
        case .noAnswer, .couldNotRestart: String(localized: "\(assistant.title) didn’t answer")
        case .couldNotAdd: String(localized: "Atlas couldn’t add itself to \(assistant.title)")
        case let .run(failure): failure.title
        }
    }

    func detail(for assistant: ConnectableAssistant, timeout: Duration) -> String {
        let seconds = Int(timeout.components.seconds)
        switch self {
        case .noAnswer:
            return String(localized: """
            Atlas added itself to \(assistant.title) but heard nothing for \(seconds) seconds. Nothing is broken; it’s usually \
            one of these.
            """)
        case .couldNotRestart:
            return String(localized: "Atlas added itself to \(assistant.title), but \(assistant.title) didn’t restart. It’s usually one of these.")
        case let .couldNotAdd(message):
            return message
        case let .run(failure):
            return failure.detail
        }
    }
}
