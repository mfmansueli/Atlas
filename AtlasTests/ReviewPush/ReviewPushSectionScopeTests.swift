//
//  ReviewPushSectionScopeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Board 57: the toolbar's “N not pushed” opens Review & Push on that
/// section's changes, with the switch to the app's and every app's, and
/// the push takes only what's shown.
@MainActor
@Suite("ReviewPushViewModel · one section")
struct ReviewPushSectionScopeTests {
    typealias Sample = DebugProductPagesData
    typealias PageID = DebugProductPagesData.PageID

    private let appID = DebugProductPagesData.appID
    private let builder = ProductPageChangeBuilder(appID: DebugProductPagesData.appID)

    private func makeViewModel(_ queue: ChangeQueue) -> ReviewPushViewModel {
        ReviewPushViewModel(
            queue: queue,
            push: PushController(queue: queue, history: PushHistory(), transport: FakePushTransport(), secrets: InMemorySecretStore()),
            selectedAppID: appID,
            appName: { _ in "Lumen Journal" }
        )
    }

    /// Two product page changes and a price.
    private func queue() throws -> ChangeQueue {
        let mood = try #require(Sample.snapshot.pages.first { $0.id == PageID.mood })
        let sleep = try #require(Sample.snapshot.pages.first { $0.id == PageID.sleep })
        let changes = try [
            #require(builder.textChange("Track how you feel.", locale: "en-US", of: mood, source: .you)),
            #require(builder.nameChange("Sleep better", of: sleep, source: .you)),
            PushFixtures.price("BRA", app: appID),
        ]
        return ChangeQueue(changes: changes)
    }

    @Test func itOpensOnTheSectionsChangesOnly() throws {
        let vm = try makeViewModel(queue())
        vm.focus(on: .productPages)
        #expect(vm.scope == .section(.productPages))
        #expect(vm.sectionCount == 2)
        #expect(vm.visibleChanges.count == 2)
        #expect(vm.visibleChanges.allSatisfy { $0.section == .productPages })
        #expect(vm.pushableChanges.count == 2)
        #expect(vm.showsScopeSwitch)
        // Screenshots' images and extras belong to Screenshots.
        #expect(vm.screenshotPlans.isEmpty)
        #expect(vm.extrasPlans.isEmpty)

        vm.scope = .thisApp
        #expect(vm.visibleChanges.count == 3)
    }

    @Test func aSectionWithNothingQueuedOpensOnTheApp() throws {
        let vm = try makeViewModel(queue())
        vm.focus(on: .storePage)
        #expect(vm.scope == .thisApp)
        #expect(vm.sectionCount == 0)
    }

    @Test func onlyTheSectionHasChangesSoThereIsNoSwitch() {
        let vm = makeViewModel(ChangeQueue(changes: [PushFixtures.price("BRA", app: appID)]))
        vm.focus(on: .subscriptionPricing)
        #expect(vm.scope == .section(.subscriptionPricing))
        #expect(!vm.showsScopeSwitch)
    }

    @Test func thePushSaysWhereFrom() {
        #expect(ReviewPushViewModel.pushTitle(3, from: .storePage) == "Push 3 from Store Page…")
        #expect(ReviewPushViewModel.pushTitle(1, from: .subscriptionPricing) == "Push 1 from Subscription Pricing…")
    }

    @Test func theNavigatorOpensOnTheSectionUntilItCloses() throws {
        let navigator = WorkspaceNavigator()
        navigator.review(section: .productPages)
        #expect(navigator.isReviewPresented)
        let vm = try makeViewModel(queue())
        navigator.configure(vm)
        #expect(vm.scope == .section(.productPages))

        navigator.reviewDidClose()
        let next = try makeViewModel(queue())
        navigator.configure(next)
        #expect(next.scope == .thisApp)
    }
}
