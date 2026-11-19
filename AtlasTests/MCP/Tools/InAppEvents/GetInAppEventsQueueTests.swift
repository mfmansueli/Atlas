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

    private func call(_ tool: some MCPTool, _ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.inAppEvents = FakeInAppEventsServices()
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code", allowedProposals: Set(MCPProposalKind.allCases))
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private func read() async throws -> JSONValue {
        try await call(GetInAppEventsTool(store: InAppEventsStore()), ["appId": "Lumen Journal"]).result
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
        _ = try await call(
            ProposeEventArtworkTool(directory: directory),
            ["appId": "Lumen Journal", "eventId": "winter", "artwork": [["kind": "card", "fileId": .string(fileID)]]]
        )

        let queued = try #require(try await winter(read())["queuedArtwork"]?.arrayValue)

        let french = try #require(queued.first { $0["locale"] == "fr-FR" })
        #expect(french["languageCreatedByPush"] == true)
        #expect(queued.first { $0["locale"] == "en-US" }?["languageCreatedByPush"] == nil)
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
