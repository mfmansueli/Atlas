//
//  LanguageBarModelTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The language bar over the Store Page and Screenshots: the language in
/// view and its count, the rest elsewhere, the arrows, and the menu rows.
@Suite("Language bar")
struct LanguageBarModelTests {
    private let japanese = StoreLocale.japanese
    private let french = StoreLocale.french

    private func model(current: StoreLocale, acceptsRightAway: Bool = false) -> LanguageBarModel {
        LanguageBarModel(
            entries: [
                LanguageBarEntry(locale: .englishUS, count: 5),
                LanguageBarEntry(locale: .german, count: 0),
                LanguageBarEntry(locale: french, count: 3),
                LanguageBarEntry(locale: japanese, count: 0),
            ],
            current: current,
            acceptsRightAway: acceptsRightAway
        )
    }

    @Test func theLanguageInViewAndTheRest() {
        let bar = model(current: .englishUS)
        #expect(bar.hereText == "5 suggestions here")
        #expect(bar.restText == "3 more in 1 other language")
        #expect(bar.totalCount == 8)
        #expect(bar.acceptHereTitle == "Accept 5 in English")
        #expect(bar.acceptAllTitle == "Accept All Languages")
        #expect(bar.withSuggestions.map(\.locale) == [.englishUS, french])
        #expect(bar.upToDate.map(\.locale) == [.german, japanese])
    }

    @Test func theArrowsSkipLanguagesWithNothingAndWrapAround() {
        #expect(model(current: .englishUS).next == french)
        #expect(model(current: .englishUS).previous == french)
        #expect(model(current: .german).next == french)
        #expect(model(current: .german).previous == .englishUS)
        #expect(model(current: japanese).next == .englishUS)
    }

    @Test func aLanguageWithNothingToReview() {
        let bar = model(current: .german)
        #expect(bar.hereText == "Nothing to review here")
        #expect(bar.restText == "8 more in 2 other languages")
    }

    @Test func everythingReviewed() {
        let bar = LanguageBarModel(entries: [LanguageBarEntry(locale: .englishUS, count: 0)], current: .englishUS)
        #expect(bar.acceptAllTitle == "All Languages Reviewed")
        #expect(bar.restText.isEmpty, "The button says it; the bar doesn't repeat it")
        #expect(bar.acceptAllAccessibilityText == "Every language is reviewed")
        #expect(bar.next == nil)
    }

    @Test func acceptingRightAwayIsSaid() {
        let bar = model(current: .englishUS, acceptsRightAway: true)
        #expect(bar.menuAcceptAllTitle == "Accept All Languages")
        #expect(bar.acceptAllAccessibilityText == "Accept all languages: 8 suggestions in 2 languages, accepts right away")
        #expect(model(current: .englishUS).menuAcceptAllTitle == "Accept All Languages…")
    }

    @Test func findALanguageMatchesNamesRegionsAndCodes() {
        let bar = model(current: .englishUS)
        #expect(bar.matchingEntries("").count == 4)
        #expect(bar.matchingEntries("  ").count == 4)
        #expect(bar.matchingEntries("fren").map(\.locale) == [french])
        #expect(bar.matchingEntries("Japanese").map(\.locale) == [japanese])
        #expect(bar.matchingEntries("de").map(\.locale) == [.german])
        #expect(bar.matchingEntries("en").map(\.locale) == [.englishUS, french])
        #expect(bar.matchingEntries("zz").isEmpty)
    }

    @Test func theMenuCountsEveryLanguage() {
        #expect(model(current: .englishUS).countText == "4 languages")
    }

    @Test func aMenuRowReadsItsCountAndANewPage() {
        let entry = LanguageBarEntry(locale: .german, count: 5, comingCount: 2, isNewPage: true)
        #expect(entry.accessibilityText == "German, 5 suggestions to review, 2 coming, not on the App Store yet")
        #expect(LanguageBarEntry(locale: .german, count: 1).accessibilityText == "German, 1 suggestion to review")
    }

    @Test func aMenuRowSaysItsNote() {
        let entry = LanguageBarEntry(locale: .german, count: 0, note: "Not pushed")
        #expect(entry.accessibilityText == "German, nothing to review, Not pushed")
        #expect(entry.accessibilityText(countsSuggestions: false) == "German, Not pushed")
    }

    /// "Accept 5 in English": the language, never a region alone ("U.K.").
    @Test func theShortNameIsTheLanguage() {
        #expect(LanguageBarModel.shortName(.englishUS) == "English")
        #expect(LanguageBarModel.shortName(.englishUK) == "English")
        #expect(LanguageBarModel.shortName(.german) == "German")
    }

    // MARK: - The menu (README-DS §12)

