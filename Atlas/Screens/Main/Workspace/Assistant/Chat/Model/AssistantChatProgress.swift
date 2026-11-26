//
//  AssistantChatProgress.swift
//  Atlas
//

import Foundation

/// How far the chat's answer has come (board 69, the loading states of 24
/// Nov), from its run's activity: sending (asked, and Claude Code hasn't
/// reported a step yet), a step, or writing the answer (Claude Code's
/// words came after its last step, or its result did). Counted in real
/// units, never with time: the steps so far plus the answer still to
/// write, so the pill reads “2 of 3” and its bar moves one step at a time.
/// Sending has no count: nothing to count yet.
struct AssistantChatProgress: Equatable, Sendable {
    enum Stage: Equatable, Sendable {
        /// Asked; no step reported yet.
        case sending
        /// The last of `steps` runs.
        case working
        /// Every step is done; Claude Code writes the reply.
        case writing
    }

    /// The steps so far, the current one last.
    var steps: [AssistantChatStep] = []
    /// Claude Code writes the answer.
    var isWriting = false

    /// The bar's share at the first step, so it shows the work began.
    static let firstStepShare = 0.06

    /// From a run's activity: its steps, and whether words came after the
    /// last one. A failed step's note doesn't count.
    static func make(activity: [ClaudeCodeActivity], hasResult: Bool = false) -> AssistantChatProgress {
        let latest = activity.last { $0.kind != .started && $0.kind != .problem }
        return AssistantChatProgress(steps: AssistantChatStep.steps(from: activity), isWriting: hasResult || latest?.kind == .said)
    }

    var stage: Stage {
        if isWriting { return .writing }
        return steps.isEmpty ? .sending : .working
    }

    /// The unit under way, from 1; nil while sending.
    var current: Int? {
        switch stage {
        case .sending: nil
        case .working: steps.count
        case .writing: steps.count + 1
        }
    }

    /// The steps so far and the answer.
    var total: Int { steps.count + 1 }

    /// “2 of 3”; nil while sending.
    var countLabel: String? {
        current.map { AIProgress(done: $0, total: total).label }
    }

    /// The bar: the units done before the current one, out of the total;
    /// nil while sending, so there's no bar.
    var fraction: Double? {
        current.map { max(Self.firstStepShare, Double($0 - 1) / Double(total)) }
    }

    /// “Sending to Claude Code…”, “Read prices…”, “Writing the answer…”.
    func text(client: String) -> String {
        switch stage {
        case .sending:
            String(localized: "Sending to \(client)…", comment: "kind:loading · the chat sent the question; the assistant hasn't reported a step yet")
        case .working:
            String(localized: "\(steps.last?.text ?? "")…", comment: "kind:progress-step · the step being worked on")
        case .writing:
            String(localized: "Writing the answer…", comment: "kind:loading · the chat's last step: the assistant writes its reply")
        }
    }

    /// VoiceOver: “Claude Code: Read prices…, 2 of 3”.
    func accessibilityLabel(client: String) -> String {
        [Self.named(client, text(client: client)), countLabel].compactMap(\.self).joined(separator: ", ")
    }

    /// “Claude Code: Writing the answer…”.
    static func named(_ client: String, _ text: String) -> String {
        String(localized: "\(client): \(text)", comment: "kind:accessibility · the assistant's name, then what its chat says")
    }
}
