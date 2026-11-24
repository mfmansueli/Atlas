//
//  NominationContent.swift
//  Atlas
//

import Foundation

/// What a nomination tells Apple's editors: everything `POST` and `PATCH
/// /v1/nominations` send. Apple publishes no character limits, so none are
/// checked here; a refusal shows Apple's own reason.
struct NominationContent: Hashable, Codable, Sendable {
    var name = ""
    var type: NominationType?
    var description = ""
    /// The first day it's on the App Store (required).
    var publishStart: Date?
    /// The last day, if it ends.
    var publishEnd: Date?
    var devices: [NominationDevice] = []
    /// App Store Connect locale codes, e.g. `en-US`.
    var locales: [String] = []
    /// App Store Connect territory IDs (`USA`…); empty is every country or
    /// region.
    var territories: [String] = []
    var launchInSelectMarketsFirst = false
    var preOrderEnabled = false
    /// The linked In-App Events' IDs.
    var eventIDs: [String] = []
    /// Links to a video, deck or mockups: Apple takes links, not files.
    var materials: [String] = []
    var notes = ""
    /// The account's apps it covers; the open app always among them.
    var appIDs: [String] = []

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedDescription: String { description.trimmingCharacters(in: .whitespacesAndNewlines) }
    var trimmedNotes: String { notes.trimmingCharacters(in: .whitespacesAndNewlines) }

    var isEverywhere: Bool { territories.isEmpty }

    /// What's missing before it can go to App Store Connect, in the
    /// nomination's order: "a type", "a name"…
    var missing: [String] {
        var missing: [String] = []
        if type == nil { missing.append(String(localized: "a type", comment: "kind:other")) }
        if trimmedName.isEmpty { missing.append(String(localized: "a name", comment: "kind:other")) }
        if trimmedDescription.isEmpty { missing.append(String(localized: "a description", comment: "kind:other")) }
        if publishStart == nil { missing.append(String(localized: "a start date", comment: "kind:other")) }
        if appIDs.isEmpty { missing.append(String(localized: "an app", comment: "kind:other")) }
        return missing
    }

    /// Whole days from `now` to the start, in this Mac's calendar; nil
    /// without a start date.
    func daysUntilStart(now: Date, calendar: Calendar = .current) -> Int? {
        guard let publishStart else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: publishStart)).day
    }

    func startHasPassed(now: Date, calendar: Calendar = .current) -> Bool {
        (daysUntilStart(now: now, calendar: calendar) ?? 0) < 0
    }

    /// Why it can't go to App Store Connect, each saying how to fix it;
    /// empty when it can. Used by the page's buttons and by
    /// `propose_nomination`'s refusal.
    func problems(now: Date, calendar: Calendar = .current) -> [String] {
        var problems: [String] = []
        let missing = missing
        if !missing.isEmpty {
            problems.append(String(localized: "Add \(missing.formatted(.list(type: .and))).", comment: "kind:error"))
        }
        if startHasPassed(now: now, calendar: calendar) {
            problems.append(String(localized: "The start date has passed. Pick one that hasn’t.", comment: "kind:error"))
        }
        if let publishStart, let publishEnd, publishEnd < publishStart {
            problems.append(String(localized: "The end date is before the start date.", comment: "kind:error"))
        }
        for link in materials where !NominationLink.isValid(link) {
            problems.append(String(localized: "“\(link)” isn’t a full link. Use one that starts with https://.", comment: "kind:error"))
        }
        return problems
    }

    /// The fields that differ from `other`, in the nomination's order.
    func changedFields(from other: NominationContent) -> [NominationField] {
        let differs: [(NominationField, Bool)] = [
            (.type, type != other.type),
            (.name, trimmedName != other.trimmedName),
            (.description, trimmedDescription != other.trimmedDescription),
            (.dates, publishStart != other.publishStart || publishEnd != other.publishEnd),
            (.devices, Set(devices) != Set(other.devices)),
            (.languages, Set(locales) != Set(other.locales)),
            (.countries, Set(territories) != Set(other.territories) || launchInSelectMarketsFirst != other.launchInSelectMarketsFirst),
            (.preOrder, preOrderEnabled != other.preOrderEnabled),
            (.events, eventIDs != other.eventIDs),
            (.materials, materials != other.materials),
            (.notes, trimmedNotes != other.trimmedNotes),
            (.apps, Set(appIDs) != Set(other.appIDs)),
        ]
        return differs.filter(\.1).map(\.0)
    }
}
