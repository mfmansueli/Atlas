//
//  InAppEventArtworkReviewTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What the person sees of proposed event art: the art under the event's
/// text as the App Store lays it, one proposal per file with Accept and
/// Dismiss in the media card, and a change that waits until accepted.
@MainActor
@Suite("In-App Event artwork review")
struct InAppEventArtworkReviewTests {
    typealias Data = InAppEventsTestData

    private let directory = EventArtworkTestFiles.directory()

    @Test func theOverlayShowsTheBadgeNameAndTheKindsDescription() {
        let card = InAppEventArtworkOverlayTexts(event: Data.winter, kind: .card, locale: "en-US", appName: "Lumen Journal")
        #expect(card.badge == "Challenge")
        #expect(card.name == "Winter Reflection Challenge")
        #expect(card.description == "31 prompts to close the year gently")
        #expect(!card.isFallback)
        let details = InAppEventArtworkOverlayTexts(event: Data.winter, kind: .details, locale: "de-DE", appName: "Lumen Journal")
        #expect(details.description == "Three lines a day through December.")
        #expect(details.isFallback)
        let arabic = InAppEventArtworkOverlayTexts(event: Data.winter, kind: .card, locale: "ar-SA", appName: "Lumen Journal")
        #expect(arabic.isRightToLeft)
    }

    @Test(arguments: [(InAppEventMedia.Kind.card, 1280, 720), (.details, 720, 1280)])
    func theOverlayRendersAtTwiceItsPointSize(kind: InAppEventMedia.Kind, width: Int, height: Int) throws {
        let art = try #require(EventArtworkTestFiles.image(width: kind == .card ? 1920 : 1080, height: kind == .card ? 1080 : 1920))
        let texts = InAppEventArtworkOverlayTexts(event: Data.winter, kind: kind, locale: "en-US", appName: "Lumen Journal")
        let image = try #require(InAppEventArtworkOverlayRenderer.render(art, kind: kind, texts: texts))
        #expect(image.width == width)
        #expect(image.height == height)
        // The fade darkens the bottom; the top keeps the art's color.
        let pixels = try #require(ArtworkPixels(image))
        let top = ArtworkContrast.luminance(pixels.color(x: pixels.width - 4, y: 4))
        let bottom = ArtworkContrast.luminance(pixels.color(x: pixels.width - 4, y: pixels.height - 4))
        #expect(bottom < top)
    }

    @Test func oneFileForManyLanguagesIsOneProposal() async throws {
        let fileID = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1920, height: 1080), name: "card.png", in: directory)
        let report = try #require(await InAppEventArtworkReport.make(
            fileID: fileID, appID: Data.app.id, kind: .card, language: "en-US", in: directory
        ))
        let builder = InAppEventChangeBuilder(appID: Data.app.id)
        let event = Data.winter
        let queue = ChangeQueue()
        queue.upsert(contentsOf: event.localizations.map { builder.artworkChange(report, into: $0, of: event, source: .assistant(client: "Claude Code")) })
        // A text change of the event isn't art.
        try queue.upsert(#require(builder.fieldChange(.name, to: "Winter", in: event.localizations[0], of: event, source: .you)))

        let queued = builder.queuedArtwork(for: event.id, in: queue.changes)
        #expect(queued.map(\.locale) == ["de-DE", "en-US"])
        #expect(queued.allSatisfy { $0.kind == .card && $0.isAwaitingAcceptance })
        let proposals = InAppEventArtworkProposal.grouped(queued)
        #expect(proposals.count == 1)
        #expect(proposals[0].locales == ["de-DE", "en-US"])
        #expect(proposals[0].push.fileName == "card.png")
        // The text drafts aren't confused by the art's ids.
        #expect(builder.drafts(for: event.id, in: queue.changes) == ["en-US": [.name: "Winter"]])

        let viewModel = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices(), store: InAppEventsStore(), queue: queue)
        let shown = viewModel.artworkProposals(of: event)
        #expect(shown.count == 1)
        viewModel.acceptArtwork(shown[0])
        #expect(queue.changes.filter { $0.id.contains(".artwork.") }.allSatisfy { !$0.isBlocked })
        #expect(viewModel.toast?.text == "Event card accepted · waiting in Review & Push")
        viewModel.dismissArtwork(viewModel.artworkProposals(of: event)[0])
        #expect(queue.changes.map(\.id) == [builder.changeID(eventID: event.id, locale: "en-US", field: .name)])
    }

    @Test func aWaitingChangeIsntAnErrorAndAcceptingItSelectsIt() {
        var change = PendingChange(id: "c", appID: "1", section: .inAppEvents, group: "g", title: "t", oldValue: "", newValue: "n", requests: [])
        change.awaitingAcceptance = "Look at it, then accept it here or in In-App Events."
        #expect(change.isBlocked)
        #expect(change.blockedReason == nil)
        #expect(change.blockingMessage == "Look at it, then accept it here or in In-App Events.")
        let queue = ChangeQueue()
        queue.upsert(change)
        let push = PushController(queue: queue, history: PushHistory(), transport: FakePushTransport())
        let review = ReviewPushViewModel(queue: queue, push: push, selectedAppID: "1", appName: { _ in "App" })
        review.accept("c")
        #expect(queue.change(id: "c")?.awaitingAcceptance == nil)
        #expect(review.isSelected("c"))
    }

    @Test func aChangeSavedBeforeAcceptanceExistedStillReads() throws {
        let saved = PendingChange(id: "old", appID: "1", section: .storePage, group: "g", title: "t", oldValue: "a", newValue: "b", requests: [])
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(saved)) as? [String: Any])
        json.removeValue(forKey: "awaitingAcceptance")
        let decoded = try JSONDecoder().decode(PendingChange.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.awaitingAcceptance == nil)
        #expect(!decoded.isBlocked)
    }
}