    @Test func theMenuGroupsSuggestionsFirstThenUpToDate() {
        let groups = model(current: .englishUS).menuGroups(matching: "")
        #expect(groups.map(\.kind) == [.toReview, .upToDate])
        #expect(groups.map(\.title) == ["Suggestions to review", "Up to date"])
        #expect(groups[0].entries.map(\.locale) == [.englishUS, french])
        #expect(groups[1].entries.map(\.locale) == [.german, japanese])
    }

    @Test func typingKeepsTheGroupsAndDropsTheEmptyOnes() {
        let bar = model(current: .englishUS)
        #expect(bar.menuGroups(matching: "ja").map(\.kind) == [.upToDate])
        #expect(bar.menuGroups(matching: "en").map(\.kind) == [.toReview])
        #expect(bar.menuGroups(matching: "zz").isEmpty, "The menu then says No language matches")
    }

    /// Screenshots: languages that reuse the primary set are listed last.
    @Test func languagesThatUseThePrimarySetAreListedLast() {
        var bar = LanguageBarModel(
            entries: [
                LanguageBarEntry(locale: .englishUS, count: 0),
                LanguageBarEntry(locale: .german, count: 2, usesPrimary: true),
                LanguageBarEntry(locale: french, count: 0, usesPrimary: true),
                LanguageBarEntry(locale: japanese, count: 0),
            ],
            current: .englishUS,
            reuseGroupTitle: "Uses English (U.S.) screenshots"
        )
        let groups = bar.menuGroups(matching: "")
        #expect(groups.map(\.title) == ["Suggestions to review", "Up to date", "Uses English (U.S.) screenshots"])
        // A suggestion comes first, whatever the language shows.
        #expect(groups[0].entries.map(\.locale) == [.german])
        #expect(groups[1].entries.map(\.locale) == [.englishUS, japanese])
        #expect(groups[2].entries.map(\.locale) == [french])
        // Without a title for them, they stay under Up to date.
        bar.reuseGroupTitle = nil
        #expect(bar.menuGroups(matching: "").map(\.kind) == [.toReview, .upToDate])
    }

    @Test func aSwitchWithNothingToReviewIsOneList() throws {
        let bar = try #require(LanguageBarModel.plain(codes: ["en-US", "de-DE", "ja"], current: "de-DE"))
        #expect(bar.current == .german)
        #expect(!bar.countsSuggestions)
        let groups = bar.menuGroups(matching: "")
        #expect(groups.map(\.kind) == [.all])
        #expect(groups[0].title == nil)
        #expect(groups[0].entries.count == 3)
        #expect(bar.pickerAccessibilityText == "Language: German. Choose another language.")
        // One language: nothing to switch.
        #expect(LanguageBarModel.plain(codes: ["en-US"], current: "en-US") == nil)
        // An unknown current one shows the first.
        #expect(LanguageBarModel.plain(codes: ["en-US", "de-DE"], current: "xx")?.current == .englishUS)
    }

    /// In-App Events and Product Pages accept at once, with Undo.
    @Test func acceptAllThatNeverAsksHasNoEllipsisNorAcceptsRightAwayLine() {
        var bar = model(current: .englishUS)
        bar.acceptAllShowsSuggestionsFirst = false
        #expect(bar.menuAcceptAllTitle == "Accept All Languages")
        #expect(!bar.showsAcceptsRightAway)
        #expect(bar.acceptAllAccessibilityText.hasSuffix("accepts right away"))
        bar.acceptsRightAway = true
        #expect(!bar.showsAcceptsRightAway)
        #expect(model(current: .englishUS, acceptsRightAway: true).showsAcceptsRightAway)
        #expect(!model(current: .englishUS).showsAcceptsRightAway)
    }

    // MARK: - Pickers elsewhere

    /// Overview's App Store preview: the primary first, the counts of
    /// the Store Page's suggestions.
    @Test func theStorePreviewPickerListsThePrimaryFirst() {
        let bar = LanguageBarModel.storePreview(
            locales: [.german, .englishUS, french], primary: .englishUS, current: french, counts: ["fr-FR": 3]
        )
        #expect(bar.entries.map(\.locale) == [.englishUS, .german, french])
        #expect(bar.current == french)
        #expect(bar.hereText == "3 suggestions here")
        #expect(bar.countsSuggestions)
    }

    @Test func theRetentionPickerSaysWhichRunTooLong() throws {
        let bar = try #require(LanguageBarModel.retention(languages: [.englishUS, .german], selectedCode: "de-DE", tooLong: ["de-DE"]))
        #expect(bar.current == .german)
        #expect(!bar.countsSuggestions)
        #expect(bar.entries.map(\.note) == [nil, "Too long"])
        #expect(LanguageBarModel.retention(languages: [], selectedCode: "en-US", tooLong: []) == nil)
    }
}
