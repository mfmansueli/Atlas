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
    /// What the app's project claims, as Atlas last read its folder.
    var linkClaims = ProjectLinkClaimsCenter.shared
    /// The clock an event's dates are checked against; tests pin it.
    var now: () -> Date = { .now }

    let definition = MCPToolDefinition(
        name: "get_in_app_events",
        title: "Get In-App Events",
        description: """
        Reads an app's In-App Events from App Store Connect, all of them or one (`eventId`), with the parts you ask \
        for (`include`: texts, media, mediaDetails, review, deepLinkCheck, design, push, queued, or all). Without \
        include, every part but the two heaviest, mediaDetails and design: `leftOut` names them, ask for them when you \
        need them (with eventId to keep the answer small). Each event comes with its id, reference name, badge, state, dates, \
        primaryLocale, deepLink, purpose and priority (null when App Store Connect has none), purchase requirement, and its \
        texts per language (name ≤30 characters, shortDescription ≤50, \
        longDescription ≤120). `missingLanguages` are the store page's languages the event isn't written in yet (people \
        there see the primary language), less those with a suggestion waiting (`suggestedLanguages`; `openSuggestions` \
        has each with its texts, who sent it (`by`; a revision of a written language has `revision: true` and \
        `revises`, only the texts it changes). Reading settles the suggestions as In-App Events does: one whose \
        texts App Store Connect has already is done and leaves, and a new language's texts sent before that language \
        was written become a revision of the texts that differ, its why starting "Suggested before this language was \
        written:"; `stale` and `staleSuggestions` name any left that would add nothing (withdraw your own with \
        withdraw_event_texts) or texts waiting in \
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
        Atlas renders, still or as a seamless loop. `missingForReview` lists what App Store Connect still needs before it \
        takes the event to App Review (deepLink, primaryLocale, purpose, dates, primaryTexts, languageTexts, card, details, \
        linkNotClaimed), each `missing`, `queued` in Review & Push or `suggested` (waiting for the person to accept it), \
        with `readyForReview`; `queuedDetails` are the deep link, purpose, priority and primary language changes waiting; \
        `deepLinkClaim` says whether the app's project (its folder in Atlas) declares the deep link's URL scheme or \
        applinks domain; `deepLinkCheck` is the last report_deep_link_check for the deep link the event will have (null \
        when not checked), `stale: true` with `staleReason` once the event's start or end moved since it was made \
        (`checkedDates`): check it again. Dates (showsFrom, starts, ends) are as App Store Connect has them, checked at the time you read: \
        missingForReview also lists a date App Store Connect would refuse (publishStartPassed and eventStartPassed: it \
        only takes dates in the future; eventEndBeforeStart, eventTooShort, eventTooLong, publishStartAfterEventStart, \
        publishStartTooEarly), each with `fix` and, for the card's date, `suggested` (a publishStart that works, ISO 8601); \
        `reviewWarnings` say when App Review (up to 2 days; the event shows only once it's approved) may not approve it \
        before its card shows (cardShowsSoon) or it starts (eventStartsSoon): they never block. `queuedDates` are dates \
        waiting in Review & Push (`by` who queued them; `suggestion` an assistant's dates waiting beside the person's, \
        to accept or dismiss); `datesEditable` says whether propose_event_details can change them (else \
        `datesNotEditable` says why). Read-only. Follow with propose_event_texts for the missing languages, \
        render_event_artwork and propose_event_artwork for the art, propose_event_details for a missing deep link, purpose \
        or primary language or dates to fix, or propose_in_app_event for a new event.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "eventId": MCPToolDefinition.string("One event's id, to read only that one."),
                "include": [
                    "type": "array",
                    "items": ["type": "string", "enum": .array(GetInAppEventsPart.names.map(JSONValue.string))],
                    "description": """
                    The parts to read: texts, media, mediaDetails, review, deepLinkCheck, design, push, queued, or all. Left out, \
                    every part but mediaDetails and design.
                    """,
                ],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let app = try await context.workspace.app(matching: arguments.string("appId"))
        let parts = try GetInAppEventsPart.parts(arguments.optionalStrings("include"))
        let services = context.workspace.services
        let only = try arguments.optionalString("eventId")
        let read = try await services.inAppEvents.events(for: app)
        // Settled as when In-App Events reads them, so `openSuggestions`
        // is what the section shows and counts.
        store.noteRead(read, for: app.id)
        let events = try Self.events(read, only: only, of: app)
        let pageLocales = await (try? services.storePage.summary(for: app))?.localeCodes ?? []
        let builder = InAppEventChangeBuilder(appID: app.id)
        let changes = context.workspace.changes.changes(for: app.id, section: .inAppEvents)
        let queued = builder.queuedNewEvents(in: changes)
        let allArt = parts.contains(.media) ? events.flatMap { builder.queuedArtwork(for: $0.id, in: changes) } : []
        let files = await Self.files(of: allArt)
        let reading = MediaReading(
            files: files, infos: InAppEventArtworkFiles.infos(atPaths: allArt.map(\.push.path)),
            stored: InAppEventArtworkFiles.stored(appID: app.id, in: directory)
        )
        let push = context.workspace.push()
        let pushItems = push?.items(appID: app.id, section: .inAppEvents) ?? []
        let claims = linkClaims.state(for: app.id)
        var result: [String: JSONValue] = [
            "appId": .string(app.id),
            "app": .string(app.name),
            "limits": [
                "name": 30, "shortDescription": 50, "longDescription": 120, "referenceName": .int(NewInAppEvent.referenceNameLimit),
                "longestEventDays": 31, "shortestEventMinutes": 15, "cardShowsDaysBeforeStart": 14, "appReviewUsuallyTakesHours": 48,
            ],
            "storePageLanguages": .array(pageLocales.map(JSONValue.string)),
            "textRules": StoreTextGuidelinePlace.eventText.rulesJSON,
            "events": .array(events.map { event in
                let texts = builder.queuedTexts(for: event.id, in: changes)
                let suggestions = store.open(for: app.id, eventID: event.id)
                var object = Self.json(event, pageLocales: pageLocales, suggested: suggestions, queued: texts, push: pushItems)
                object.merge(Self.suggestionsJSON(suggestions, of: event)) { $1 }
                object.merge(Self.media(event, queued: builder.queuedArtwork(for: event.id, in: changes), reading: reading, push: pushItems)) { $1 }
                let deepLink = Self.deepLink(of: event, builder: builder, changes: changes)
                object.merge(Self.reviewJSON(
                    event, appName: app.name, builder: builder, changes: changes, claims: claims,
                    report: store.deepLinkReport(for: app.id, eventID: event.id, deepLink: deepLink), now: now()
                )) { $1 }
                return .object(GetInAppEventsPart.keeping(parts, of: object, keys: \.eventKeys))
            }),
            "pushInProgress": .bool(push?.isRunning ?? false),
            "pushChanges": .array(pushItems.map(\.json)),
            "queued": .array(queued.map(Self.queued)),
            "artworkUpload": .string(RenderEventArtworkTool.uploadLink(app: app, port: context.port)),
        ]
        if parts.contains(.design) {
            result["design"] = InAppEventDesignFacts.json(
                look: services.storePage.appSupport?.profile(for: app.id)?.look,
                knowledge: services.storePage.appSupport?.knowledge(for: app.id),
                project: autopilot.designProject(for: app.id)
            )
        }
        result = GetInAppEventsPart.keeping(parts, of: result, keys: \.resultKeys)
        if let leftOut = GetInAppEventsPart.leftOutJSON(parts) { result.merge(leftOut) { $1 } }
        let target = only != nil && events.count == 1 ? "\(app.name) · \(events[0].referenceName)" : "\(app.name) · In-App Events"
        return .read(.object(result), target: target)
    }

    /// The app's events, or only the one `eventID` names; an unknown id
    /// throws with the ones there are.
    static func events(_ events: [InAppEvent], only eventID: String?, of app: StoreApp) throws -> [InAppEvent] {
        guard let eventID = eventID?.trimmingCharacters(in: .whitespaces), !eventID.isEmpty else { return events }
        guard let event = events.first(where: { $0.id == eventID }) else {
            let known = events.map { "\($0.id) (\($0.referenceName))" }.joined(separator: ", ")
            throw MCPToolError.notFound(String(localized: "\(app.name) has no In-App Event “\(eventID)”. Its events: \(known.isEmpty ? "none" : known)."))
        }
        return [event]
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
        // Always there, null when App Store Connect has none: an event
        // without a deep link can't go to App Review.
        for detail in InAppEventDetail.allCases {
            object[detail.rawValue] = detail.value(in: event).map(JSONValue.string) ?? .null
        }
        if let primary = event.primaryLocale { object["primaryLanguage"] = .string(primary) }
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
