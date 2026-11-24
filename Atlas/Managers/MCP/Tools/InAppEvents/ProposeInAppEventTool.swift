//
//  ProposeInAppEventTool.swift
//  Atlas
//

import Foundation

/// `propose_in_app_event`: an assistant's new In-App Event, checked like
/// the New Event sheet's and queued in Review & Push as the same change,
/// "Create “New Year Challenge 2027”". The push creates it as a draft with
/// its texts; its card and details page images are added in App Store
/// Connect, and the person submits it for review. Nothing here pushes or
/// submits.
struct ProposeInAppEventTool: MCPTool {
    /// The clock the event's start is checked against; tests pin it.
    var now: () -> Date = { .now }

    /// The arguments, typed apart so the definition type-checks quickly.
    private static let properties: [String: JSONValue] = MCPToolDefinition.withLayers([
        "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
        "referenceName": MCPToolDefinition.string("The event's name in App Store Connect, unique among the app's events; people never see it (≤64)."),
        "badge": enumeration(InAppEventBadge.allCases.map(\.rawValue), "What kind of event it is; the card shows it above the name."),
        "purpose": enumeration(InAppEventPurpose.allCases.map(\.rawValue), "Who it's for; APPROPRIATE_FOR_ALL_USERS when left out."),
        "priority": enumeration(InAppEventPriority.allCases.map(\.rawValue), "HIGH shows it before the app's NORMAL events; NORMAL when left out."),
        "purchaseRequirement": enumeration(
            InAppEventPurchaseRequirement.allCases.map(\.rawValue),
            "IN_APP_PURCHASE only when taking part costs extra (in a subscription app, beyond the subscription); NO_COST_ASSOCIATED when left out."
        ),
        "deepLink": MCPToolDefinition.string("""
        The universal link (https://…) or app URL (myapp://event) that Open on the card goes to. The draft can be created \
        without one, but App Store Connect won't take it to App Review until it has one (propose_event_details sets it \
        later). Check in the project that the app opens it, and report it with report_deep_link_check.
        """),
        "primaryLocale": MCPToolDefinition.string("The event's primary language, e.g. en-US; the app's when left out."),
        "publishStart": MCPToolDefinition.string("When the card starts showing, ISO 8601 with a time zone: at most 14 days before eventStart."),
        "eventStart": MCPToolDefinition.string("When the event starts, ISO 8601 with a time zone, e.g. 2027-01-01T00:00:00Z: in the future."),
        "eventEnd": MCPToolDefinition.string("When it ends, ISO 8601 with a time zone: 15 minutes to 31 days after eventStart."),
        "territories": [
            "type": "array", "items": ["type": "string"],
            "description": "Optional App Store Connect territory codes (USA, BRA…); every country or region when left out.",
        ],
        "texts": [
            "type": "object",
            "description": "By locale: {\"en-US\": {name (≤30), shortDescription (≤50), longDescription (≤120)}}, all three in each language.",
            "additionalProperties": [
                "type": "object",
                "properties": ["name": ["type": "string"], "shortDescription": ["type": "string"], "longDescription": ["type": "string"]],
            ],
        ],
        "reason": MCPToolDefinition.why("Why this event, for the person to read before pushing."),
        "evidence": [
            "type": "array", "items": ["type": "string"],
            "description": "Where it comes from, e.g. Alba/Streaks/StreakChallenge.swift:14 — the January streak challenge.",
        ],
    ])

    private static func enumeration(_ values: [String], _ description: String) -> JSONValue {
        ["type": "string", "enum": .array(values.map(JSONValue.string)), "description": .string(description)]
    }

