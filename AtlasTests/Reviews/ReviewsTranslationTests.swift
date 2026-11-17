//
//  ReviewsTranslationTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Reviews read in the app's language: translated once on this Mac, with
/// Show Original for one review and a switch for all.
@MainActor
@Suite("Reviews · translation")
struct ReviewsTranslationTests {
    typealias Data = ReviewsTestData

    private func makeModel(_ services: FakeReviewsServices = FakeReviewsServices()) -> ReviewsViewModel {
        ReviewsViewModel(app: Data.app, store: Data.store(), services: services)
    }

    @Test func reviewsInAnotherLanguageAreTranslatedOnceAndKept() async {
        let model = makeModel()
        await model.translate()
        let translations = model.archive.translations
        #expect(translations.keys.sorted() == ["de1", "de2", "fr1", "jp1"])
        #expect(translations["de1"]?.title == "[de→en] Title de1")
        let text = model.displayText(for: Data.reviews[0])
        #expect(text.isTranslated)
        #expect(text.title == "[de→en] Title de1")
        #expect(text.note == "Translated from German")
        #expect(text.toggleTitle == "Show Original")
    }

    @Test func aReviewInTheAppsLanguageIsShownAsWritten() async {
        let model = makeModel()
        await model.translate()
        let text = model.displayText(for: Data.reviews[3])
        #expect(!text.isTranslated)
        #expect(text.note == nil)
        #expect(text.toggleTitle == nil)
    }

    @Test func showOriginalSwitchesOneReviewAndTheSwitchAllOfThem() async {
        let model = makeModel()
        await model.translate()
        let german = Data.reviews[0]
        model.toggleTranslation(german)
        #expect(model.displayText(for: german).title == "Title de1")
        #expect(model.displayText(for: german).note == "Original, in German")
        #expect(model.displayText(for: german).toggleTitle == "Show Translation")
        #expect(model.displayText(for: Data.reviews[2]).isTranslated)
        model.setTranslates(false)
        #expect(!model.displayText(for: Data.reviews[2]).isTranslated)
        // The switch starts every review from the same place again.
        #expect(model.translationOverrides.isEmpty)
    }

    @Test func aLanguageThatNeedsADownloadIsAskedFor() async {
        let services = FakeReviewsServices()
        services.translator = FakeReviewTranslator(needsDownload: ["ja"], unsupported: ["fr"])
        let model = makeModel(services)
        await model.translate()
        #expect(model.languagesToDownload == ["ja"])
        #expect(model.downloadText == "Apple Translation needs to download Japanese before those reviews can be translated.")
        #expect(model.archive.translations.keys.sorted() == ["de1", "de2"])
        // Without a translation there's nothing to switch to.
        #expect(model.displayText(for: Data.reviews[2]).toggleTitle == nil)
    }
}
