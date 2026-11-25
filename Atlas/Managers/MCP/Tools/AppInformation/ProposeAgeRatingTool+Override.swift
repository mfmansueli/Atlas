//
//  ProposeAgeRatingTool+Override.swift
//  Atlas
//

import Foundation

// `propose_age_rating`'s override: "Rate higher than calculated" with a
// rating above what the answers add up to and the reason, as the Age
// Rating page sets it (the reason stays on this Mac, since App Store
// Connect has no field for it). It waits until the person accepts it.
extension ProposeAgeRatingTool {
    struct OverrideOutcome {
        var result: JSONValue
        var logLine: MCPToolOutcome.LogLine
    }

    func proposeOverride(
        _ object: [String: JSONValue],
        app: StoreApp,
        content: AppInformationContent,
        builder: AppInformationChangeBuilder,
        notes: inout AppInformationNotes,
        context: MCPToolContext
    ) -> OverrideOutcome {
        let target = String(localized: "\(app.name) · Age Rating · Rate higher than calculated")
        let values = builder.ageRating(content.ageRating, with: context.workspace.changes.changes(for: app.id, section: .appInformation))
        let text = (object["rating"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let reason = (object["reason"]?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = AgeRating.overrides(above: values.preview.calculated)
        let rating: AgeRating?
        if text.lowercased() == "off" || text.lowercased() == "none" {
            rating = nil
        } else if let match = allowed.first(where: { $0.title == text || $0.apiValue == text.uppercased() }) {
            rating = match
        } else {
            let list = (allowed.map(\.title) + ["off"]).formatted(.list(type: .or))
            return refused(String(localized: "The answers add up to \(values.preview.calculated.title), so the override is \(list)."), target: target)
        }
        if rating != nil, reason.isEmpty {
            return refused(String(localized: "Say why the app should be rated higher: send override.reason."), target: target)
        }
        if let problem = AssistantTextLimits.whyRefusal(reason, field: "override.reason") { return refused(problem, target: target) }
        guard var change = builder.overrideChange(from: content.ageRating, to: rating, reason: reason, source: context.source) else {
            return OverrideOutcome(result: ["question": "override", "status": "unchanged"], logLine: .init(target: target, outcome: .read))
        }
        change.awaitingAcceptance = String(localized: "Look at it, then accept it on the Age Rating page or here.")
        context.workspace.changes.upsert(change)
        if rating != nil { notes.overrideReason = reason }
        return OverrideOutcome(
            result: ["question": "override", "status": "queued", "changeId": .string(change.id)],
            logLine: .init(target: target, outcome: .proposed)
        )
    }

    private func refused(_ reason: String, target: String) -> OverrideOutcome {
        OverrideOutcome(
            result: ["question": "override", "status": "refused", "reason": .string(reason)],
            logLine: .init(target: target, outcome: .refused, reason: reason)
        )
    }
}
