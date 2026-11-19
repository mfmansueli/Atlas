//
//  EventArtworkToolsTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Atlas

/// `render_event_artwork`, `propose_event_artwork` and the media state in
/// `get_in_app_events`: an assistant makes or sends an event's card and
/// details page, sees it under the event's text with its checks, and
/// queues it for the person to accept. Nothing is pushed.
@MainActor
@Suite("In-App Event artwork MCP tools", .serialized)
struct EventArtworkToolsTests {
    typealias Data = InAppEventsTestData

    private let directory = EventArtworkTestFiles.directory()
    private let changes = ChangeQueue()

    private func call(
        _ tool: some MCPTool, _ arguments: [String: JSONValue], events: [InAppEvent] = Data.events,
        allowed: Set<MCPProposalKind> = Set(MCPProposalKind.allCases)
    ) async throws -> MCPToolOutcome {
        var workspace = MCPTestFixtures.workspace(changes: changes)
        workspace.services.inAppEvents = FakeInAppEventsServices(events)
        let context = MCPToolContext(workspace: workspace, clientName: "Claude Code", allowedProposals: allowed)
        return try await tool.call(MCPToolArguments(arguments), in: context)
    }

    private func render(_ arguments: [String: JSONValue]) async throws -> MCPToolOutcome {
        try await call(RenderEventArtworkTool(directory: directory), ["appId": "Lumen Journal", "eventId": "winter"].merging(arguments) { $1 })
    }

    private func propose(_ artwork: [JSONValue], eventID: String = "winter", events: [InAppEvent] = Data.events) async throws -> MCPToolOutcome {
        try await call(
            ProposeEventArtworkTool(directory: directory), ["appId": "Lumen Journal", "eventId": .string(eventID), "artwork": .array(artwork)],
            events: events
        )
    }

