//
//  PrivacyWorksheet+Review.swift
//  Atlas
//

import Foundation

// The person's edits: answering by hand, accepting or rejecting a
// suggestion and settling a conflict. Answering an open question is in
// `Questions/PrivacyWorksheet+Questions.swift`.
extension PrivacyWorksheet {
    /// "Start from scratch": an empty worksheet the person fills in.
    mutating func start() {
        isStarted = true
    }

    /// The first question, answered Yes or No.
    mutating func setCollects(_ value: Bool) {
        isStarted = true
        if collects == nil {
            collects = .yours(value)
        } else {
            collects?.set(value)
        }
    }

    /// The person changed a type's answer on the page.
    mutating func edit(_ type: PrivacyDataType, to answer: PrivacyAnswer) {
        isStarted = true
        if entries[type] == nil {
            guard answer != .notCollected else { return }
            entries[type] = .yours(answer)
        } else {
            entries[type]?.edit(answer)
        }
    }

    /// "Accept": the suggestion counts as it is. A collected type without a
    /// purpose can't be accepted.
    mutating func accept(_ type: PrivacyDataType) {
        guard let entry = entries[type], entry.status == .unreviewed, !entry.answer.isMissingPurpose else { return }
        entries[type]?.status = .accepted
    }

    /// "Reject": the type becomes not collected, the person's answer.
    mutating func reject(_ type: PrivacyDataType) {
        guard entries[type] != nil else { return }
        entries[type]?.answer = .notCollected
        entries[type]?.status = .rejected
        entries[type]?.conflict = nil
    }

    /// The suggestions "Accept All High-Confidence" would accept: high
    /// confidence, unreviewed, no conflict, a purpose when collected, and no
    /// open question about them.
    var highConfidenceTypes: [PrivacyDataType] {
        PrivacyDataType.allCases.filter { type in
            guard let entry = entries[type], entry.status == .unreviewed, entry.conflict == nil,
                  entry.suggestion?.confidence == .high, !entry.answer.isMissingPurpose
            else { return false }
            return openQuestion(about: type) == nil
        }
    }

    /// "Accept All High-Confidence", which also accepts a suggested first
    /// question. Returns how many types it accepted.
    @discardableResult
    mutating func acceptAllHighConfidence() -> Int {
        let types = highConfidenceTypes
        for type in types {
            entries[type]?.status = .accepted
        }
        if collects?.status == .unreviewed {
            collects?.status = .accepted
        }
        return types.count
    }

    /// The person's own answer for the first question, accepting an
    /// assistant's as it is.
    mutating func acceptCollects() {
        guard collects?.status == .unreviewed else { return }
        collects?.status = .accepted
    }

    // MARK: - Conflicts

    /// "Keep yours": the assistant's different answer goes away.
    mutating func keepYours(_ type: PrivacyDataType) {
        entries[type]?.conflict = nil
    }

    /// "Use Claude Code's": the assistant's answer replaces the person's,
    /// accepted.
    mutating func useAssistants(_ type: PrivacyDataType) {
        guard let conflict = entries[type]?.conflict else { return }
        entries[type] = PrivacyTypeEntry(answer: conflict.answer, status: .accepted, suggestion: conflict)
    }

    // MARK: - Cross-check

    /// "Mark as Collected": the manifest is right; the type becomes
    /// collected with the assistant's purposes, or App Functionality.
    mutating func markCollected(_ type: PrivacyDataType) {
        let suggested = entries[type]?.suggestion?.answer
        let purposes = suggested.map(\.purposes).flatMap { $0.isEmpty ? nil : $0 } ?? [.appFunctionality]
        let answer = PrivacyAnswer(collected: true, purposes: purposes, linked: suggested?.linked ?? false, tracking: suggested?.tracking ?? false)
        edit(type, to: answer)
        explanations[type] = nil
    }

    /// "Not Collected, Explain…": keeps the answer and the reason, so the
    /// cross-check stops flagging it.
    mutating func explainNotCollected(_ type: PrivacyDataType, because reason: String) {
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        explanations[type] = trimmed
    }
}
