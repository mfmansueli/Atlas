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
    /// Where the app's design project is kept (Connect a Design Project).
    var autopilot = AutopilotCenter.shared
    /// Where the art files are kept, to know App Store Connect's media by
    /// the file Atlas uploaded; tests use their own folder.
    var directory = InAppEventArtworkFiles.directory

    let definition = MCPToolDefinition(
        name: "get_in_app_events",
        title: "Get In-App Events",
        description: """
        Reads an app's In-App Events from App Store Connect: each with its id, reference name, badge, state, dates, primary \
        language, deep link, purchase requirement, and its texts per language (name ≤30 characters, shortDescription ≤50, \
        longDescription ≤120). `missingLanguages` are the store page's languages the event isn't written in yet (people \
        there see the primary language), less those with a suggestion waiting (`suggestedLanguages`; `openSuggestions` \
        has each with its texts, who sent it (`by`) and `stale` when App Store Connect has that language written since, \
        `staleSuggestions` their languages: withdraw your own with withdraw_event_texts) or texts waiting in \
        Review & Push (`queuedTexts`: per language, its changeId(s), newLanguage when the push creates it, \
        waitingForAcceptance, by, and the queued name, shortDescription and longDescription). Only events with \
        `editable: true` take new texts. `media` says, per language, whether it has its own card (16:9) and details page \
        (9:16), as an image or a video, or shows the primary language's; `mediaDetails` has the same per language and \
        kind as App Store Connect gives it (fileName, fileSize, isVideo, width, height, previewFrameTimeCode, imageUrl, \
        state, shownFrom when it's the primary language's), with `atlasFile` when it was uploaded from a file Atlas \
        still has, `matchesQueued` the queued changes sending that same file, and `sameAsPrimary` on a language's own \
        copy of the primary's; `stillMissing` lists what no language shows yet \
        (both are needed to submit the event) and the languages without their own; `queuedArtwork` is art waiting in Review \
        & Push, each with the file Atlas will send: `path` on this Mac (open it to see exactly what goes), `fileSize`, \
        `width`/`height`, a video's `seconds` and `previewFrameTimeCode`, `fileExists`, `languageCreatedByPush` when \
        its language is created by the same push, the file's `originalName`, `sha256` and `origin` (from: makeTheArtwork \
        with conceptId and title, render_event_artwork with page, upload or imageBase64 with name, chooseFiles), \
        `sameAsPrimary` when it's the primary language's art again (with `copyNeeded` false where the language shows \
        the primary's without it: those are in `identicalCopies` for the person to take out), \
        `alreadyInAppStoreConnect` when that language has this file already, and `pushStatus` while a push has it. \
        `queuedArtworkSummary` groups the queued art by kind and file with its languages. `pushInProgress` is true while \
        Review & Push is pushing; `pushChanges` are this app's In-App Event changes in that push (or the one just \
        finished) with their status: queued, sending (progress), done, failed (reason), conflict or notSent (reason). \
        `queued` are the new events waiting in Review & Push, not created yet: their reference names are taken \
        too. `artworkUpload` is this launch's link for sending a card or details page file made elsewhere (POST the bytes, \
        `?name=` the file name). `design` is what the art is designed from: the app's look and design language, what Atlas \
        knows of the app, its design project if one is connected, and `how` to make each piece as an HTML page \
        Atlas renders, still or as a seamless loop. Read-only. Follow with propose_event_texts for the missing languages, \
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
        let allArt = events.flatMap { builder.queuedArtwork(for: $0.id, in: changes) }
        let files = await Self.files(of: allArt)
        let reading = MediaReading(
            files: files, infos: InAppEventArtworkFiles.infos(atPaths: allArt.map(\.push.path)),
            stored: InAppEventArtworkFiles.stored(appID: app.id, in: directory)
        )
        let push = context.workspace.push()
        let pushItems = push?.items(appID: app.id, section: .inAppEvents) ?? []
        let result: JSONValue = [
            "appId": .string(app.id),
            "app": .string(app.name),
            "limits": [
                "name": 30, "shortDescription": 50, "longDescription": 120, "referenceName": .int(NewInAppEvent.referenceNameLimit),
                "longestEventDays": 31, "cardShowsDaysBeforeStart": 14,
            ],
            "storePageLanguages": .array(pageLocales.map(JSONValue.string)),
            "textRules": StoreTextGuidelinePlace.eventText.rulesJSON,
            "events": .array(events.map { event in
                let texts = builder.queuedTexts(for: event.id, in: changes)
                let suggestions = store.open(for: app.id, eventID: event.id)
                var object = Self.json(event, pageLocales: pageLocales, suggested: suggestions, queued: texts, push: pushItems)
                object.merge(Self.suggestionsJSON(suggestions, of: event)) { $1 }
                object.merge(Self.media(event, queued: builder.queuedArtwork(for: event.id, in: changes), reading: reading, push: pushItems)) { $1 }
                return .object(object)
            }),
            "pushInProgress": .bool(push?.isRunning ?? false),
            "pushChanges": .array(pushItems.map(\.json)),
            "queued": .array(queued.map(Self.queued)),
            "artworkUpload": .string(RenderEventArtworkTool.uploadLink(app: app, port: context.port)),
            "design": InAppEventDesignFacts.json(
                look: services.storePage.appSupport?.profile(for: app.id)?.look,
                knowledge: services.storePage.appSupport?.knowledge(for: app.id),
                project: autopilot.designProject(for: app.id)
            ),
        ]
        return .read(result, target: "\(app.name) · In-App Events")
    }

    static func json(
        _ event: InAppEvent, pageLocales: [String], suggested: [InAppEventTextSuggestion], queued: [InAppEventQueuedTexts] = [],
        push: [MCPPushSnapshot.Item] = []
    ) -> [String: JSONValue] {
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
        // Texts waiting in Review & Push that complete a language count as written.
        let queuedLocales = Set(queued.filter { $0.completes(event.localization($0.locale)) }.map(\.locale))
        let missing = event.state.isEditable
            ? pageLocales.filter { !written.contains($0) && !suggestedLocales.contains($0) && !queuedLocales.contains($0) }
            : []
        var object: [String: JSONValue] = [
            "id": .string(event.id),
            "referenceName": .string(event.referenceName),
            "state": .string(event.state.rawValue),
            "editable": .bool(event.state.isEditable),
            "texts": .object(texts),
            "missingLanguages": .array(missing.map(JSONValue.string)),
            "suggestedLanguages": .array(suggestedLocales.sorted().map(JSONValue.string)),
        ]
        if !queued.isEmpty { object["queuedTexts"] = Self.queuedTextsJSON(queued, push: push) }
        if let badge = event.badge { object["badge"] = .string(badge.rawValue) }
        if let primary = event.primaryLocale { object["primaryLanguage"] = .string(primary) }
        if let deepLink = event.deepLink, !deepLink.isEmpty { object["deepLink"] = .string(deepLink) }
        if let purchase = event.purchaseRequirement { object["purchaseRequirement"] = .string(purchase.rawValue) }
        if let publish = event.schedule?.publishStart { object["showsFrom"] = .string(publish.formatted(.iso8601)) }
        if let start = event.schedule?.eventStart { object["starts"] = .string(start.formatted(.iso8601)) }
        if let end = event.schedule?.eventEnd { object["ends"] = .string(end.formatted(.iso8601)) }
        return object
    }

    /// What was read of the queued art's files and the files Atlas keeps
    /// for the app, once for every event.
    struct MediaReading {
        /// The queued files as read, by path.
        var files: [String: InAppEventArtworkFile] = [:]
        /// Their infos (original name, SHA-256, origin), by path.
        var infos: [String: InAppEventArtworkFileInfo] = [:]
        /// Every file kept for the app, to know App Store Connect's media.
        var stored: [InAppEventArtworkStoredFile] = []
    }

    /// Each language's card and details page, what's still missing, and
    /// the art waiting in Review & Push. Past events' media are read for
    /// the primary language only, archived ones' not at all.
    static func media(
        _ event: InAppEvent, queued: [InAppEventQueuedArtwork], reading: MediaReading = MediaReading(), push: [MCPPushSnapshot.Item] = []
    ) -> [String: JSONValue] {
        guard event.state != .archived else { return ["media": "not read for archived events"] }
        let state = InAppEventMediaState(event: event)
        let copies = InAppEventArtworkCopies(event: event, queued: queued, infos: reading.infos, stored: reading.stored)
        var object: [String: JSONValue] = [
            "media": .object(Dictionary(uniqueKeysWithValues: state.languages.map { language in
                (language.locale, JSONValue.object(Dictionary(uniqueKeysWithValues: InAppEventMedia.Kind.allCases.map { kind in
                    (kind.mcpValue, JSONValue.string(language.text(kind)))
                })))
            })),
            "mediaDetails": mediaDetailsJSON(state, queued: queued, reading: reading),
            "stillMissing": .object(state.missingJSON),
        ]
        if event.state.isOver { object["mediaNote"] = "Only the primary language's media are read for an event that's over." }
        if !queued.isEmpty {
            let locales = Set(event.localizations.map(\.locale))
            object["queuedArtwork"] = .array(queued.map { item in
                queuedArtworkJSON(
                    item, file: reading.files[item.push.path], languageExists: locales.contains(item.locale), info: reading.infos[item.push.path],
                    copies: copies, stored: reading.stored, push: push.first { $0.changeID == item.changeID }
                )
            })
            object["queuedArtworkSummary"] = queuedArtworkSummaryJSON(queued, infos: reading.infos)
            let unneeded = copies.unneededCopies(in: queued, infos: reading.infos)
            if !unneeded.isEmpty {
                object["identicalCopies"] = [
                    "changeIds": .array(unneeded.map { .string($0.changeID) }),
                    "note": """
                    These upload the primary language's art again into languages that show it without them (Apple's \
                    fallback). Nothing is taken out by itself: the person can remove them in Review & Push.
                    """,
                ]
            }
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
