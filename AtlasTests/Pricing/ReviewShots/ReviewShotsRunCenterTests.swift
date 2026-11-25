//
//  ReviewShotsRunCenterTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Make Review Screenshots… runs: the steps the assistant reports, the
/// images that arrive, why it stops, and what the toolbar and the Autopilot
/// menu say about it.
@MainActor
@Suite("ReviewShotsRunCenter")
struct ReviewShotsRunCenterTests {
    private let appID = "app1"
    private let products: [ReviewShotsRun.Product] = [
        .init(productID: "monthly", plan: "Monthly"), .init(productID: "annual", plan: "Annual"), .init(productID: "lifetime", plan: "Lifetime"),
    ]

    @Test func itFollowsEachProductInTurn() throws {
        let center = ReviewShotsRunCenter()
        center.start(appID: appID, client: "Claude Code", products: products)
        #expect(center.run(for: appID)?.toolbarText == "Making review screenshots")
        #expect(center.run(for: appID)?.isCapturing("monthly") == true, "The first one is on its way before any report")
        #expect(center.run(for: appID)?.isQueued("monthly") == false)
        #expect(center.menuNote(for: appID).text == "Running")
        #expect(!center.menuNote(for: appID).isEnabled)

        center.report(appID: appID, productID: "monthly", step: "Opened Lumen in Simulator · iPhone 17 Pro")
        center.report(appID: appID, productID: "monthly", step: "Opened the paywall from Settings → Lumen Plus")
        center.arrived(appID: appID, productID: "monthly")
        center.report(appID: appID, productID: "annual", step: "Selecting Annual and waiting for its price")

        let run = try #require(center.run(for: appID))
        #expect(run.steps == ["Opened Lumen in Simulator · iPhone 17 Pro"])
        #expect(run.step == "Selecting Annual and waiting for its price")
        #expect(run.toolbarText == "Capturing Annual · 2 of 3")
        #expect(run.menuText == "Making review screenshots · capturing Annual, 2 of 3")
        #expect(run.fraction == 0.5, "Halfway through the second of three")
        #expect(run.isQueued("lifetime"))
        #expect(!run.isQueued("annual"))
        #expect(!run.isQueued("monthly"))
        #expect(run.queuedText(for: "lifetime") == "Claude Code captures Lifetime after Annual.")
    }

    @Test func aRunThatStopsWaitsForThePerson() {
        let center = ReviewShotsRunCenter()
        center.start(appID: appID, client: "Claude Code", products: products)
        center.fail(appID: appID, .paywallNotFound(tried: "Settings and the + button"))
        #expect(center.run(for: appID)?.needs == "Show It the Paywall")
        #expect(center.workingRun(for: appID) == nil)
        center.runEnded(appID: appID)
        #expect(center.run(for: appID) != nil, "It stays until Not Now or Try Again")

        center.fail(appID: appID, .noPrices(saw: ""))
        #expect(center.run(for: appID)?.needs == "Choose How to Continue")
        center.clear(appID: appID)
        #expect(center.run(for: appID) == nil)
    }

    @Test func whatArrivedIsReadyUntilAccepted() {
        let center = ReviewShotsRunCenter()
        center.start(appID: appID, client: "Claude Code", products: products)
        center.arrived(appID: appID, productID: "monthly")
        center.runEnded(appID: appID)
        #expect(center.run(for: appID)?.phase == .ready)
        #expect(center.run(for: appID)?.needs == nil, "Ready isn't purple: the toolbar's green check says it, then rests")
        #expect(center.run(for: appID)?.readyText == "Review Screenshots Ready")
        center.settle(appID: appID, suggestionsLeft: 1)
        #expect(center.run(for: appID) != nil)
        center.settle(appID: appID, suggestionsLeft: 0)
        #expect(center.run(for: appID) == nil)

        center.start(appID: appID, client: "Claude Code", products: products)
        center.runEnded(appID: appID)
        #expect(center.run(for: appID) == nil, "Nothing arrived: nothing to show")
    }

