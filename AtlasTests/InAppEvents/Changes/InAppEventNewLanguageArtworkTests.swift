//
//  InAppEventNewLanguageArtworkTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Art for a language its queued texts create: Atlas no longer copies the
/// event's art there by itself (Apple shows the primary language's in a
/// language without its own); art someone names for it waits under the
/// language's locale until the push has created it, leaves with its texts,
/// and goes after everything else.
@MainActor
@Suite("In-App Event art in new languages")
struct InAppEventNewLanguageArtworkTests {
    typealias Events = InAppEventsTestData
    typealias Studio = EventArtworkStudioTestData

    private let directory = EventArtworkTestFiles.directory()
    private let builder = InAppEventChangeBuilder(appID: InAppEventsTestData.app.id)
    private let queue = ChangeQueue()

    private func report(_ kind: InAppEventMedia.Kind) async throws -> InAppEventArtworkReport {
        let size = InAppEventArtworkRules.minimumSize(for: kind)
        let id = try EventArtworkTestFiles.store(
            EventArtworkTestFiles.png(width: size.width, height: size.height), name: "\(kind.mcpValue).png", in: directory
        )
        return try #require(await InAppEventArtworkReport.make(fileID: id, appID: Events.app.id, kind: kind, language: "en-US", in: directory))
    }

    private func texts(_ locale: String) throws -> PendingChange {
        try #require(builder.newLanguageChange(
            [.name: "Réflexion d’hiver", .shortDescription: "31 questions", .longDescription: "Trois lignes par jour."],
            locale: locale, of: Events.winter, source: .you
        ))
    }

    /// The art queued for the event's own two languages.
    private func eventArt() async throws -> [PendingChange] {
        let card = try await report(.card)
        let details = try await report(.details)
        return Events.winter.localizations.flatMap { localization in
            [card, details].map { builder.artworkChange($0, into: localization, of: Events.winter, source: .you) }
        }
    }

    private func localizationID(of change: PendingChange) -> String? {
        change.requests.lazy.compactMap(InAppEventArtworkPush.init).first?.localizationID
    }

    @Test func aLanguageNotCreatedYetIsNamedByItsLocale() throws {
        let language = EventLocalizationPlaceholder(eventID: "winter", locale: "fr-FR")
        #expect(language.token == "{eventLocalization:winter:fr-FR}")
        #expect(EventLocalizationPlaceholder(text: "a \(language.token) b") == language)
        #expect(EventLocalizationPlaceholder(text: "{eventLocalization:winter}") == nil)
        #expect(EventLocalizationPlaceholder.isPlaceholder(language.token))
        #expect(!EventLocalizationPlaceholder.isPlaceholder("loc-en"))

        let push = InAppEventArtworkPush(
            localizationID: language.token, kind: .card, isVideo: false, fileName: "card.png", fileSize: 10, path: "/tmp/card.png"
        )
        #expect(EventLocalizationPlaceholder(in: push.request) == language)
        #expect(InAppEventArtworkPush(push.request)?.localizationID == language.token)
        #expect(try EventLocalizationPlaceholder(in: texts("fr-FR").requests[0]) == nil)
    }

    @Test func theNewLanguagesAreTheOnesQueuedTextsCreate() throws {
        let edit = try #require(builder.fieldChange(.name, to: "Winter", in: Events.winter.localizations[0], of: Events.winter, source: .you))
        let changes = try [edit, texts("ja"), texts("fr-FR")]
        #expect(builder.newLanguages(of: "winter", in: changes) == ["fr-FR", "ja"])
        #expect(builder.newLanguages(of: "update", in: changes).isEmpty)
    }

    @Test func artNamedForANewLanguageWaitsForItAndLeavesWithItsTexts() async throws {
        let art = try await eventArt()
        let french = try await builder.artworkChange(report(.card), newLanguage: "fr-FR", of: Events.winter, source: .you)
        #expect(localizationID(of: french) == "{eventLocalization:winter:fr-FR}")
        #expect(french.title == "\(InAppEventChangeBuilder.localeName("fr-FR")) · \(InAppEventMedia.Kind.card.title)")
        #expect(french.flagRegion == "FR")
        #expect(french.oldValue == "None")

        // With its texts queued, nothing leaves.
        let changes = try art + [texts("fr-FR"), french]
        #expect(builder.orphanedNewLanguageArtwork(of: Events.winter, in: changes).isEmpty)
        // Its texts gone, its image goes; the event's own languages' stay.
        let without = changes.filter { $0.id != builder.newChangeID(eventID: "winter", locale: "fr-FR") }
        #expect(builder.orphanedNewLanguageArtwork(of: Events.winter, in: without) == [french.id])
    }

    @Test func theUploadsForNewLanguagesGoAfterEverythingElse() async throws {
        let art = try await eventArt()
        let french = try await builder.artworkChange(report(.card), newLanguage: "fr-FR", of: Events.winter, source: .you)
        let frenchTexts = try texts("fr-FR")
        let sorted = InAppEventPushOrder.sorted([french, art[0], frenchTexts, art[1]])
        #expect(sorted.map(\.id) == [art[0].id, frenchTexts.id, art[1].id, french.id])
        #expect(InAppEventPushOrder.waitsForANewLanguage(french))
        #expect(!InAppEventPushOrder.waitsForANewLanguage(art[0]))
    }

    @Test func writingANewLanguageCopiesNoArtAndEmptyingItTakesItsOwnAway() async throws {
        let model = InAppEventsViewModel(app: Events.app, services: FakeInAppEventsServices(), store: InAppEventsStore(), queue: queue)
        await model.load()
        try await queue.upsert(contentsOf: eventArt())
        let cardID = builder.artworkChangeID(eventID: "winter", kind: .card, locale: "fr-FR")

        model.write([.name: "Réflexion d’hiver"], locale: "fr-FR", of: Events.winter, source: .you)
        // French shows the English art: no copy is queued for it.
        #expect(queue.change(id: cardID) == nil)
        #expect(queue.change(id: builder.artworkChangeID(eventID: "winter", kind: .details, locale: "fr-FR")) == nil)

        // Art someone queued for French leaves once its texts do.
        try await queue.upsert(builder.artworkChange(report(.card), newLanguage: "fr-FR", of: Events.winter, source: .you))
        model.write([.name: ""], locale: "fr-FR", of: Events.winter, source: .you)
        #expect(queue.change(id: builder.newChangeID(eventID: "winter", locale: "fr-FR")) == nil)
        #expect(queue.change(id: cardID) == nil)
        #expect(queue.changes.count == 4)
    }

    @Test func useThisArtworkLeavesTheLanguagesBeingCreatedToThePrimarysArt() async throws {
        let studio = EventArtworkStudio()
        try studio.begin(Studio.run(step: .choose, concepts: [Studio.concept("a", isPick: true, in: directory)]))
        let flow = EventArtworkFlow(app: Events.app, event: Events.winter, studio: studio, queue: queue, hasDesignSystem: true)
        flow.directory = directory
        flow.now = { Events.now }
        try queue.upsert(texts("fr-FR"))

        #expect(await flow.use("a"))
        #expect(queue.change(id: builder.artworkChangeID(eventID: "winter", kind: .card, locale: "fr-FR")) == nil)
        // German has no image of its own either: it shows the English one.
        let queued = Set(builder.queuedArtwork(for: "winter", in: queue.changes).map(\.locale))
        #expect(queued == ["en-US"])
        #expect(flow.run.queuedChangeIDs.count == 2)
    }
}
