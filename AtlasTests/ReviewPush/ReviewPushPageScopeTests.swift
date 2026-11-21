//
//  ReviewPushPageScopeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 54: Push and Submit… opens Review & Push on one custom product
/// page's changes, with the switch to the app's and every app's.
@MainActor
@Suite("ReviewPushViewModel · one product page")
struct ReviewPushPageScopeTests {
    typealias Sample = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID

    private let appID = DebugProductPagesData.appID
    private let builder = ProductPageChangeBuilder(appID: DebugProductPagesData.appID)

    private func page(_ id: String) throws -> ProductPage {
        try #require(Sample.snapshot.pages.first { $0.id == id })
    }

    private func makeViewModel(_ queue: ChangeQueue) -> ReviewPushViewModel {
        ReviewPushViewModel(
            queue: queue,
            push: PushController(queue: queue, history: PushHistory(), transport: FakePushTransport(), secrets: InMemorySecretStore()),
            selectedAppID: appID,
            appName: { _ in "Lumen Journal" }
        )
    }

    /// Mood's promotional text, Sleep's name and a price of the app.
    private func queue() throws -> ChangeQueue {
        let mood = try page(PageID.mood)
        let sleep = try page(PageID.sleep)
        let changes = try [
            #require(builder.textChange("Track how you feel.", locale: "en-US", of: mood, source: .you)),
            #require(builder.nameChange("Sleep better", of: sleep, source: .you)),
            PushFixtures.price("BRA", app: appID),
        ]
        return ChangeQueue(changes: changes)
    }

    @Test func itOpensOnThePagesChangesOnly() throws {
        let vm = try makeViewModel(queue())
        vm.focus(on: ReviewPageFocus(appID: appID, pageID: PageID.mood, name: "Mood"))
        #expect(vm.scope == .productPage(PageID.mood))
        #expect(vm.visibleChanges.map(\.groupID) == [PageID.mood])
        #expect(vm.pageCount == 1)
        #expect(vm.thisAppCount == 3)
        #expect(vm.showsScopeSwitch)
        #expect(vm.screenshotPlans.isEmpty)
        #expect(vm.extrasPlans.isEmpty)

        vm.scope = .thisApp
        #expect(vm.visibleChanges.count == 3)
    }

    @Test func aDraftsChangesAreItsOwnToo() {
        let queue = ChangeQueue(changes: Sample.pendingChanges)
        let vm = makeViewModel(queue)
        vm.focus(on: ReviewPageFocus(appID: appID, pageID: PageID.privateDiary, name: "Private diary"))
        #expect(vm.scope == .productPage(PageID.privateDiary))
        #expect(vm.visibleChanges.count == Sample.pendingChanges.count)
        // Only the page has changes: no switch to make.
        #expect(!vm.showsScopeSwitch)
    }

    @Test func aPageWithNothingQueuedOpensOnTheApp() throws {
        let vm = try makeViewModel(queue())
        vm.focus(on: ReviewPageFocus(appID: appID, pageID: PageID.year, name: "Year"))
        #expect(vm.scope == .thisApp)
        #expect(vm.pageCount == 0)
    }

    @Test func anotherAppsPageIsIgnored() throws {
        let vm = try makeViewModel(queue())
        vm.focus(on: ReviewPageFocus(appID: "other", pageID: PageID.mood, name: "Mood"))
        #expect(vm.pageFocus == nil)
        #expect(vm.scope == .thisApp)
    }

    @Test func theNavigatorOpensOnThePageAndForgetsItWhenTheSheetCloses() throws {
        let navigator = WorkspaceNavigator()
        navigator.review(page: ReviewPageFocus(appID: appID, pageID: PageID.mood, name: "Mood"))
        #expect(navigator.isReviewPresented)
        let vm = try makeViewModel(queue())
        navigator.configure(vm)
        #expect(vm.scope == .productPage(PageID.mood))
        navigator.reviewDidClose()
        #expect(navigator.reviewPage == nil)
        let next = try makeViewModel(queue())
        navigator.configure(next)
        #expect(next.scope == .thisApp)
        #expect(next.pageFocus == nil)
    }
}
