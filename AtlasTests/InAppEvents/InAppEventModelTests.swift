//
//  InAppEventModelTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An In-App Event as App Store Connect has it: what it still needs
/// before App Review, its status, and what Atlas keeps of the
/// suggestions for it.
@MainActor
@Suite("In-App Events · model")
struct InAppEventModelTests {
    typealias Data = InAppEventsTestData

    @Test func anEventSaysWhatItStillNeeds() {
        #expect(Data.winter.missing(now: Data.now) == ["write every language"])
        #expect(!Data.winter.canSubmit(now: Data.now))
        var bare = Data.winter
        bare.localizations = []
        bare.schedules = []
        bare.deepLink = nil
        bare.primaryLocale = nil
        bare.purpose = nil
        // Alba 1.2.0: App Store Connect refused events without a deep link.
        #expect(bare.missing(now: Data.now) == [
            "add a deep link", "choose its primary language", "choose its purpose", "set its dates", "write its primary language",
            "add the card image", "add the details image",
        ])
        #expect(bare.reviewNeeds(now: Data.now).first == .deepLink)
        #expect(!bare.canSubmit(now: Data.now))
        #expect(bare.datesText == "No dates yet")
        var noLink = Data.winter
        noLink.localizations.removeLast()
        noLink.deepLink = "  "
        #expect(noLink.missing(now: Data.now) == ["add a deep link"])
        #expect(!noLink.canSubmit(now: Data.now))
        var ready = Data.winter
        ready.localizations.removeLast()
        #expect(ready.missing(now: Data.now).isEmpty)
        #expect(ready.canSubmit(now: Data.now))
        // Complete, but already live: nothing to submit.
        #expect(!Data.update.canSubmit(now: Data.now))
    }

    @Test func theImagesOfThePrimaryLanguageAreTheEvents() {
        #expect(Data.winter.media(.card)?.sizeText == "1920 × 1080")
        #expect(Data.winter.media(.details) != nil)
        #expect(Data.winter.primaryLocalization?.locale == "en-US")
        #expect(InAppEventsViewModel.mediaText(.card, of: Data.winter) == "1920 × 1080 · for every language")
        var bare = Data.winter
        bare.localizations[0].media = []
        #expect(InAppEventsViewModel.mediaText(.card, of: bare) == "Missing · needed to submit")
    }

    @Test(arguments: [
        ("DRAFT", true, false, false), ("READY_FOR_REVIEW", true, false, false), ("REJECTED", true, false, false),
        ("WAITING_FOR_REVIEW", false, true, false), ("IN_REVIEW", false, true, false), ("APPROVED", false, true, false),
        ("PUBLISHED", false, true, false), ("PAST", false, false, true), ("ARCHIVED", false, false, true),
    ])
    func aStateSaysWhatCanBeDone(state: String, isEditable: Bool, isSubmitted: Bool, isOver: Bool) {
        let state = InAppEventState(apiValue: state)
        #expect(state.isEditable == isEditable)
        #expect(state.isSubmitted == isSubmitted)
        #expect(state.isOver == isOver)
    }

    @Test func anUnknownStateIsADraft() {
        #expect(InAppEventState(apiValue: "SOMETHING_NEW") == .draft)
        #expect(InAppEventState(apiValue: nil) == .draft)
    }

    @Test func theStatusSaysWhenAnEventGoesWithTheVersion() {
        #expect(InAppEventStatus(Data.winter, goingWithVersion: "1.4").title == "Goes with 1.4")
        #expect(InAppEventStatus(Data.winter, goingWithVersion: nil).title == "Draft")
        #expect(InAppEventStatus(Data.update, goingWithVersion: "1.4").title == "On the App Store")
        #expect(InAppEventStatus(Data.gratitude, goingWithVersion: nil).title == "Ended")
    }

    @Test func theLimitsAreApples() {
        #expect(InAppEventField.allCases.map(\.limit) == [30, 50, 120])
        var suggestion = Data.suggestion("ja")
        #expect(suggestion.overLimit == nil)
        suggestion.shortDescription = String(repeating: "a", count: 51)
        #expect(suggestion.overLimit?.field == .shortDescription)
        #expect(suggestion.overLimit?.count == 51)
    }

    @Test func aNewSuggestionReplacesTheOneForItsLanguageAndComesBackFromDismissed() {
        let store = InAppEventsStore()
        store.add([Data.suggestion("ja", name: "One"), Data.suggestion("ko")], for: Data.app.id)
        store.dismiss("winter.ja", for: Data.app.id)
        #expect(store.count(for: Data.app.id) == 1)
        store.add([Data.suggestion("ja", name: "Two")], for: Data.app.id)
        #expect(store.count(for: Data.app.id) == 2)
        #expect(store.suggestion(for: Data.app.id, eventID: "winter", locale: "ja")?.name == "Two")
        // An event that's gone takes its suggestions with it.
        store.prune(for: Data.app.id, keeping: ["other"])
        #expect(store.count(for: Data.app.id) == 0)
    }

    @Test func suggestionsAreKeptOnDisk() {
        let directory = FileManager.default.temporaryDirectory.appending(path: "InAppEventsStoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = InAppEventsStore(directory: directory)
        store.add([Data.suggestion("ja"), Data.suggestion("ko")], for: Data.app.id)
        store.dismiss("winter.ko", for: Data.app.id)
        let reopened = InAppEventsStore(directory: directory)
        #expect(reopened.open(for: Data.app.id).map(\.locale) == ["ja"])
        #expect(reopened.archive(for: Data.app.id).suggestions.count == 2)
    }

    @Test func theChangesOfAnEventAreFoundByTheirIDs() throws {
        let builder = InAppEventChangeBuilder(appID: Data.app.id)
        let german = try #require(Data.winter.localization("de-DE"))
        let field = try #require(builder.fieldChange(.name, to: "Winter", in: german, of: Data.winter, source: .you))
        let new = try #require(builder.newLanguageChange([.name: "冬", .shortDescription: ""], locale: "ja", of: Data.winter, source: .you))
        #expect(builder.owns(field))
        #expect(!builder.isNewEvent(field))
        #expect(field.group == "In-App Events · Winter Reflection 2026")
        #expect(field.conflictCheck?.expected == "Winter-Reflexion")
        #expect(new.title == "Japanese · Event Name")
        let drafts = builder.drafts(for: "winter", in: [field, new])
        #expect(drafts["de-DE"] == [.name: "Winter"])
        #expect(drafts["ja"] == [.name: "冬"])
        #expect(builder.drafts(for: "other", in: [field, new]).isEmpty)
        // Nothing changed, nothing to push.
        #expect(builder.fieldChange(.name, to: "Winter-Reflexion", in: german, of: Data.winter, source: .you) == nil)
        #expect(builder.newLanguageChange([.name: ""], locale: "ja", of: Data.winter, source: .you) == nil)
    }
}
