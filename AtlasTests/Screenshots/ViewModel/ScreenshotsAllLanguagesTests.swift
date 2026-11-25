//
//  ScreenshotsAllLanguagesTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// All Languages (the canvas's `sh-all`): each language's strip shows its
/// own screenshots on the device in view, none when it uses the primary
/// language's, and VoiceOver reads the name, the state and the count.
@MainActor
@Suite("Screenshots All Languages")
struct ScreenshotsAllLanguagesTests {
    @Test func eachStripShowsTheLanguagesOwnScreenshots() async {
        let (model, _) = await ScreenshotsTestFixtures.viewModel()
        let primary = model.pageLocales.first
        #expect(primary == .englishUS)
        for locale in model.pageLocales {
            let strip = model.allLanguagesThumbnails(of: locale)
            #expect(strip.count == model.ownCount(locale: locale.code, displayType: model.displayType))
            #expect(strip.allSatisfy { !$0.isDeleted })
            #expect(strip.map(\.position) == strip.map(\.position).sorted(), "In the set's order")
            if strip.isEmpty, locale != primary, model.proposedCaptions(in: locale).isEmpty {
                #expect(model.pageStatus(of: locale) == "Uses English (U.S.)")
            }
        }
        #expect(!model.allLanguagesThumbnails(of: .englishUS).isEmpty, "The primary language has its own set")
    }

    @Test func voiceOverReadsNameStateAndCount() async {
        let (model, _) = await ScreenshotsTestFixtures.viewModel()
        let count = model.allLanguagesThumbnails(of: .german).count
        let label = model.allLanguagesAccessibilityLabel(of: .german)
        #expect(label.hasPrefix("German, 3 captions suggested"))
        if count > 1 { #expect(label.hasSuffix(", \(count) screenshots")) }
    }
}
#endif
