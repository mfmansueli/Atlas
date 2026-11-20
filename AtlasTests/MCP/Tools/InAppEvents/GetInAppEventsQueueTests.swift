//
//  GetInAppEventsQueueTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What `get_in_app_events` says is waiting in Review & Push, so an
/// assistant can answer "which art and texts were chosen" from the MCP
/// alone: the texts per language (and those languages aren't missing any
/// more), and each art upload with the file Atlas sends.
@MainActor
@Suite("get_in_app_events · what's queued", .serialized)
struct GetInAppEventsQueueTests {
    typealias Data = InAppEventsTestData

    private let directory = EventArtworkTestFiles.directory()
    private let changes = ChangeQueue()
    private let builder = InAppEventChangeBuilder(appID: InAppEventsTestData.app.id)

    private func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue], events: [InAppEvent] = InAppEventsTestData.events, push: MCPPushSnapshot? = nil
    ) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.inAppEvents = FakeInAppEventsServices(events)
        workspace.push = { push }
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code", allowedProposals: Set(MCPProposalKind.allCases))
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    /// Every part (`include: ["all"]`), mediaDetails too.
    private func read(events: [InAppEvent] = InAppEventsTestData.events, push: MCPPushSnapshot? = nil) async throws -> JSONValue {
        try await call(
            GetInAppEventsTool(store: InAppEventsStore(), directory: directory, now: { Data.now }), ["appId": "Lumen Journal", "include": ["all"]],
            events: events, push: push
        ).result
    }

    /// Queues `fileID`'s image as `kind` for `locales` straight from the
    /// builder (no copy check).
    private func queue(
        _ fileID: String, kind: InAppEventMedia.Kind = .card, into locales: [String], of event: InAppEvent = InAppEventsTestData.winter
    ) async throws {
        let report = try #require(await InAppEventArtworkReport.make(fileID: fileID, appID: Data.app.id, kind: kind, language: "en-US", in: directory))
        for locale in locales {
            let localization = try #require(event.localization(locale))
            changes.upsert(builder.artworkChange(report, into: localization, of: event, source: .you))
        }
    }

    private func path(of fileID: String) throws -> String {
        try #require(InAppEventArtworkFiles.url(id: fileID, appID: Data.app.id, in: directory)?.path(percentEncoded: false))
    }

    private func winter(_ result: JSONValue) throws -> JSONValue {
        try #require(result["events"]?.arrayValue?.first { $0["id"] == "winter" })
    }

    private func missing(_ event: JSONValue) -> [String] {
        event["missingLanguages"]?.arrayValue?.compactMap(\.stringValue) ?? []
    }

    private static let french: [InAppEventField: String] = [
        .name: "Réflexion d’hiver", .shortDescription: "31 questions pour finir l’année", .longDescription: "Trois lignes par jour.",
    ]

    @Test func queuedTextsShowPerLanguageAndArentMissingAnyMore() async throws {
        let before = try await winter(read())
        #expect(before["queuedTexts"] == nil)
        let language = try #require(missing(before).first)

        let new = try #require(builder.newLanguageChange(Self.french, locale: language, of: Data.winter, source: .you))
        changes.upsert(new)
        let after = try await winter(read())

        #expect(!missing(after).contains(language))
        let queued = try #require(after["queuedTexts"]?.arrayValue)
        #expect(queued.count == 1)
        #expect(queued[0]["locale"] == .string(language))
        #expect(queued[0]["changeId"] == .string(new.id))
        #expect(queued[0]["changeIds"]?.arrayValue == [.string(new.id)])
        #expect(queued[0]["newLanguage"] == true)
        #expect(queued[0]["waitingForAcceptance"] == false)
        #expect(queued[0]["by"] == "You")
        #expect(queued[0]["name"] == "Réflexion d’hiver")
        #expect(queued[0]["shortDescription"] == "31 questions pour finir l’année")
        #expect(queued[0]["longDescription"] == "Trois lignes par jour.")
    }

    @Test func aQueuedTextThatLeavesTheLanguageIncompleteKeepsItMissing() async throws {
        // German has only its name in App Store Connect; a new name alone doesn't finish it.
        let german = try #require(Data.winter.localization("de-DE"))
        let edit = try #require(builder.fieldChange(.name, to: "Winterreflexion", in: german, of: Data.winter, source: .you))
        changes.upsert(edit)
        let event = try await winter(read())

        #expect(missing(event).contains("de-DE"))
        let queued = try #require(event["queuedTexts"]?.arrayValue?.first)
        #expect(queued["locale"] == "de-DE")
        #expect(queued["newLanguage"] == false)
        #expect(queued["name"] == "Winterreflexion")
        #expect(queued["shortDescription"] == nil)
    }

    @Test func queuedArtworkSaysWhichFileGoesAndWhere() async throws {
        let fileID = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1920, height: 1080), name: "kind-star.png", in: directory)
        _ = try await call(
            ProposeEventArtworkTool(directory: directory),
            ["appId": "Lumen Journal", "eventId": "winter", "artwork": [["kind": "card", "fileId": .string(fileID), "locales": ["de-DE"]]]]
        )
        let path = try #require(InAppEventArtworkFiles.url(id: fileID, appID: Data.app.id, in: directory)?.path(percentEncoded: false))

        let queued = try #require(try await winter(read())["queuedArtwork"]?.arrayValue?.first)

        #expect(queued["file"] == "kind-star.png")
        #expect(queued["path"] == .string(path))
        #expect(queued["fileExists"] == true)
        #expect(queued["width"] == 1920)
        #expect(queued["height"] == 1080)
        #expect((queued["fileSize"]?.intValue ?? 0) > 0)
        #expect(queued["previewFrameTimeCode"] == nil)
        #expect(queued["languageCreatedByPush"] == nil)
    }

    @Test func artForALanguageThePushCreatesSaysSo() async throws {
        let new = try #require(builder.newLanguageChange(Self.french, locale: "fr-FR", of: Data.winter, source: .you))
        changes.upsert(new)
        let fileID = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1920, height: 1080), name: "card.png", in: directory)
        // French has art of its own (the English file would be left out:
        // French shows it anyway).
        let frenchID = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1920, height: 1080, busy: true), name: "fr.png", in: directory)
        _ = try await call(ProposeEventArtworkTool(directory: directory), [
            "appId": "Lumen Journal", "eventId": "winter",
            "artwork": [["kind": "card", "fileId": .string(fileID)], ["kind": "card", "fileId": .string(frenchID), "locales": ["fr-FR"]]],
        ])

        let queued = try #require(try await winter(read())["queuedArtwork"]?.arrayValue)

        let french = try #require(queued.first { $0["locale"] == "fr-FR" })
        #expect(french["languageCreatedByPush"] == true)
        #expect(queued.first { $0["locale"] == "en-US" }?["languageCreatedByPush"] == nil)
    }

    /// The name a file came with, its SHA-256 and where it came from show
    /// with each queued upload; a file kept before Atlas wrote them shows
    /// neither.
    @Test func queuedArtworkSaysWhereItsFileCameFrom() async throws {
        let png = EventArtworkTestFiles.png(width: 1920, height: 1080)
        let fileID = try InAppEventArtworkFiles.save(
            png, fileName: "Winter card final.png", appID: Data.app.id, in: directory,
            origin: InAppEventArtworkOrigin(source: .upload, name: "Winter card final.png")
        )
        try await queue(fileID, into: ["en-US"])
        let queued = try #require(try await winter(read())["queuedArtwork"]?.arrayValue?.first)
        #expect(queued["originalName"] == "Winter card final.png")
        #expect(queued["sha256"] == .string(InAppEventArtworkFileInfo.sha256(of: png)))
        #expect(queued["origin"]?["from"] == "upload")
        #expect(queued["origin"]?["name"] == "Winter card final.png")

        // Art from Make the Artwork names its concept.
        let made = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1080, height: 1920), name: "c-details.png", in: directory)
        InAppEventArtworkFiles.markConcept([made], conceptID: "c2", title: "Snow path", appID: Data.app.id, in: directory)
        try await queue(made, kind: .details, into: ["en-US"])
        let details = try #require(try await winter(read())["queuedArtwork"]?.arrayValue?.first { $0["kind"] == "details" })
        #expect(details["origin"]?["from"] == "makeTheArtwork")
        #expect(details["origin"]?["conceptId"] == "c2")
        #expect(details["origin"]?["title"] == "Snow path")

        // A file without its info: the fields are left out.
        let info = try URL(fileURLWithPath: path(of: fileID)).deletingLastPathComponent().appending(path: InAppEventArtworkFiles.infoName)
        try FileManager.default.removeItem(at: info)
        let old = try #require(try await winter(read())["queuedArtwork"]?.arrayValue?.first { $0["kind"] == "card" })
        #expect(old["originalName"] == nil)
        #expect(old["sha256"] == nil)
        #expect(old["origin"] == nil)
        #expect(old["file"] == "Winter card final.png")
    }

    /// The primary language's file queued again for a language that shows
    /// it anyway is flagged, and the queue is listed grouped by file.
    @Test func aCopyOfThePrimarysArtIsFlaggedAndTheQueueIsGroupedByFile() async throws {
        let cardData = EventArtworkTestFiles.png(width: 1920, height: 1080)
        let card = try EventArtworkTestFiles.store(cardData, name: "card.png", in: directory)
        let details = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1080, height: 1920), name: "details.png", in: directory)
        try await queue(card, into: ["en-US", "de-DE"])
        try await queue(details, kind: .details, into: ["en-US"])
        let event = try await winter(read())

        let queued = try #require(event["queuedArtwork"]?.arrayValue)
        let german = try #require(queued.first { $0["locale"] == "de-DE" })
        #expect(german["sameAsPrimary"] == true)
        #expect(german["copyNeeded"] == false)
        #expect(queued.first { $0["locale"] == "en-US" && $0["kind"] == "card" }?["sameAsPrimary"] == nil)
        let germanID = try #require(german["changeId"])
        #expect(event["identicalCopies"]?["changeIds"]?.arrayValue == [germanID])

        let summary = try #require(event["queuedArtworkSummary"]?.arrayValue)
        #expect(summary.count == 2)
        #expect(summary[0]["kind"] == "card")
        #expect(summary[0]["file"] == "card.png")
        #expect(summary[0]["originalName"] == "card.png")
        #expect(summary[0]["sha256"] == .string(InAppEventArtworkFileInfo.sha256(of: cardData)))
        #expect(summary[0]["locales"]?.arrayValue == ["de-DE", "en-US"])
        #expect(summary[0]["changeIds"]?.arrayValue?.count == 2)
        #expect(summary[1]["kind"] == "details")
        #expect(summary[1]["locales"]?.arrayValue == ["en-US"])
        #expect(try summary[1]["path"] == .string(path(of: details)))
    }

    /// A language with its own card in App Store Connect needs the new one:
    /// it isn't listed as a copy to take out.
    @Test func aCopyForALanguageWithItsOwnArtIsNeeded() async throws {
        var event = Data.winter
        event.localizations[1].media = [InAppEventMedia(kind: .card, width: 1920, height: 1080, fileName: "old.png", fileSize: 1)]
        let card = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1920, height: 1080), name: "card.png", in: directory)
        try await queue(card, into: ["en-US", "de-DE"], of: event)
        let read = try await winter(read(events: [event]))
        let german = try #require(read["queuedArtwork"]?.arrayValue?.first { $0["locale"] == "de-DE" })
        #expect(german["sameAsPrimary"] == true)
        #expect(german["copyNeeded"] == true)
        #expect(read["identicalCopies"] == nil)
    }

    /// What App Store Connect has, file by file: the name and size it was
    /// uploaded with, its processing, the file on this Mac it came from,
    /// the queued change sending the same file, and the language showing
    /// the primary's.
    @Test func mediaDetailsShowAppStoreConnectsFiles() async throws {
        let png = EventArtworkTestFiles.png(width: 1920, height: 1080)
        let card = try EventArtworkTestFiles.store(png, name: "winter-card.png", in: directory)
        var event = Data.winter
        event.localizations[0].media = [
            InAppEventMedia(
                kind: .card, width: 1920, height: 1080, imageURL: URL(string: "https://example.com/card.jpg"), fileName: "winter-card.png",
                fileSize: png.count, state: "COMPLETE"
            ),
            InAppEventMedia(
                kind: .details, isVideo: true, width: 1080, height: 1920, fileName: "loop.mov", fileSize: 99, previewFrameTimeCode: "00:00:01:00",
                state: "FAILED", stateErrors: ["Too short."]
            ),
        ]
        try await queue(card, into: ["en-US"], of: event)
        let read = try await winter(read(events: [event]))
        // `media` keeps its one-line text.
        #expect(read["media"]?["en-US"]?["card"]?.stringValue != nil)

        let details = try #require(read["mediaDetails"])
        let english = try #require(details["en-US"]?["card"])
        #expect(english["fileName"] == "winter-card.png")
        #expect(english["fileSize"] == .int(png.count))
        #expect(english["isVideo"] == false)
        #expect(english["width"] == 1920)
        #expect(english["imageUrl"] == "https://example.com/card.jpg")
        #expect(english["state"] == "COMPLETE")
        #expect(english["atlasFile"]?["fileId"] == .string(card))
        #expect(english["atlasFile"]?["sha256"] == .string(InAppEventArtworkFileInfo.sha256(of: png)))
        #expect(english["matchesQueued"]?.arrayValue?.count == 1)
        #expect(english["shownFrom"] == nil)
        let video = try #require(details["en-US"]?["details"])
        #expect(video["previewFrameTimeCode"] == "00:00:01:00")
        #expect(video["stateErrors"]?.arrayValue == ["Too short."])
        #expect(video["atlasFile"] == nil)
        // German has none of its own: it shows the English pair.
        #expect(details["de-DE"]?["card"]?["shownFrom"] == "en-US")
        #expect(details["de-DE"]?["card"]?["fileName"] == "winter-card.png")
    }

    @Test func aLanguagesOwnCopyOfThePrimarysFileIsSaidToBeTheSame() async throws {
        var event = Data.winter
        let card = InAppEventMedia(kind: .card, width: 1920, height: 1080, fileName: "winter-card.png", fileSize: 10)
        event.localizations[0].media = [card]
        event.localizations[1].media = [card]
        let details = try #require(try await winter(read(events: [event]))["mediaDetails"])
        #expect(details["de-DE"]?["card"]?["sameAsPrimary"] == true)
        #expect(details["de-DE"]?["card"]?["shownFrom"] == nil)
        #expect(details["en-US"]?["card"]?["sameAsPrimary"] == nil)
    }

    /// While the person pushes, each queued change says where it stands.
    @Test func thePushSaysWhereEachChangeStands() async throws {
        let idle = try await read()
        #expect(idle["pushInProgress"] == false)
        #expect(idle["pushChanges"]?.arrayValue?.isEmpty == true)

        let card = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1920, height: 1080), name: "card.png", in: directory)
        try await queue(card, into: ["en-US"])
        let german = try #require(Data.winter.localization("de-DE"))
        let text = try #require(builder.fieldChange(.shortDescription, to: "Kurz", in: german, of: Data.winter, source: .you))
        changes.upsert(text)
        let cardID = builder.artworkChangeID(eventID: "winter", kind: .card, locale: "en-US")
        func item(_ id: String, _ status: PushItemStatus, note: String? = nil, app: String = Data.app.id) -> MCPPushSnapshot.Item {
            MCPPushSnapshot.Item(changeID: id, appID: app, section: .inAppEvents, groupID: "winter", title: id, status: status, progressNote: note)
        }
        let push = MCPPushSnapshot(isRunning: true, items: [
            item(cardID, .sending, note: "Uploading event card · part 2 of 3"),
            item(text.id, .failed("The text is too long.")),
            item("other-app-change", .queued, app: "999"),
        ])
        let result = try await read(push: push)
        #expect(result["pushInProgress"] == true)
        let pushed = try #require(result["pushChanges"]?.arrayValue)
        #expect(pushed.count == 2)
        #expect(pushed.first?["status"] == "sending")
        #expect(pushed.first?["progress"] == "Uploading event card · part 2 of 3")
        #expect(pushed.last?["reason"] == "The text is too long.")
        let event = try winter(result)
        let art = try #require(event["queuedArtwork"]?.arrayValue?.first)
        #expect(art["pushStatus"] == "sending")
        #expect(art["pushProgress"] == "Uploading event card · part 2 of 3")
        let texts = try #require(event["queuedTexts"]?.arrayValue?.first { $0["locale"] == "de-DE" })
        #expect(texts["pushStatus"] == "failed")
        #expect(texts["pushReason"] == "The text is too long.")
    }

    @Test func aMovedOrDeletedFileIsSaidToBeMissing() {
        let push = InAppEventArtworkPush(
            localizationID: "loc-en", kind: .card, isVideo: true, fileName: "loop.mov", fileSize: 10, path: "/tmp/atlas-gone/loop.mov",
            previewFrameTimeCode: "00:00:02:00"
        )
        let item = InAppEventQueuedArtwork(
            changeID: "c", kind: .card, locale: "en-US", push: push, source: .you, isAwaitingAcceptance: false
        )
        let json = GetInAppEventsTool.queuedArtworkJSON(item, file: nil)
        #expect(json["fileExists"] == false)
        #expect(json["languageCreatedByPush"] == nil)
        #expect(json["previewFrameTimeCode"] == "00:00:02:00")
        #expect(json["path"] == "/tmp/atlas-gone/loop.mov")
        #expect(json["width"] == nil)
    }

    @Test func aPlaceholderLanguageThatAppStoreConnectHasSinceIsntSaidToBeCreated() {
        let push = InAppEventArtworkPush(
            localizationID: EventLocalizationPlaceholder(eventID: "winter", locale: "de-DE").token, kind: .card, isVideo: false,
            fileName: "card.png", fileSize: 10, path: "/tmp/atlas-gone/card.png"
        )
        let item = InAppEventQueuedArtwork(changeID: "c", kind: .card, locale: "de-DE", push: push, source: .you, isAwaitingAcceptance: false)
        #expect(GetInAppEventsTool.queuedArtworkJSON(item, file: nil, languageExists: true)["languageCreatedByPush"] == nil)
        #expect(GetInAppEventsTool.queuedArtworkJSON(item, file: nil, languageExists: false)["languageCreatedByPush"] == true)
    }

    @Test func aLanguageWithTextsInTheQueueIsntSuggestedAgain() async throws {
        let language = try #require(try await missing(winter(read())).first)
        let new = try #require(builder.newLanguageChange(Self.french, locale: language, of: Data.winter, source: .you))
        changes.upsert(new)

        let outcome = try await call(ProposeEventTextsTool(), [
            "appId": "Lumen Journal", "eventId": "winter",
            "texts": [["locale": .string(language), "name": "Nome", "shortDescription": "Curta", "longDescription": "Longa", "why": "Natural."]],
        ])

        let skipped = outcome.result["skipped"]?.arrayValue ?? []
        let reason = skipped.first { $0["locale"] == .string(language) }?["reason"]?.stringValue
        #expect(reason?.contains("already waiting in Review & Push") == true)
    }
}
