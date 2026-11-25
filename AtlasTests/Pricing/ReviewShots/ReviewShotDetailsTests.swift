//
//  ReviewShotDetailsTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// What a waiting review screenshot says on its card and in Review & Push,
/// kept by its change's id.
@MainActor
@Suite("ReviewShotDetails")
struct ReviewShotDetailsTests {
    private let now = Date(timeIntervalSinceReferenceDate: 815_000_000)

    private var fromClaude: ReviewShotDetails {
        ReviewShotDetails(
            origin: .assistant(client: "Claude Code"), plan: "Monthly", price: "$4.99", device: "iPhone 17 Pro",
            language: "English (U.S.)", checks: ["Price shows"], madeAt: now
        )
    }

    @Test func anAssistantsImageSaysWhatItShows() {
        let details = fromClaude
        #expect(details.heading == "Review screenshot · Monthly selected")
        #expect(details.capturedLine(now: now.addingTimeInterval(5))
            == "Captured in Simulator on iPhone 17 Pro, English (U.S.), a moment ago. Monthly is selected and shows $4.99.")
        #expect(details.acceptedLine == "From Claude Code · Monthly selected · sent when you push")
        #expect(details.reviewLine(product: "Monthly") == "Monthly · Monthly selected · from Claude Code")
        #expect(details.isFromAssistant)
        #expect(details.client == "Claude Code")
    }

    @Test func aCaptureSaysWhichOne() {
        let details = ReviewShotDetails(origin: .capture(title: "Capture 14 · Paywall"))
        #expect(!details.isFromAssistant)
        #expect(details.heading == "Review screenshot")
        #expect(details.acceptedLine == "Capture 14 · Paywall from Screenshots · sent when you push")
        #expect(details.reviewLine(product: "Annual") == "Annual · Capture 14 · Paywall from Screenshots")
    }

    @Test func theStoreKeepsThemAndForgetsWhatLeftTheQueue() throws {
        let defaults = try #require(UserDefaults(suiteName: "ReviewShotDetailsTests"))
        defaults.removePersistentDomain(forName: "ReviewShotDetailsTests")
        let store = ReviewShotDetailsStore(defaults: defaults)
        store.set(fromClaude, for: "a")
        store.set(ReviewShotDetails(origin: .capture(title: "Capture 1 · Paywall")), for: "b")
        #expect(ReviewShotDetailsStore(defaults: defaults).details(for: "a") == fromClaude)

        store.prune(keeping: ["b"])
        let reread = ReviewShotDetailsStore(defaults: defaults)
        #expect(reread.details(for: "a") == nil)
        #expect(reread.details(for: "b") != nil)
        defaults.removePersistentDomain(forName: "ReviewShotDetailsTests")
    }

    /// Bruma's Monthly (2026-11-23): nothing selects it without a tap, so
    /// its image shows Monthly and its price with Annual selected.
    @Test func anotherPlanSelectedIsSaidPlainly() {
        var details = ReviewShotDetails(origin: .assistant(client: "Claude Code"), plan: "Annual", price: "$6.99", device: "iPhone 17 Pro")
        details.expectedPlan = "Monthly"
        #expect(details.showsOtherPlan)
        #expect(details.heading == "Review screenshot · Monthly shows, Annual selected")
        #expect(details.capturedLine(now: details.madeAt).hasSuffix("Monthly shows $6.99, with Annual selected."))
        #expect(details.reviewLine(product: "Monthly") == "Monthly · Monthly shows, Annual selected · from Claude Code")
        details.expectedPlan = "annual"
        #expect(!details.showsOtherPlan)
        #expect(details.heading == "Review screenshot · Annual selected")
    }
}
#endif
