//
//  GetInAppEventsTool.swift
//  Atlas
//

import Foundation

/// `get_in_app_events`: an app's In-App Events with their texts and the
/// languages still missing, and the new events waiting in Review & Push
/// (`queued`), so an assistant proposes neither twice.
struct GetInAppEventsTool: MCPTool {
    var store = InAppEventsStore.shared

    let definition = MCPToolDefinition(
        name: "get_in_app_events",
        title: "Get In-App Events",
        description: """
        Reads an app's In-App Events from App Store Connect: each with its id, reference name, badge, state, dates, primary \
        language, deep link, purchase requirement, and its texts per language (name ≤30 characters, shortDescription ≤50, \
        longDescription ≤120). `missingLanguages` are the store page's languages the event isn't written in yet (people \
        there see the primary language); `suggestedLanguages` already have a suggestion waiting. Only events with \
        `editable: true` take new texts. `media` says, per language, whether it has its own card (16:9) and details page \
        (9:16), as an image or a video, or shows the primary language's; `stillMissing` lists what no language shows yet \
        (both are needed to submit the event) and the languages without their own; `queuedArtwork` is art waiting in Review \
        & Push. `queued` are the new events waiting in Review & Push, not created yet: their reference names are taken \
        too. `artworkUpload` is this launch's link for sending a card or details page file made elsewhere (POST the bytes, \
        `?name=` the file name). Read-only. Follow with propose_event_texts for the missing languages, \
        render_event_artwork and propose_event_artwork for the art, or propose_in_app_event for a new event.
        """,
        inputSchema: MCPToolDefinition.schema(
            ["appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps.")],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let services = context.workspace.services
        let events = try await services.inAppEvents.events(for: app)
        let pageLocales = await (try? services.storePage.summary(for: app))?.localeCodes ?? []
        let builder = InAppEventChangeBuilder(appID: app.id)
        let changes = context.workspace.changes.changes(for: app.id, section: .inAppEvents)
        let queued = builder.queuedNewEvents(in: changes)
        let result: JSONValue = [
            "appId": .string(app.id),
            "app": .string(app.name),
            "limits": [
                "name": 30, "shortDescription": 50, "longDescription": 120, "referenceName": .int(NewInAppEvent.referenceNameLimit),
                "longestEventDays": 31, "cardShowsDaysBeforeStart": 14,
            ],
            "storePageLanguages": .array(pageLocales.map(JSONValue.string)),
            "events": .array(events.map { event in
                var object = Self.json(event, pageLocales: pageLocales, suggested: store.open(for: app.id, eventID: event.id))
                object.merge(Self.media(event, queued: builder.queuedArtwork(for: event.id, in: changes))) { $1 }
                return .object(object)
            }),
            "queued": .array(queued.map(Self.queued)),
            "artworkUpload": .string(RenderEventArtworkTool.uploadLink(app: app, port: context.port)),
        ]
        return .read(result, target: "\(app.name) · In-App Events")
    }

    private static func json(_ event: InAppEvent, pageLocales: [String], suggested: [InAppEventTextSuggestion]) -> [String: JSONValue] {
        var texts: [String: JSONValue] = [:]
        for localization in event.localizations {
            texts[localization.locale] = [
                "name": .string(localization.name),
                "shortDescription": .string(localization.shortDescription),
                "longDescription": .string(localization.longDescription),
            ]
        }
        let written = Set(event.localizations.filter(\.isComplete).map(\.locale))
        let suggestedLocales = Set(suggested.map(\.locale))
        let missing = event.state.isEditable ? pageLocales.filter { !written.contains($0) && !suggestedLocales.contains($0) } : []
        var object: [String: JSONValue] = [
            "id": .string(event.id),
            "referenceName": .string(event.referenceName),
            "state": .string(event.state.rawValue),
            "editable": .bool(event.state.isEditable),
            "texts": .object(texts),
            "missingLanguages": .array(missing.map(JSONValue.string)),
            "suggestedLanguages": .array(suggestedLocales.sorted().map(JSONValue.string)),
        ]
        if let badge = event.badge { object["badge"] = .string(badge.rawValue) }
        if let primary = event.primaryLocale { object["primaryLanguage"] = .string(primary) }
        if let deepLink = event.deepLink, !deepLink.isEmpty { object["deepLink"] = .string(deepLink) }
        if let purchase = event.purchaseRequirement { object["purchaseRequirement"] = .string(purchase.rawValue) }
        if let publish = event.schedule?.publishStart { object["showsFrom"] = .string(publish.formatted(.iso8601)) }
        if let start = event.schedule?.eventStart { object["starts"] = .string(start.formatted(.iso8601)) }
        if let end = event.schedule?.eventEnd { object["ends"] = .string(end.formatted(.iso8601)) }
        return object
    }