    /// The toast at the end says what it made: Bruma's first live run
    /// (2026-11-23) stopped without a capture, and the toast said “The
    /// review screenshots wait in Pricing.”
    @Test func theEndingSaysWhatItMade() {
        let center = ReviewShotsRunCenter()
        center.start(appID: appID, client: "Claude Code", products: products)
        #expect(center.runEnded(appID: appID) == "Claude Code made no review screenshots.")

        center.start(appID: appID, client: "Claude Code", products: products)
        center.report(appID: appID, productID: nil, step: "Stopped: xcodebuild was refused")
        #expect(center.runEnded(appID: appID) == "Claude Code made no review screenshots. Its last step: Stopped: xcodebuild was refused")

        center.start(appID: appID, client: "Claude Code", products: products)
        center.arrived(appID: appID, productID: "monthly")
        #expect(center.runEnded(appID: appID) == "Claude Code made 1 of 3 review screenshots. What it made waits in Pricing.")

        center.start(appID: appID, client: "Claude Code", products: products)
        for product in products { center.arrived(appID: appID, productID: product.productID) }
        #expect(center.runEnded(appID: appID) == nil, "All of them: the ask's own “they wait in Pricing”")

        center.start(appID: appID, client: "Claude Code", products: products)
        center.fail(appID: appID, .paywallNotFound(tried: ""))
        #expect(center.runEnded(appID: appID) == "Claude Code stopped before the review screenshots. Pricing says why.")
    }

    /// A product the paywall doesn't show is skipped, one whose checks
    /// failed twice too: the run moves on, and the card says why until the
    /// next run.
    @Test func skippedProductsMoveTheRunOnAndStayOnTheirCards() throws {
        let center = ReviewShotsRunCenter()
        center.start(appID: appID, client: "Claude Code", products: products)
        center.report(appID: appID, productID: "monthly", step: "Selecting Monthly")
        center.miss(appID: appID, productID: "monthly", kind: .skipped, reason: "The paywall shows only Annual")
        let run = try #require(center.run(for: appID))
        #expect(run.currentProduct?.productID == "annual")
        #expect(run.current == nil)
        #expect(run.fraction == 1.0 / 3.0)
        #expect(!run.isQueued("monthly"))
        let skipped = ReviewShotsMiss(kind: .skipped, reason: "The paywall shows only Annual", client: "Claude Code")
        #expect(center.miss(appID: appID, productID: "monthly") == skipped)

        center.miss(appID: appID, productID: "annual", kind: .checkFailed, reason: "the price didn’t show")
        center.arrived(appID: appID, productID: "lifetime")
        center.runEnded(appID: appID)
        #expect(center.miss(appID: appID, productID: "annual")?.kind == .checkFailed, "Kept after the run")
        center.forgetMiss(appID: appID, productID: "annual")
        #expect(center.miss(appID: appID, productID: "annual") == nil)

        center.start(appID: appID, client: "Claude Code", products: products)
        #expect(center.miss(appID: appID, productID: "monthly") == nil, "A new run starts clean")
    }

    @Test func noPricesKeepsWhatItSaw() {
        let center = ReviewShotsRunCenter()
        center.start(appID: appID, client: "Claude Code", products: products)
        let image = URL(filePath: "/tmp/no-prices.png")
        center.fail(appID: appID, .noPrices(saw: "Empty plans"), sawImage: image)
        #expect(center.run(for: appID)?.sawImage == image)
        #expect(center.run(for: appID)?.phase == .noPrices(saw: "Empty plans"))
    }

    @Test func aPushIsAnnouncedOnceAndOnlyFromThisLaunch() {
        let launch = Date(timeIntervalSince1970: 1000)
        let center = ReviewShotsRunCenter(since: launch)
        let before = PushRecord(date: launch.addingTimeInterval(-60), appID: appID, appName: "Lumen", title: "", pushed: [])
        let after = PushRecord(date: launch.addingTimeInterval(60), appID: appID, appName: "Lumen", title: "", pushed: [])
        #expect(!center.needsAnnouncing(before), "An earlier launch's push")
        #expect(center.needsAnnouncing(after))
        center.markAnnounced([after.id])
        #expect(!center.needsAnnouncing(after))
    }

    @Test func theMenuSaysHowManyAreMissing() {
        let center = ReviewShotsRunCenter()
        #expect(center.menuNote(for: appID).text == nil)
        center.setMissing(3, for: appID)
        #expect(center.menuNote(for: appID) == ("3 missing", true))
        center.setMissing(0, for: appID)
        #expect(center.menuNote(for: appID) == ("All set", false))
    }

    @Test func whereThePaywallIsIsKept() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReviewShotsRunCenterTests"))
        defaults.removePersistentDomain(forName: "ReviewShotsRunCenterTests")
        ReviewShotsRunCenter(defaults: defaults).setRoute("  Settings → Lumen Plus ", for: appID)
        #expect(ReviewShotsRunCenter(defaults: defaults).routes[appID] == "Settings → Lumen Plus")
        ReviewShotsRunCenter(defaults: defaults).setRoute("", for: appID)
        #expect(ReviewShotsRunCenter(defaults: defaults).routes[appID] == nil)
        defaults.removePersistentDomain(forName: "ReviewShotsRunCenterTests")
    }
}
#endif
