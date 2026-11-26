//
//  ReviewPushUITests.swift
//  AtlasUITests
//

import XCTest

/// Review & Push and Activity, driven through the DEBUG scenes in
/// `ReviewPushDebugScenes` (simulated App Store Connect, nothing leaves the Mac).
@MainActor
final class ReviewPushUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() async throws {
        app.terminate()
    }

    func testReviewGroupsChangesAndFiltersBySource() {
        launch(scene: "review")
        XCTAssertTrue(element("review.sheet").waitForExistence(timeout: 10))
        XCTAssertTrue(element("review.row.price.6450100002.BRA").exists)
        XCTAssertTrue(app.staticTexts["Subscription Pricing · Lumen Plus Annual"].exists)

        element("review.sourceFilter").radioButtons["Machine translation 2"].click()
        XCTAssertTrue(element("review.row.price.6450100002.BRA").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Push 2 Changes"].exists)
    }

    func testAllAppsShowsEveryAppsChanges() {
        launch(scene: "review")
        XCTAssertTrue(element("review.scope").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["28 changes"].exists)
        element("review.scope").radioButtons["All apps · 31"].click()
        XCTAssertTrue(app.staticTexts["31 changes"].waitForExistence(timeout: 5))
    }

    func testDiscardingARowRemovesIt() {
        launch(scene: "review")
        let discard = app.buttons["review.discard.price.6450100002.CAN"]
        XCTAssertTrue(discard.waitForExistence(timeout: 10))
        discard.click()
        XCTAssertTrue(element("review.row.price.6450100002.CAN").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Push 27 Changes"].exists)
    }

    /// A new version queued with its texts: one row, "Create version 1.5",
    /// with each text below it; discarding the version discards them all.
    func testANewVersionShowsWithItsTexts() {
        launch(scene: "review-newversion")
        let id = "review.creation.appStoreVersion.6450000001.IOS"
        XCTAssertTrue(element("\(id).title").waitForExistence(timeout: 10))
        XCTAssertEqual(element("\(id).title").value as? String ?? element("\(id).title").label, "Create version 1.5")
        let fields = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "\(id).storePage."))
        XCTAssertEqual(fields.count, 3)
        for text in ["What’s New · English (U.S.)", "What’s New · German", "App Review · Notes"] {
            let row = fields.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
            XCTAssertEqual(row.count, 1, "No row for \(text): \(fields.allElementsBoundByIndex.map { "\($0.label) | \(String(describing: $0.value))" })")
        }
        XCTAssertTrue(app.buttons["Push 4 Changes"].exists)

        app.buttons["\(id).discard"].click()
        XCTAssertTrue(element("review.empty").waitForExistence(timeout: 5))
    }

    /// Claude Code's new Review Notes for an in-app purchase: its row under
    /// "Review Notes · Lifetime" with the reason, App Store Connect's notes
    /// before and the suggested ones after.
    func testASuggestedReviewNoteShowsBeforeAndAfter() {
        launch(scene: "review-inapp-note")
        let row = element("review.row.storePage.6450000001.inAppReviewNote.lumen.plus.lifetime")
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        let texts = row.descendants(matching: .any)
        let before = texts.matching(NSPredicate(format: "label == %@ OR value == %@", Self.oldNote, Self.oldNote))
        XCTAssertGreaterThanOrEqual(before.count, 1, "No “before”: \(texts.allElementsBoundByIndex.map(\.label))")
        let added = "since 1.5, weekly reflections"
        let after = texts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", added, added))
        XCTAssertGreaterThanOrEqual(after.count, 1, "No “after”: \(texts.allElementsBoundByIndex.map(\.label))")
        XCTAssertTrue(app.staticTexts["Review Notes · Lifetime"].exists)
        let why = "1.5 adds weekly reflections"
        let reason = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", why, why))
        XCTAssertGreaterThanOrEqual(reason.count, 1, "The reason isn’t under the heading.")
        XCTAssertTrue(app.buttons["Push 1 Change"].exists)
    }

    private static let oldNote = "Buy it in Settings → Lumen Plus with a sandbox account. It unlocks unlimited photos."

    func testPushingShowsProgressAndEmptiesTheQueue() {
        launch(scene: "review")
        let pushAll = app.buttons["review.pushAll"]
        XCTAssertTrue(pushAll.waitForExistence(timeout: 10))
        pushAll.click()
        XCTAssertTrue(element("push.title").waitForExistence(timeout: 5))
        XCTAssertTrue(element("push.rateMeter").exists)
        let done = app.buttons["push.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["All 28 changes pushed"].exists)
        done.click()
        XCTAssertTrue(element("review.sheet").waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["overview.waiting"].waitForExistence(timeout: 5))
    }

    func testMinimizingKeepsThePushGoingAndTheToolbarOpensItAgain() {
        launch(scene: "review")
        let pushAll = app.buttons["review.pushAll"]
        XCTAssertTrue(pushAll.waitForExistence(timeout: 10))
        pushAll.click()
        XCTAssertTrue(element("push.title").waitForExistence(timeout: 5))
        let minimize = app.buttons["push.minimize"]
        XCTAssertTrue(minimize.exists)

        minimize.click()
        XCTAssertTrue(element("review.sheet").waitForNonExistence(timeout: 5))
        // While it runs, the toolbar's badge counts what was sent ("3/28").
        let badge = element("workspace.reviewPushBadge")
        if badge.exists, let text = badge.value as? String, !text.isEmpty {
            XCTAssertTrue(text.contains("/") || Int(text) != nil, text)
        }

        app.buttons["workspace.reviewPushButton"].click()
        XCTAssertTrue(element("push.title").waitForExistence(timeout: 5))
        let done = app.buttons["push.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["All 28 changes pushed"].exists)
    }

    func testPartialFailureShowsApplesErrorAndOffersRetry() {
        launch(scene: "push-partial")
        XCTAssertTrue(app.staticTexts["24 pushed · 2 failed"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["push.retryFailed"].exists)
        XCTAssertTrue(app.buttons["push.viewResults"].exists)
        let chile = element("push.row.price.6450100002.CHL")
        let chileText = "\(chile.label) \(chile.value as? String ?? "")"
        XCTAssertTrue(chileText.contains("ENTITY_ERROR.RELATIONSHIP.INVALID"), chileText)

        app.buttons["push.done"].click()
        XCTAssertTrue(element("workspace.banner").waitForExistence(timeout: 5))
        app.buttons["banner.reviewFailed"].click()
        XCTAssertTrue(element("review.row.price.6450100002.CHL").waitForExistence(timeout: 5))
    }

    /// The banner appears once the push ends, above the section. (Content
    /// that scrolled under a safe-area banner showed through it; XCUITest
    /// reports the same frames either way, so screenshots checked that.)
    func testTheFailureBannerDoesntCoverTheSection() {
        launch(scene: "push-partial")
        XCTAssertTrue(app.staticTexts["24 pushed · 2 failed"].waitForExistence(timeout: 20))
        app.buttons["push.done"].click()
        let banner = element("workspace.banner")
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        let overview = element("workspace.overview")
        XCTAssertTrue(overview.waitForExistence(timeout: 5))
        overview.scroll(byDeltaX: 0, deltaY: -120)
        XCTAssertGreaterThanOrEqual(overview.frame.minY, banner.frame.maxY, "The Overview at \(overview.frame) runs under the banner at \(banner.frame).")
    }

    func testConflictMustBeResolvedBeforePushing() {
        launch(scene: "push-conflict")
        XCTAssertTrue(app.buttons["Push 3 Changes"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["4 changes · 1 needs attention"].exists)
        app.buttons["review.keepMine"].click()
        XCTAssertTrue(app.buttons["Push 4 Changes"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["review.keepMine"].exists)
    }

    func testAssistantConflictAndRejectAll() {
        launch(scene: "review-assistant")
        let pickAssistant = app.buttons["review.pickAssistant"]
        XCTAssertTrue(pickAssistant.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Push 10 Changes"].exists)

        app.buttons["review.rejectAll"].click()
        XCTAssertTrue(pickAssistant.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Push 1 Change"].exists)
    }

    func testEmptyQueueSaysSo() {
        launch(scene: "review-empty")
        XCTAssertTrue(app.staticTexts["Nothing to push"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["review.pushAll"].isEnabled)
    }

    /// Activity is Review & Push's second tab; Restore Previous Values puts
    /// the old values on To Push, with a toast that nothing was pushed.
    func testActivityRestoresPreviousValuesThroughReview() {
        launch(scene: "activity")
        XCTAssertTrue(element("review.activity").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Subscription Pricing · Mexico, Türkiye, India"].exists)
        XCTAssertTrue(app.staticTexts["All succeeded"].exists)
        XCTAssertTrue(app.staticTexts["2 failed"].exists)
        app.buttons.matching(identifier: "activity.restore").element(boundBy: 2).click()
        XCTAssertTrue(element("review.row.price.6450100002.MEX").waitForExistence(timeout: 5))
        XCTAssertTrue(element("review.sheet").exists)
        XCTAssertFalse(element("review.activity").exists, "Restore switches to To Push")
        XCTAssertTrue(app.staticTexts["Restore"].exists)
        XCTAssertTrue(app.staticTexts["The previous values for 3 changes are in Review & Push. Nothing was pushed."].exists)
    }

    /// The segmented control switches between To Push and Activity.
    func testTheTabsSwitchBetweenToPushAndActivity() {
        launch(scene: "review")
        let tabs = element("review.tabs")
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        XCTAssertTrue(element("review.row.price.6450100002.BRA").exists, "changes wait, so it opens on To Push")
        tabs.radioButtons["Activity"].click()
        XCTAssertTrue(element("review.activity").waitForExistence(timeout: 5))
        tabs.radioButtons["To Push"].click()
        XCTAssertTrue(element("review.row.price.6450100002.BRA").waitForExistence(timeout: 5))
    }

    /// ⌘Y (Product → Activity) opens Review & Push on Activity.
    func testCommandYOpensActivity() {
        launch(scene: "nav-ov")
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        app.typeKey("y", modifierFlags: .command)
        XCTAssertTrue(element("review.activity").waitForExistence(timeout: 5))
        app.buttons["activity.done"].click()
        XCTAssertTrue(element("review.activity").waitForNonExistence(timeout: 5))
    }

    /// The push sheet's last step: Show in Activity opens Activity on the
    /// push that just ended, tinted.
    func testShowInActivityHighlightsThePushThatEnded() {
        launch(scene: "push-partial")
        XCTAssertTrue(app.staticTexts["24 pushed · 2 failed"].waitForExistence(timeout: 20))
        let show = app.buttons["push.showInActivity"]
        XCTAssertTrue(show.exists)
        show.click()
        XCTAssertTrue(element("review.activity").waitForExistence(timeout: 5))
        XCTAssertTrue(element("activity.record.highlighted").waitForExistence(timeout: 5))
    }

    func testOfflineBanner() {
        launch(scene: "banner-offline")
        XCTAssertTrue(element("workspace.banner").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["You’re offline"].exists)
    }

    // MARK: - Helpers

    private func launch(scene: String) {
        app.launch(debugScene: scene)
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
