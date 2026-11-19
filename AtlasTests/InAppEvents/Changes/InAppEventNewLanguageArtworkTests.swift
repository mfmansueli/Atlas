//
//  InAppEventNewLanguageArtworkTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An event's card and details page go into every language, the ones its
/// queued texts create too: those name the language by its locale until
/// the push has created it, a language queued after the art gets it, one
/// taken out of the queue takes its images along, and the uploads go after
/// everything else.
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

    @Test func aNewLanguageGetsTheEventsArtAndLosesItWithItsTexts() async throws {
        let art = try await eventArt()
        let changes = try art + [texts("fr-FR")]

        let (add, discard) = builder.newLanguageArtwork(of: Events.winter, in: changes)
        #expect(discard.isEmpty)
        #expect(add.map(\.id) == [
            builder.artworkChangeID(eventID: "winter", kind: .card, locale: "fr-FR"),
            builder.artworkChangeID(eventID: "winter", kind: .details, locale: "fr-FR"),
        ])
        let card = try #require(add.first)
        #expect(localizationID(of: card) == "{eventLocalization:winter:fr-FR}")
        #expect(card.title == "\(InAppEventChangeBuilder.localeName("fr-FR")) · \(InAppEventMedia.Kind.card.title)")
        #expect(card.flagRegion == "FR")
        #expect(card.oldValue == "None")
        // The English card, as queued for the event's own language.
        #expect(card.newValue == art[0].newValue)
        #expect(card.source == .you)
        #expect(card.restoreRequests.isEmpty)

        // Queued: nothing more to add. Its texts gone: its images go too.
        #expect(builder.newLanguageArtwork(of: Events.winter, in: changes + add).add.isEmpty)
        let without = (changes + add).filter { $0.id != builder.newChangeID(eventID: "winter", locale: "fr-FR") }
        #expect(Set(builder.newLanguageArtwork(of: Events.winter, in: without).discard) == Set(add.map(\.id)))
    }

    @Test func artQueuedForTheLanguageItselfIsKept() async throws {
        let art = try await eventArt()
        let french = try await builder.artworkChange(report(.card), newLanguage: "fr-FR", of: Events.winter, source: .you)
        let (add, _) = try builder.newLanguageArtwork(of: Events.winter, in: art + [texts("fr-FR"), french])
        #expect(add.map(\.id) == [builder.artworkChangeID(eventID: "winter", kind: .details, locale: "fr-FR")])
    }

    @Test func withoutArtNothingIsAdded() throws {
        #expect(try builder.newLanguageArtwork(of: Events.winter, in: [texts("fr-FR")]).add.isEmpty)
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

    @Test func writingANewLanguageBringsTheArtAlongAndEmptyingItTakesItAway() async throws {
        let model = InAppEventsViewModel(app: Events.app, services: FakeInAppEventsServices(), store: InAppEventsStore(), queue: queue)
        await model.load()
        try await queue.upsert(contentsOf: eventArt())
        let cardID = builder.artworkChangeID(eventID: "winter", kind: .card, locale: "fr-FR")

        model.write([.name: "Réflexion d’hiver"], locale: "fr-FR", of: Events.winter, source: .you)
        let card = try #require(queue.change(id: cardID))
        #expect(localizationID(of: card) == "{eventLocalization:winter:fr-FR}")
        #expect(queue.change(id: builder.artworkChangeID(eventID: "winter", kind: .details, locale: "fr-FR")) != nil)

        model.write([.name: ""], locale: "fr-FR", of: Events.winter, source: .you)
        #expect(queue.change(id: builder.newChangeID(eventID: "winter", locale: "fr-FR")) == nil)
        #expect(queue.change(id: cardID) == nil)
    }

    @Test func useThisArtworkCoversTheLanguagesBeingCreated() async throws {
        let studio = EventArtworkStudio()
        try studio.begin(Studio.run(step: .choose, concepts: [Studio.concept("a", isPick: true, in: directory)]))
        let flow = EventArtworkFlow(app: Events.app, event: Events.winter, studio: studio, queue: queue, hasDesignSystem: true)
        flow.directory = directory
        flow.now = { Events.now }
        try queue.upsert(texts("fr-FR"))

        #expect(await flow.use("a"))
        let card = try #require(queue.change(id: builder.artworkChangeID(eventID: "winter", kind: .card, locale: "fr-FR")))
        #expect(localizationID(of: card) == "{eventLocalization:winter:fr-FR}")
        let queued = Set(builder.queuedArtwork(for: "winter", in: queue.changes).map(\.locale))
        #expect(queued == ["en-US", "de-DE", "fr-FR"])
        #expect(flow.run.queuedChangeIDs.count == 6)
    }
}
