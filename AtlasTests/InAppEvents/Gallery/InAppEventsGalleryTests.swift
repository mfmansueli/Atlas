//
//  InAppEventsGalleryTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The gallery and the event's page (board 40): opening an event and
/// going back, the tile's note, and the texts the preview shows in each
/// language.
@MainActor
@Suite("In-App Events gallery")
struct InAppEventsGalleryTests {
    typealias Data = InAppEventsTestData
    typealias Test = EventArtworkStudioTestData

    private let queue = ChangeQueue()
    private let store = InAppEventsStore()
    private let studio = EventArtworkStudio()
    private let directory = EventArtworkTestFiles.directory()

    private func makeModel() async -> InAppEventsViewModel {
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices(), store: store, queue: queue)
        model.now = { Data.now }
        model.pageLocales = ["en-US", "de-DE", "ja", "pt-BR"]
        model.artworkStudio = studio
        await model.load()
        return model
    }

    @Test func aTileOpensTheEventsPageAndEventsGoesBack() async {
        let model = await makeModel()
        #expect(!model.showsEvent)
        model.previewKind = .details
        model.isSwitchMenuShown = true
        model.open("gratitude")
        #expect(model.showsEvent)
        #expect(model.selectedEvent?.id == "gratitude")
        #expect(model.previewKind == .card)
        #expect(!model.isSwitchMenuShown)
        model.showGallery()
        #expect(!model.showsEvent)
        model.open("nothing")
        #expect(!model.showsEvent)
    }

    @Test func aDraftsNoteSaysWhatItStillNeeds() async throws {
        store.add([Data.suggestion("ja"), Data.suggestion("ko")], for: Data.app.id)
        let model = await makeModel()
        #expect(model.tileNote(of: Data.winter) == InAppEventTileNote(text: "2 languages suggested", tone: .suggestion))
        try studio.begin(Test.run(step: .making, concepts: [Test.concept("a", in: directory)]))
        #expect(model.tileNote(of: Data.winter).text == "Drawing · 1 of 3 ready · 2 languages suggested")
        studio.update(Test.key) { $0.step = .choose }
        #expect(model.readyConcepts(of: Data.winter) == 1)
        #expect(model.tileNote(of: Data.winter).text == "1 concept to choose from · 2 languages suggested")
    }

    @Test func otherEventsSayHowTheyWent() async {
        let model = await makeModel()
        #expect(model.tileNote(of: Data.gratitude) == InAppEventTileNote(text: "1 language", tone: .secondary))
        #expect(model.readyConcepts(of: Data.gratitude) == nil)
    }

    @Test func aMissingImageAloneIsAmber() {
        let warning = InAppEventTileNote.make([.init(text: "Event details image missing", isWarning: true)], done: "Ready to submit")
        #expect(warning.tone == .warning)
        let both = InAppEventTileNote.make(
            [.init(text: "Event details image missing", isWarning: true), .init(text: "9 languages suggested")], done: "Ready to submit"
        )
        #expect(both == InAppEventTileNote(text: "Event details image missing · 9 languages suggested", tone: .suggestion))
        #expect(InAppEventTileNote.make([], done: "Ready to submit") == InAppEventTileNote(text: "Ready to submit", tone: .secondary))
    }

    @Test func thePreviewShowsEachLanguagesText() async {
        store.add([Data.suggestion("ja", name: "冬の振り返り"), Data.suggestion("ar-SA", name: "الشتاء")], for: Data.app.id)
        let model = await makeModel()
        let english = model.shownTexts(of: Data.winter, locale: "en-US")
        #expect(english.origin == .own)
        #expect(english.name == "Winter Reflection Challenge")
        let japanese = model.shownTexts(of: Data.winter, locale: "ja")
        #expect(japanese.origin == .suggestion)
        #expect(japanese.name == "冬の振り返り")
        #expect(model.shownTexts(of: Data.winter, locale: "ar-SA").isRightToLeft)
        // Not written yet: the English, which people there see.
        let portuguese = model.shownTexts(of: Data.winter, locale: "pt-BR")
        #expect(portuguese.origin == .fallback)
        #expect(portuguese.shortDescription == "31 prompts to close the year gently")
        // German has its name only: the rest is the English.
        let german = model.shownTexts(of: Data.winter, locale: "de-DE")
        #expect(german.name == "Winter-Reflexion")
        #expect(german.shortDescription == "31 prompts to close the year gently")
    }
}
