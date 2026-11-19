//
//  EventArtworkOtherEvents.swift
//  Atlas
//

import Foundation

/// The ideas Claude already drew for the app's other events, so this
/// event's art looks like itself next to them on the App Store. On Alba
/// (2026-11-18) Gratitude Week and the New Year challenge, both Challenge
/// badges with the same first layout, each got "a path of lights climbing
/// to the sunrise", twice in a row. The brief has them, and so does each
/// answer to propose_event_artwork_concept while concepts are still to
/// come, since runs drawn at the same time read their briefs before the
/// others had sent anything.
enum EventArtworkOtherEvents {
    static let how = """
    Ideas already drawn for this app's other events. Make this event's concepts different ideas from them (another \
    subject, composition and moment), so each event looks like itself when they're side by side on the App Store; the \
    app's world, colors and craft stay the same.
    """

    /// `otherEvents`, or nil when no other event of the app has concepts.
    static func json(_ runs: [EventArtworkRun], except eventID: InAppEvent.ID) -> JSONValue? {
        let events: [JSONValue] = runs.filter { $0.eventID != eventID }.compactMap { run in
            let concepts = run.concepts.filter(\.isMadeByClaudeDesign)
            guard !concepts.isEmpty else { return nil }
            return [
                "event": .string(run.eventName),
                "concepts": .array(concepts.map { concept in
                    var object: [String: JSONValue] = ["name": .string(concept.name), "idea": .string(concept.why)]
                    if concept.id == run.usedConceptID { object["used"] = true }
                    return .object(object)
                }),
            ]
        }
        guard !events.isEmpty else { return nil }
        return ["how": .string(how), "events": .array(events)]
    }
}