    let definition = MCPToolDefinition(
        name: "propose_in_app_event",
        title: "Propose In-App Event",
        description: """
        Proposes a new In-App Event for an app, queued in Atlas's Review & Push as “Create “<referenceName>”” for \
        the person to review. Read get_in_app_events first: reference names are unique, so leave the ones its events and \
        `queued` events have. badge is LIVE_EVENT, PREMIERE, CHALLENGE, COMPETITION, NEW_SEASON, MAJOR_UPDATE or \
        SPECIAL_EVENT; purpose APPROPRIATE_FOR_ALL_USERS (default), ATTRACT_NEW_USERS, KEEP_ACTIVE_USERS_INFORMED or \
        BRING_BACK_LAPSED_USERS; priority NORMAL (default) or HIGH; purchaseRequirement NO_COST_ASSOCIATED (default) or \
        IN_APP_PURCHASE. publishStart, eventStart and eventEnd are ISO 8601 dates and times with a time zone: the event \
        starts in the future and lasts 15 minutes to 31 days, and its card shows in the future, at most 14 days before it \
        starts. App Review usually takes up to 2 days and the event shows only once it's approved, so a card or start \
        within 2 days comes back with a `warning` (not a refusal): leave App Review time. texts \
        are by locale, name ≤30, shortDescription ≤50 and longDescription ≤120, all three per language: usually the \
        primary language; write the others with propose_event_texts once the event is created. Anything App Store \
        Connect would refuse is refused with the reasons (status "refused"); proposing your own queued reference name \
        again replaces it. Give deepLink (where Open on the card goes) when you know it: the event is created without \
        one, but App Store Connect won't take it to App Review until it has one (set it later with \
        propose_event_details). Nothing reaches App Store Connect until the person pushes, and the person adds the card and \
        details page images and submits the event for review: no tool does either. \
        \(StoreTextGuidelinePlace.eventText.summary)
        """,
        inputSchema: MCPToolDefinition.schema(
            Self.properties,
            required: ["appId", "referenceName", "badge", "publishStart", "eventStart", "eventEnd", "texts", "reason"]
        ),
        proposalKind: .storeText
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let proposal = try Self.proposal(from: arguments, app: app)
        let event = proposal.event
        let target = "\(app.name) · \(event.trimmedReferenceName)"
        guard context.allows(.storeText) else { return .refused(MCPProposalKind.storeText.refusal, target: target) }
        let reason = try arguments.string("reason")
        let evidence = try arguments.optionalStrings("evidence") ?? []
        let layers = try arguments.layers()

        let events = try await context.workspace.services.inAppEvents.events(for: app)
        let builder = InAppEventChangeBuilder(appID: app.id)
        let queue = context.workspace.changes
        let changes = queue.changes(for: app.id, section: .inAppEvents)
        // The assistant's own queued event with this name is replaced; anyone else's is left to them.
        let replaced = builder.queuedNewEvent(named: event.referenceName, in: changes).flatMap { $0.source == context.source ? $0 : nil }
        let taken = builder.takenReferenceNames(events: events, changes: changes, except: replaced?.id)
        let reasons = event.problems(now: now(), takenReferenceNames: taken) + proposal.problems
        guard reasons.isEmpty else {
            let result: JSONValue = [
                "status": "refused", "referenceName": .string(event.trimmedReferenceName), "reasons": .array(reasons.map { .string($0) }),
            ]
            return MCPToolOutcome(result: result, isError: false, logLines: [.init(target: target, outcome: .refused, reason: reasons.joined(separator: " "))])
        }
        let token = replaced.map { String($0.id.dropFirst(builder.newEventChangeID(token: "").count)) } ?? UUID().uuidString.lowercased()
        guard let change = builder.newEventChange(event, token: token, source: context.source, reason: reason, evidence: evidence) else {
            return .failed(String(localized: "Atlas couldn’t write this event’s request. Check its texts and send it again."), target: target)
        }
        queue.upsert(change)
        queue.attach(layers, to: change.id)
        let result = Self.queuedResult(change, event: event, replaced: replaced != nil, warnings: event.warnings(now: now()))
        return MCPToolOutcome(result: result, isError: false, logLines: [
            .init(target: target, outcome: .proposed),
        ])
    }

    private static func queuedResult(_ change: PendingChange, event: NewInAppEvent, replaced: Bool, warnings: [String]) -> JSONValue {
        var stillNeeded: [JSONValue] = [
            "The event card image or video (16:9, 1920×1080 to 3840×2160), added in App Store Connect.",
            "The details page image or video (9:16, 1080×1920 to 2160×3840), added in App Store Connect.",
        ]
        if event.trimmedDeepLink.isEmpty {
            let deepLink: JSONValue = """
            A deep link: App Store Connect won't take the event to App Review without one. Set it with \
            propose_event_details once the event is created.
            """
            stillNeeded.insert(deepLink, at: 0)
        }
        var result: [String: JSONValue] = [
            "status": "queued",
            "changeId": .string(change.id),
            "referenceName": .string(event.trimmedReferenceName),
            "replacedYourEarlierProposal": .bool(replaced),
            "showsIn": .string("Review & Push → In-App Events · New, as \(change.title)"),
            "stillNeeded": .array(stillNeeded),
            "note": """
            Nothing is created until the person pushes; then App Store Connect gets the event as a draft with these texts. \
            Its event card and details page artwork still have to be added in App Store Connect, and the person pushes the \
            event and submits it for review themselves: there's no tool for either. Once it's created, get_in_app_events \
            lists it, and propose_event_texts writes its other languages.
            """,
        ]
        // App Review's time: it never blocks.
        if !warnings.isEmpty { result["warning"] = .string(warnings.joined(separator: " ")) }
        return .object(result)
    }
}
