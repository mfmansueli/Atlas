//
//  ProposeEventSubmissionTool.swift
//  Atlas
//

import Foundation

/// `propose_event_submission`: suggests sending a ready In-App Event to
/// App Review on its own, without a new version. Checked like the event
/// page's Submit Event…: a draft or rejected event with everything App
/// Review needs and none of its changes still waiting in Review & Push.
/// It waits on the event's page; only the person submits, after the
/// confirmation.
struct ProposeEventSubmissionTool: MCPTool {
    var suggestions = InAppEventSubmitSuggestionStore.shared
    /// The clock the dates are checked against; tests pin it.
    var now: () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "propose_event_submission",
        title: "Suggest submitting an In-App Event",
        description: """
        Suggests sending an In-App Event to App Review on its own, without a new version: for a draft or rejected \
        event (get_in_app_events' state) whose card, details page, texts, deep link and dates are ready \
        (missingForReview empty) and whose changes in Review & Push are pushed. why says why now in one sentence (e.g. \
        “It starts in 5 days; App Review takes up to 2.”). Refused with what's missing otherwise, so propose those \
        first. It waits on the event's page; only the person submits it, after confirming. To send an event with the \
        next version instead, use propose_release_action's eventIds. withdraw: true takes it back.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("The event's id, from get_in_app_events."),
                "why": MCPToolDefinition.why("Why now, for the person."),
                "withdraw": ["type": "boolean", "description": "true: take back your suggestion for this event; nothing else is read."],
            ]),
            required: ["appId", "eventId"]
        ),
        proposalKind: .release
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let eventID = try arguments.string("eventId")
        let target = String(localized: "\(app.name) · In-App Events · submit", comment: "kind:other")
        guard context.allows(.release) else { return .refused(MCPProposalKind.release.refusal, target: target) }
        if try arguments.optionalBool("withdraw") == true {
            guard suggestions.suggestion(for: app.id, eventID: eventID)?.client == context.clientName else {
                return .refused(String(localized: "No submit suggestion of yours waits for this event.", comment: "kind:error"), target: target)
            }
            suggestions.remove(for: app.id, eventID: eventID)
            return MCPToolOutcome(result: ["status": "withdrawn"], isError: false, logLines: [.init(target: target, outcome: .proposed)])
        }
        let why = try arguments.string("why")
        let layers = try arguments.layers()
        let event = try await RenderEventArtworkTool.event(eventID, of: app, in: context)
        let pending = Self.pendingCount(of: event, app: app, queue: context.workspace.changes)
        if let reason = Self.refusal(for: event, pending: pending, now: now()) { return .refused(reason, target: target) }
        suggestions.suggest(InAppEventSubmitSuggestion(appID: app.id, eventID: event.id, why: why, client: context.clientName, layers: layers))
        let result: JSONValue = [
            "status": "suggested",
            "eventId": .string(event.id),
            "note": "It waits on the event's page; the person submits it with Submit Event… after confirming.",
        ]
        return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .proposed)])
    }

    /// The event's changes still waiting in Review & Push.
    static func pendingCount(of event: InAppEvent, app: StoreApp, queue: ChangeQueue) -> Int {
        let prefix = "\(InAppEventChangeBuilder(appID: app.id).idPrefix)\(event.id)."
        return queue.changes(for: app.id, section: .inAppEvents).count { $0.id.hasPrefix(prefix) }
    }

    /// Why the event can't go to App Review on its own now; nil when it can.
    static func refusal(for event: InAppEvent, pending: Int, now: Date) -> String? {
        let name = event.referenceName
        switch event.state {
        case .draft, .readyForReview, .rejected:
            break
        case .waitingForReview, .inReview, .accepted, .approved, .published:
            return String(localized: "“\(name)” is already with App Review or approved.", comment: "kind:error")
        case .past, .archived:
            return String(localized: "“\(name)” has ended. Propose a new event with propose_in_app_event.", comment: "kind:error")
        }
        let missing = event.missing(now: now)
        if !missing.isEmpty {
            return String(localized: """
            “\(name)” isn’t ready for App Review: \(missing.formatted(.list(type: .and))). Propose those first \
            (get_in_app_events’ missingForReview says how).
            """, comment: "kind:error")
        }
        if pending > 0 {
            return String(localized: "\(pending) changes to “\(name)” wait in Review & Push. The person pushes them first; suggest it after.", comment: "kind:error")
        }
        return nil
    }
}