    /// Each language's card and details page, what's still missing, and
    /// the art waiting in Review & Push. Past events' media are read for
    /// the primary language only, archived ones' not at all.
    static func media(_ event: InAppEvent, queued: [InAppEventQueuedArtwork]) -> [String: JSONValue] {
        guard event.state != .archived else { return ["media": "not read for archived events"] }
        let state = InAppEventMediaState(event: event)
        var object: [String: JSONValue] = [
            "media": .object(Dictionary(uniqueKeysWithValues: state.languages.map { language in
                (language.locale, JSONValue.object(Dictionary(uniqueKeysWithValues: InAppEventMedia.Kind.allCases.map { kind in
                    (kind.mcpValue, JSONValue.string(language.text(kind)))
                })))
            })),
            "stillMissing": .object(state.missingJSON),
        ]
        if event.state.isOver { object["mediaNote"] = "Only the primary language's media are read for an event that's over." }
        if !queued.isEmpty {
            object["queuedArtwork"] = .array(queued.map { item in
                [
                    "changeId": .string(item.changeID), "kind": .string(item.kind.mcpValue), "locale": .string(item.locale),
                    "file": .string(item.push.fileName), "isVideo": .bool(item.push.isVideo),
                    "waitingForAcceptance": .bool(item.isAwaitingAcceptance), "by": .string(item.source.title),
                ]
            })
        }
        return object
    }

    /// A new event waiting in Review & Push, as it was proposed.
    private static func queued(_ change: PendingChange) -> JSONValue {
        var object: [String: JSONValue] = [
            "changeId": .string(change.id),
            "title": .string(change.title),
            "by": .string(change.source.title),
        ]
        if let blocked = change.blockedReason { object["blockedReason"] = .string(blocked) }
        guard let event = InAppEventChangeBuilder.newEvent(in: change) else { return .object(object) }
        var texts: [String: JSONValue] = [:]
        for (locale, fields) in event.texts {
            texts[locale] = .object(Dictionary(uniqueKeysWithValues: fields.map { ($0.key.rawValue, JSONValue.string($0.value)) }))
        }
        object.merge([
            "referenceName": .string(event.trimmedReferenceName),
            "badge": .string(event.badge.rawValue),
            "purpose": .string(event.purpose.rawValue),
            "priority": .string(event.priority.rawValue),
            "purchaseRequirement": .string(event.purchaseRequirement.rawValue),
            "primaryLanguage": .string(event.primaryLocale),
            "showsFrom": .string(event.publishStart.formatted(.iso8601)),
            "starts": .string(event.eventStart.formatted(.iso8601)),
            "ends": .string(event.eventEnd.formatted(.iso8601)),
            "territories": event.territories.isEmpty ? "all" : .array(event.territories.map(JSONValue.string)),
            "texts": .object(texts),
        ]) { $1 }
        if !event.trimmedDeepLink.isEmpty { object["deepLink"] = .string(event.trimmedDeepLink) }
        return .object(object)
    }
}
