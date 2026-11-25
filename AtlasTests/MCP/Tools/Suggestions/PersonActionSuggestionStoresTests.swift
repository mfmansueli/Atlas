//
//  PersonActionSuggestionStoresTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The suggestions an assistant leaves for actions only the person takes
/// (deleting library files, submitting an event, a product page's review
/// step, Billing Grace Period): one per app or page, a newer one replaces
/// it, and doing the action clears it.
@MainActor
@Suite("Suggestions for person-only actions")
struct PersonActionSuggestionStoresTests {
    private let app = "6450000001"

    @Test func aCleanupSuggestionLosesTheFilesThePersonDeleted() {
        let store = AssetLibraryCleanupStore()
        store.suggest(AssetLibraryCleanupSuggestion(appID: app, fileIDs: ["a", "b", "c"], why: "3 files on no page.", client: "Claude Code"))
        store.noteDeleted(["a"], appID: app)
        #expect(store.suggestion(for: app)?.fileIDs == ["b", "c"])
        store.noteDeleted(["b", "c"], appID: app)
        #expect(store.suggestion(for: app) == nil)
    }

    @Test func aNewerCleanupSuggestionReplacesTheOlderOne() {
        let store = AssetLibraryCleanupStore()
        store.suggest(AssetLibraryCleanupSuggestion(appID: app, fileIDs: ["a"], why: "One.", client: "Claude Code"))
        store.suggest(AssetLibraryCleanupSuggestion(appID: app, fileIDs: ["b"], why: "Two.", client: "Claude Code"))
        #expect(store.suggestion(for: app)?.fileIDs == ["b"])
        store.remove(for: app)
        #expect(store.suggestion(for: app) == nil)
    }

    @Test func anEventSubmitSuggestionIsKeptPerEvent() {
        let store = InAppEventSubmitSuggestionStore()
        store.suggest(InAppEventSubmitSuggestion(appID: app, eventID: "e1", why: "Starts in 5 days.", client: "Claude Code"))
        #expect(store.suggestion(for: app, eventID: "e1") != nil)
        #expect(store.suggestion(for: app, eventID: "e2") == nil)
        store.remove(for: app, eventID: "e1")
        #expect(store.suggestion(for: app, eventID: "e1") == nil)
    }

    @Test func aPageSuggestionClearsOnlyWhenItsActionIsDone() {
        let store = ProductPageReviewSuggestionStore()
        store.suggest(ProductPageReviewSuggestion(appID: app, pageID: "p1", action: .submit, why: "Ready since Monday.", client: "Claude Code"))
        store.done(.newVersion, appID: app, pageID: "p1")
        #expect(store.suggestion(for: app, pageID: "p1")?.action == .submit)
        store.done(.submit, appID: app, pageID: "p1")
        #expect(store.suggestion(for: app, pageID: "p1") == nil)
    }

    @Test func eachPageActionHasTheButtonThePersonPresses() {
        #expect(ProductPageReviewAction.submit.buttonTitle == "Submit for Review…")
        #expect(ProductPageReviewAction.cancelSubmission.buttonTitle == "Cancel Submission")
        #expect(ProductPageReviewAction.newVersion.buttonTitle == "Edit…")
    }

    @Test func aGracePeriodSuggestionIsKeptPerApp() {
        let store = GracePeriodSuggestionStore()
        store.suggest(GracePeriodSuggestion(appID: app, duration: .sixteenDays, why: "41 left over failed charges.", client: "Claude Code"))
        #expect(store.suggestion(for: app)?.duration == .sixteenDays)
        store.remove(for: app)
        #expect(store.suggestion(for: app) == nil)
    }
}
