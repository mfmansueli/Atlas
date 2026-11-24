//
//  AssistantChatStep.swift
//  Atlas
//

import Foundation

/// One step of a chat answer while it works, from its run's activity:
/// “Read the store page”, “Read CHANGELOG.md”, “Suggest prices”. Steps are
/// counted as they happen (Motion v2: progress only from countable units),
/// so the pill says “Step 3”, never a guess at how much is left.
struct AssistantChatStep: Identifiable, Hashable, Sendable {
    var id: Int
    var text: String

    /// The steps worth showing: Atlas's tools, files, searches and
    /// commands, without one repeated right after itself.
    static func steps(from activity: [ClaudeCodeActivity]) -> [AssistantChatStep] {
        var steps: [AssistantChatStep] = []
        for item in activity {
            guard let text = Self.stepText(for: item), steps.last?.text != text else { continue }
            steps.append(AssistantChatStep(id: item.id, text: text))
        }
        return steps
    }

    /// The words for one line of activity; nil for what isn't a step.
    static func stepText(for item: ClaudeCodeActivity) -> String? {
        switch item.kind {
        case .atlas: atlasStep(item.text)
        case .file, .search: item.text
        case .command: commandStep(item.text)
        case .tool: item.text.replacingOccurrences(of: "_", with: " ").capitalizedFirst
        case .started, .said, .problem: nil
        }
    }

    /// `get_store_page` → “Read the store page”; `propose_prices` →
    /// “Suggest prices”.
    static func atlasStep(_ tool: String) -> String {
        let words = { (prefix: String) in tool.dropFirst(prefix.count).replacingOccurrences(of: "_", with: " ") }
        if tool == "ask_in_chat" { return String(localized: "Ask you", comment: "kind:progress-step · the chat asks the person") }
        for prefix in ["get_", "list_"] where tool.hasPrefix(prefix) {
            return String(localized: "Read \(words(prefix))", comment: "kind:progress-step · an Atlas tool that reads, e.g. Read store page")
        }
        for prefix in ["propose_", "suggest_"] where tool.hasPrefix(prefix) {
            return String(localized: "Suggest \(words(prefix))", comment: "kind:progress-step · an Atlas tool that suggests, e.g. Suggest prices")
        }
        return tool.replacingOccurrences(of: "_", with: " ").capitalizedFirst
    }

    /// `git log v1.3..HEAD --oneline` → “Run git log”.
    static func commandStep(_ command: String) -> String {
        let program = command.split(separator: " ").prefix(2).joined(separator: " ")
        return String(localized: "Run \(program)", comment: "kind:progress-step · a command, e.g. Run git log")
    }
}

private extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
