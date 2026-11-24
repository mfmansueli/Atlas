//
//  NominationNeed.swift
//  Atlas
//

import Foundation

/// The one line on a nomination's card and page saying what needs the
/// person, in order: Apple's refusal, what's missing, a start date that has
/// passed, what waits in Review & Push, a close start date, or that it's
/// ready.
struct NominationNeed: Hashable, Sendable {
    enum Tone: Hashable, Sendable {
        /// Grey: nothing needs you.
        case quiet
        /// Amber: something to fix or know.
        case warning
        /// Blue: it waits in Review & Push.
        case queued
        /// Purple: an assistant's suggestion.
        case suggested
    }

    var text: String
    var tone: Tone

    /// Under 3 weeks to the start, Apple's advice is to nominate earlier.
    static let closeDays = 21

    struct Facts {
        var nomination: Nomination
        var queued: Set<NominationChangeBuilder.Kind>
        var isRefused: Bool
        var actionRequest: NominationActionRequest?
        var now: Date
    }

    init(text: String, tone: Tone) {
        self.text = text
        self.tone = tone
    }

    init(_ facts: Facts) {
        let nomination = facts.nomination
        let content = nomination.content
        let days = content.daysUntilStart(now: facts.now)
        switch nomination.state {
        case .archived:
            let date = (nomination.lastModifiedDate ?? nomination.submittedDate).map { $0.formatted(date: .abbreviated, time: .omitted) }
            self.init(
                text: date.map { String(localized: "Archived \($0) · read-only", comment: "kind:description") }
                    ?? String(localized: "Archived · read-only", comment: "kind:description"),
                tone: .quiet
            )
        case .submitted:
            if facts.queued.contains(.archive) {
                self.init(text: String(localized: "Archive waits in Review & Push", comment: "kind:description"), tone: .queued)
            } else if let request = facts.actionRequest {
                self.init(text: String(localized: "\(request.client) suggests archiving it", comment: "kind:description"), tone: .suggested)
            } else {
                self.init(text: String(localized: "Nothing needs you · Apple doesn’t report back", comment: "kind:description"), tone: .quiet)
            }
        case .draft:
            self = Self.draft(facts, days: days)
        }
    }

    private static func draft(_ facts: Facts, days: Int?) -> NominationNeed {
        let missing = facts.nomination.content.missing
        if facts.isRefused {
            return NominationNeed(text: String(localized: "Apple refused it: see why", comment: "kind:description"), tone: .warning)
        }
        if !missing.isEmpty {
            return NominationNeed(text: String(localized: "Add \(missing.formatted(.list(type: .and)))", comment: "kind:description"), tone: .warning)
        }
        if let days, days < 0 {
            return NominationNeed(text: String(localized: "Start date has passed: pick a new one", comment: "kind:description"), tone: .warning)
        }
        if facts.queued.contains(.submit) {
            return NominationNeed(text: String(localized: "Submit waits in Review & Push", comment: "kind:description"), tone: .queued)
        }
        if !facts.queued.isEmpty {
            if let client = facts.nomination.suggestedBy {
                return NominationNeed(text: String(localized: "Suggested by \(client) · waits in Review & Push", comment: "kind:description"), tone: .queued)
            }
            return NominationNeed(text: String(localized: "Waits in Review & Push", comment: "kind:description"), tone: .queued)
        }
        if let request = facts.actionRequest {
            return NominationNeed(text: String(localized: "\(request.client) suggests submitting it", comment: "kind:description"), tone: .suggested)
        }
        if let days, days < closeDays {
            return NominationNeed(
                text: String(localized: "Start date \(NominationDayText.relative(days)): Apple suggests a few weeks ahead", comment: "kind:description"),
                tone: .warning
            )
        }
        let ready = facts.nomination.isInAppStoreConnect
            ? String(localized: "Ready to submit", comment: "kind:description")
            : String(localized: "Ready to add to Review & Push", comment: "kind:description")
        return NominationNeed(text: ready, tone: .quiet)
    }
}
