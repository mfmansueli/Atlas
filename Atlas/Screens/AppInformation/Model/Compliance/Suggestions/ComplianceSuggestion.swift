//
//  ComplianceSuggestion.swift
//  Atlas
//

import Foundation

/// An assistant's answer to one App Compliance regulation, with why and
/// its evidence, kept on this Mac (`AppInformationNotes`) until the person
/// accepts or dismisses it. Compliance answers are the person's: Accept
/// All never takes these.
struct ComplianceSuggestion: Hashable, Codable, Sendable {
    var answer: ComplianceSuggestedAnswer
    /// Who suggested it, why, and what it found in the project.
    var evidence: AssistantEvidence

    var rule: ComplianceRule { answer.rule }

    /// e.g. "Claude Code".
    var client: String { evidence.client }

    /// Still worth showing: the regulation takes an answer and this isn't
    /// the one already given.
    func isOpen(in report: ComplianceReport) -> Bool {
        report.takesSuggestion(for: rule) && !answer.isGiven(in: report)
    }
}