    private func stored(_ width: Int, _ height: Int, name: String = "card.png", busy: Bool = false) throws -> String {
        try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: width, height: height, busy: busy), name: name, in: directory)
    }

    private static func pixelSize(_ image: MCPToolOutcome.ImageContent) -> PixelSize? {
        guard let source = CGImageSourceCreateWithData(image.data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int, let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return PixelSize(width: width, height: height)
    }

    @Test func theToolsAreInTheToolboxFreeAndInTheInstructions() {
        let names: Set = ["render_event_artwork", "propose_event_artwork"]
        #expect(MCPToolbox.standard.toolNames.isSuperset(of: names))
        #expect(names.compactMap { ProAssistantGate.refusal(forTool: $0, isPro: false) }.isEmpty)
        #expect(RenderEventArtworkTool().definition.isReadOnly)
        #expect(ProposeEventArtworkTool().definition.proposalKind == .artwork)
        #expect(MCPEndpoint.instructions.contains("render_event_artwork"))
        #expect(MCPEndpoint.instructions.contains("propose_event_artwork"))
        #expect(MCPEndpoint.instructions.contains("the tools only ever queue changes"))
    }

    // MARK: - render_event_artwork

    @Test func aFileIsCheckedAndShownUnderTheEventsText() async throws {
        let outcome = try await render(["kind": "card", "fileId": .string(stored(1920, 1080))])
        let result = outcome.result
        #expect(result["canPropose"] == true)
        #expect(result["pixelSize"] == "1920 × 1080")
        #expect(result["refusals"]?.arrayValue == [])
        #expect(result["locale"] == "en-US")
        #expect(result["overlay"]?["badge"] == "Challenge")
        #expect(result["overlay"]?["name"] == "Winter Reflection Challenge")
        #expect(result["overlay"]?["description"] == "31 prompts to close the year gently")
        #expect(result["then"] == "propose_event_artwork with this fileId, for every language or some")
        // The art, then the art as the App Store lays the text over it.
        #expect(outcome.images.count == 2)
        #expect(outcome.images.allSatisfy { $0.mimeType == "image/jpeg" })
        #expect(outcome.images.map(Self.pixelSize) == [PixelSize(width: 1280, height: 720), PixelSize(width: 1280, height: 720)])
        #expect(outcome.logLines.first?.outcome == MCPCallOutcome.read)
        #expect(changes.changes.isEmpty)
    }

    @Test func aDetailsPageInALanguageWithoutTextsShowsThePrimaryOnes() async throws {
        let png = EventArtworkTestFiles.png(width: 1080, height: 1920)
        let outcome = try await render(["kind": "details", "locale": "de-DE", "imageBase64": .string(png.base64EncodedString()), "fileName": "details.png"])
        #expect(outcome.result["fileName"] == "details.png")
        #expect(outcome.result["canPropose"] == true)
        #expect(outcome.result["overlay"]?["name"] == "Winter Reflection Challenge")
        #expect(outcome.result["overlay"]?["description"] == "Three lines a day through December.")
        #expect(outcome.result["overlay"]?["note"] != nil)
        #expect(outcome.images.last.flatMap(Self.pixelSize) == PixelSize(width: 720, height: 1280))
    }

    @Test func artOutsideApplesRulesIsShownWithWhatToFix() async throws {
        let outcome = try await render(["kind": "card", "fileId": .string(stored(1280, 720))])
        #expect(outcome.result["canPropose"] == false)
        #expect(outcome.result["refusals"]?.arrayValue?.first?.stringValue?.contains("make it at least 1920 × 1080") == true)
        #expect(outcome.result["then"] == "fix the refusals, then render again")
        #expect(outcome.images.count == 2)
    }

    @Test func artWithoutASourceOrWithTwoIsRefusedWithTheUploadLink() async throws {
        let none = try await render(["kind": "card"])
        #expect(none.result["status"] == "refused")
        #expect(none.result["reason"] == "Give the art: html, a fileId from the upload link, or imageBase64.")
        let link = try #require(none.result["uploadLink"]?.stringValue)
        #expect(link == "http://127.0.0.1:47321/event-artwork/\(InAppEventArtworkFiles.uploadToken)/\(Data.app.id)")

        let two = try await render(["kind": "card", "fileId": "ea-0000000000", "imageBase64": "AAAA"])
        #expect(two.result["reason"] == "Give only one of html, fileId and imageBase64.")
        let text = try await render(["kind": "card", "imageBase64": .string(Foundation.Data("hello".utf8).base64EncodedString())])
        #expect(text.result["reason"] == "imageBase64 takes a PNG or JPEG; send a video to the upload link.")
        let unknown = try await render(["kind": "card", "fileId": "ea-0000000000"])
        #expect(unknown.result["status"] == "refused")
        await #expect(throws: MCPToolError.self) { _ = try await render(["kind": "poster", "fileId": "ea-0000000000"]) }
        await #expect(throws: MCPToolError.self) { _ = try await render(["eventId": "nope", "kind": "card", "fileId": "ea-0000000000"]) }
    }

    @Test func anHTMLPageRendersAtTheLargestSizeAppleTakes() async throws {
        let html = "<!doctype html><html><body style='margin:0;background:#1f2e5c'></body></html>"
        let outcome = try await render(["kind": "card", "html": .string(html)])
        #expect(outcome.result["pixelSize"] == "3840 × 2160")
        #expect(outcome.result["fileName"] == "winter-reflection-2026-card-en-us.png")
        #expect(outcome.result["canPropose"] == true)
        let fileID = try #require(outcome.result["fileId"]?.stringValue)
        #expect(InAppEventArtworkFiles.url(id: fileID, appID: Data.app.id, in: directory) != nil)
    }

    /// A page WebKit can't draw at 3840 × 2160 is drawn at the smallest
    /// size Apple takes instead.
    @Test func aStillTooHeavyAtFullSizeIsDrawnAtTheSmallestSize() {
        let page = ArtworkWebRequest(html: "<p></p>", kind: .eventCard, locale: "en-US", isRightToLeft: false, headline: "", appName: "Lumen")
        let smaller = RenderEventArtworkTool.smallerStill(page, kind: .card)
        #expect(smaller.outputWidth == 1920)
        #expect(smaller.outputHeight == 1080)
        #expect(smaller.drawnWidth == 1920)
        let details = ArtworkWebRequest(html: "<p></p>", kind: .eventDetails, locale: "en-US", isRightToLeft: false, headline: "", appName: "Lumen")
        let tall = RenderEventArtworkTool.smallerStill(details, kind: .details)
        #expect(tall.outputWidth == 1080)
        #expect(tall.outputHeight == 1920)
    }

    /// With motion, the page's CSS animation becomes a loop Apple takes:
    /// a .mov at 30 fps and the smallest size, its first frame the poster.
    @Test func anAnimatedPageBecomesALoopAtTheSmallestSizeAppleTakes() async throws {
        let html = """
        <!doctype html><html><head><style>
        body { margin: 0; background: #1f2e5c; }
        .sun { width: 400px; height: 400px; border-radius: 50%; background: #f6c15b; animation: drift 20s linear infinite; }
        @keyframes drift { from { transform: translateX(0); } 50% { transform: translateX(800px); } to { transform: translateX(0); } }
        </style></head><body><div class="sun"></div></body></html>
        """
        let tool = RenderEventArtworkTool(directory: directory, loopFrames: 4)
        let outcome = try await call(tool, ["appId": "Lumen Journal", "eventId": "winter", "kind": "card", "html": .string(html), "motion": true])
        #expect(outcome.result["isVideo"] == true)
        #expect(outcome.result["pixelSize"] == "1920 × 1080")
        #expect(outcome.result["fileName"] == "winter-reflection-2026-card-en-us.mov")
        #expect(outcome.result["frameRate"]?.doubleValue == 30)
        // Four frames make a test loop of a tenth of a second: only its
        // length is outside Apple's rules.
        let refusals = outcome.result["refusals"]?.arrayValue?.compactMap(\.stringValue) ?? []
        #expect(refusals.count == 1)
        #expect(refusals.first?.hasPrefix("The video is 0.1 seconds") == true)
        #expect(!outcome.images.isEmpty)
        let fileID = try #require(outcome.result["fileId"]?.stringValue)
        #expect(InAppEventArtworkFiles.url(id: fileID, appID: Data.app.id, in: directory)?.pathExtension == "mov")
        // The draft it was written to is gone.
        let left = try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
        #expect(!left.contains { $0.hasPrefix("loop-") })
    }

    // MARK: - propose_event_artwork

    @Test func artGoesIntoThePrimaryLanguageAndWaitsForThePerson() async throws {
        let card = try stored(3840, 2160)
        let outcome = try await propose([["kind": "card", "fileId": .string(card)]])
        #expect(outcome.result["status"] == "queued")
        let ids = outcome.result["changes"]?.arrayValue?.compactMap { $0["changeId"]?.stringValue }
        let prefix = "inAppEvents.\(Data.app.id).winter.artwork.card."
        #expect(ids == [prefix + "en-US"])
        #expect(outcome.result["sameAsPrimary"] == nil)
        #expect(changes.changes.count == 1)
        #expect(changes.changes.allSatisfy { $0.awaitingAcceptance != nil && $0.isBlocked && $0.source == .assistant(client: "Claude Code") })
        #expect(changes.changes.first?.oldValue == "Image 1920 × 1080")
        #expect(outcome.result["next"] == "The person looks at it and accepts it; pushing uploads it. Never push or submit it yourself.")
        #expect(outcome.logLines.map(\.outcome) == [.proposed])

        // Another file for German is its own art: it's queued.
        _ = try await propose([["kind": "card", "fileId": .string(stored(1920, 1080, name: "card-2.png")), "locales": ["de-DE"]]])
        #expect(changes.changes.count == 2)
        let german = changes.changes.first { $0.id == prefix + "de-DE" }
        #expect(german?.oldValue == "None")
        // Proposed again, the waiting one is replaced, not doubled.
        _ = try await propose([["kind": "card", "fileId": .string(stored(1920, 1080, name: "card-3.png", busy: true)), "locales": ["de-DE"]]])
        #expect(changes.changes.count == 2)
        let replaced = changes.changes.first { $0.id == prefix + "de-DE" }
        #expect(replaced.flatMap { $0.requests.first.flatMap(InAppEventArtworkPush.init) }?.fileName == "card-3.png")
    }

    /// One video for every language: only the primary language gets it, as
    /// the others show the primary's; a language with its own card in App
    /// Store Connect gets it too, to replace that one.
    @Test func theSameFileIsntCopiedIntoLanguagesThatShowThePrimarysArt() async throws {
        var winter = Data.winter
        winter.localizations.append(InAppEventLocalization(
            id: "loc-fr", locale: "fr-FR", name: "Hiver", shortDescription: "s", longDescription: "l",
            media: [InAppEventMedia(kind: .card, width: 1920, height: 1080, fileName: "old-fr.png", fileSize: 99)]
        ))
        let card = try stored(1920, 1080)
        let outcome = try await propose([["kind": "card", "fileId": .string(card), "locales": "all"]], events: [winter])
        #expect(outcome.result["status"] == "queued")
        let prefix = "inAppEvents.\(Data.app.id).winter.artwork.card."
        #expect(Set(changes.changes.map(\.id)) == [prefix + "en-US", prefix + "fr-FR"])
        let same = try #require(outcome.result["sameAsPrimary"]?.arrayValue)
        #expect(same.count == 1)
        #expect(same.first?["locale"] == "de-DE")
        #expect(same.first?["note"]?.stringValue?.contains("shows en-US's") == true)

        // The same bytes under another file id are the same art too.
        let copy = try stored(1920, 1080, name: "card-again.png")
        let again = try await propose([["kind": "card", "fileId": .string(copy), "locales": ["de-DE"]]], events: [winter])
        #expect(again.result["status"] == "notNeeded")
        #expect(again.isError == false)
        #expect(again.result["sameAsPrimary"]?.arrayValue?.first?["locale"] == "de-DE")
        #expect(changes.changes.count == 2)
    }

    /// Without a queued card, the primary language's art is App Store
    /// Connect's: a file Atlas uploaded there (same name and size) isn't
    /// queued again for a language that shows it.
    @Test func theArtAlreadyInAppStoreConnectIsntCopiedEither() async throws {
        let card = try stored(1920, 1080, name: "winter-card.png")
        let url = try #require(InAppEventArtworkFiles.url(id: card, appID: Data.app.id, in: directory))
        let size = try #require(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        var winter = Data.winter
        winter.localizations[0].media = [InAppEventMedia(kind: .card, width: 1920, height: 1080, fileName: "winter-card.png", fileSize: size)]
        let outcome = try await propose([["kind": "card", "fileId": .string(card), "locales": ["de-DE"]]], events: [winter])
        #expect(outcome.result["status"] == "notNeeded")
        #expect(changes.changes.isEmpty)
    }

    @Test func aVideoDetailsPageGoesIntoSomeLanguagesWithItsPosterFrame() async throws {
        // Five seconds, the shortest Apple takes.
        let video = try await EventArtworkTestFiles.storedMovie(width: 1080, height: 1920, fps: 30, frames: 150, in: directory)
        let outcome = try await propose([["kind": "details", "fileId": .string(video), "locales": ["de-DE", "ja"], "posterSeconds": .double(1.5)]])
        #expect(outcome.result["status"] == "queued")
        #expect(outcome.result["changes"]?.arrayValue?.count == 1)
        let refused = try #require(outcome.result["refused"]?.arrayValue)
        #expect(refused.first?["locale"] == "ja")
        #expect(refused.first?["reason"]?.stringValue?.hasPrefix("The event has no ja language yet") == true)
        let push = try #require(changes.changes.first?.requests.first.flatMap(InAppEventArtworkPush.init))
        #expect(push.isVideo)
        #expect(push.kind == .details)
        #expect(push.localizationID == "loc-de")
        #expect(push.previewFrameTimeCode == "00:00:01:15")
    }

    @Test func aFileWithARefusalIsntQueued() async throws {
        let outcome = try await propose([
            ["kind": "card", "fileId": .string(stored(1280, 720))],
            ["kind": "details", "fileId": .string(stored(1920, 1080, name: "wide.png"))],
            ["kind": "poster", "fileId": "x"],
            ["kind": "card", "fileId": "ea-0000000000"],
        ])
        #expect(outcome.result["status"] == "refused")
        let reasons = outcome.result["refused"]?.arrayValue?.compactMap { $0["reason"]?.stringValue } ?? []
        #expect(reasons.count == 4)
        #expect(reasons[0].contains("make it at least 1920 × 1080"))
        #expect(reasons[1].contains("this looks like the card (16:9)"))
        #expect(reasons[2] == "kind is card or details.")
        #expect(reasons[3].hasPrefix("Atlas has no file “ea-0000000000”"))
        #expect(changes.changes.isEmpty)
    }

    @Test func anEventWithAppReviewOrOverOrWithoutPermissionTakesNoArt() async throws {
        let card = try stored(1920, 1080)
        var reviewed = Data.winter
        reviewed.state = .inReview
        let inReview = try await propose([["kind": "card", "fileId": .string(card)]], events: [reviewed])
        #expect(inReview.result["reason"]?.stringValue?.contains("is with App Review") == true)
        let past = try await propose([["kind": "card", "fileId": .string(card)]], eventID: "gratitude")
        #expect(past.result["reason"]?.stringValue?.contains("is over") == true)
        let noPermission = try await call(
            ProposeEventArtworkTool(directory: directory),
            ["appId": "Lumen Journal", "eventId": "winter", "artwork": [["kind": "card", "fileId": .string(card)]]],
            allowed: [.storeText]
        )
        #expect(noPermission.result["status"] == "refused")
        #expect(changes.changes.isEmpty)
    }

    // MARK: - get_in_app_events

    @Test func eachLanguagesMediaWhatIsMissingAndTheQueuedArtAreRead() async throws {
        _ = try await propose([["kind": "card", "fileId": .string(stored(1920, 1080)), "locales": ["de-DE"]]])
        let outcome = try await call(GetInAppEventsTool(store: InAppEventsStore()), ["appId": "Lumen Journal"])
        let link = "http://127.0.0.1:47321/event-artwork/\(InAppEventArtworkFiles.uploadToken)/\(Data.app.id)"
        #expect(outcome.result["artworkUpload"] == .string(link))
        let winter = try #require(outcome.result["events"]?.arrayValue?.first)
        #expect(winter["media"]?["en-US"]?["card"] == "image 1920 × 1080")
        #expect(winter["media"]?["en-US"]?["details"] == "image 1080 × 1920")
        #expect(winter["media"]?["de-DE"]?["card"] == "none · shows en-US's image 1920 × 1080")
        #expect(winter["stillMissing"]?["neededToSubmit"]?.arrayValue == [])
        #expect(winter["stillMissing"]?["cardWithoutOwn"]?.arrayValue == ["de-DE"])
        #expect(winter["stillMissing"]?["detailsWithoutOwn"]?.arrayValue == ["de-DE"])
        let queued = try #require(winter["queuedArtwork"]?.arrayValue)
        #expect(queued.count == 1)
        #expect(queued[0]["locale"] == "de-DE")
        #expect(queued[0]["kind"] == "card")
        #expect(queued[0]["waitingForAcceptance"] == true)
        #expect(queued[0]["by"] == "Claude Code")
        let gratitude = try #require(outcome.result["events"]?.arrayValue?.last)
        #expect(gratitude["mediaNote"] != nil)
    }

    @Test func anEventWithoutMediaSaysWhatSubmittingNeeds() {
        var bare = Data.winter
        for index in bare.localizations.indices { bare.localizations[index].media = [] }
        let state = InAppEventMediaState(event: bare)
        #expect(state.neededToSubmit == [.card, .details])
        #expect(state.languages.first?.text(.card) == "none")
        var video = Data.winter
        video.localizations[1].media = [InAppEventMedia(kind: .details, isVideo: true)]
        #expect(InAppEventMediaState(event: video).languages[1].text(.details) == "video")
    }
}
