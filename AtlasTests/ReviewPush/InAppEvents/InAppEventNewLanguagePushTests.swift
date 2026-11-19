//
//  InAppEventNewLanguagePushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Pushing an event's image into a language the same push creates: the
/// texts go first, then the push reads the event's languages and uploads
/// into the new one. Without its texts the image says what to push first.
@MainActor
@Suite("In-App Event art pushed into a new language")
struct InAppEventNewLanguagePushTests {
    typealias Events = InAppEventsTestData

    private let directory = EventArtworkTestFiles.directory()
    private let builder = InAppEventChangeBuilder(appID: InAppEventsTestData.app.id)
    private let queue = ChangeQueue()
    private let history = PushHistory()

    private func frenchCard() async throws -> PendingChange {
        let id = try EventArtworkTestFiles.store(EventArtworkTestFiles.png(width: 1920, height: 1080), name: "card.png", in: directory)
        let report = try #require(await InAppEventArtworkReport.make(fileID: id, appID: Events.app.id, kind: .card, language: "en-US", in: directory))
        return builder.artworkChange(report, newLanguage: "fr-FR", of: Events.winter, source: .you)
    }

    private func frenchTexts() throws -> PendingChange {
        try #require(builder.newLanguageChange(
            [.name: "Réflexion d’hiver", .shortDescription: "31 questions", .longDescription: "Trois lignes par jour."],
            locale: "fr-FR", of: Events.winter, source: .you
        ))
    }

    private func push(via transport: FakeNewLanguageTransport) async -> PushController {
        let push = PushController(queue: queue, history: history, transport: transport)
        push.push(queue.changes)
        await push.waitUntilFinished()
        return push
    }

    @Test func theImageGoesUpOnceItsTextsHaveCreatedTheLanguage() async throws {
        // Queued before its texts: it still goes after them.
        try await queue.upsert(contentsOf: [frenchCard(), frenchTexts()])
        let transport = FakeNewLanguageTransport(languages: ["en-US": "loc-en", "de-DE": "loc-de"])

        let push = await push(via: transport)

        #expect(push.doneCount == 2)
        #expect(queue.changes.isEmpty)
        #expect(transport.log == ["create fr-FR", "languages winter"])
        #expect(transport.artwork.log.contains("reserve appEventScreenshots card.png EVENT_CARD loc-fr-FR"))
        #expect(!transport.artwork.log.contains { $0.contains("{eventLocalization") })
    }

    @Test func withoutItsTextsTheImageSaysWhatToPushFirst() async throws {
        try await queue.upsert(frenchCard())
        let transport = FakeNewLanguageTransport(languages: ["en-US": "loc-en"])

        let push = await push(via: transport)

        let name = InAppEventChangeBuilder.localeName("fr-FR")
        #expect(push.items.first?.status == .failed("\(name) isn’t on this event in App Store Connect yet. Push its texts first, then its images."))
        #expect(transport.artwork.log.isEmpty)
        #expect(queue.changes.count == 1)
    }
}
