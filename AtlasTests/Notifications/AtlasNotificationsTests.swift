//
//  AtlasNotificationsTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Atlas tells you about (board 48), with no notification center:
/// what would have been sent is kept on the notifier.
@MainActor
@Suite("Atlas notifications")
struct AtlasNotificationsTests {
    private let preferences = NotificationPreferences(defaults: nil)

    private var notifier: AtlasNotifier {
        AtlasNotifier(center: nil, preferences: preferences)
    }

    @Test func aPushThatFinishedTellsWhileItsSwitchIsOn() {
        let notifier = notifier
        AtlasNotifications.pushFinished(landed: 26, failed: 0, notifier: notifier)
        #expect(notifier.sent.map(\.body) == ["26 changes are on App Store Connect."])
        preferences.pushFinished = false
        AtlasNotifications.pushFinished(landed: 1, failed: 0, notifier: notifier)
        #expect(notifier.sent.count == 1)
    }

    /// "A push that fails always tells you."
    @Test func aFailedPushAlwaysTells() {
        preferences.pushFinished = false
        let notifier = notifier
        AtlasNotifications.pushFinished(landed: 24, failed: 2, notifier: notifier)
        #expect(notifier.sent.first?.title == "Push stopped")
        #expect(notifier.sent.first?.body.hasPrefix("2 of 26 changes weren’t pushed.") == true)
    }

    @Test func newReviewsFollowTheLevel() {
        let notifier = notifier
        let reviews = [ReviewsTestData.review("a", rating: 5), ReviewsTestData.review("b", rating: 2)]
        AtlasNotifications.newReviews(reviews, appName: "Lumen", appID: "app", preferences: preferences, notifier: notifier)
        #expect(notifier.sent.map(\.title) == ["New review for Lumen"])
        #expect(notifier.sent.first?.body == "2★ “Title b”")
        preferences.newReviews = .never
        AtlasNotifications.newReviews(reviews, appName: "Lumen", appID: "app", preferences: preferences, notifier: notifier)
        #expect(notifier.sent.count == 1)
        // Only five stars at 3 or lower: nothing to tell.
        preferences.newReviews = .lowRatings
        AtlasNotifications.newReviews([reviews[0]], appName: "Lumen", appID: "app", preferences: preferences, notifier: notifier)
        #expect(notifier.sent.count == 1)
    }

    @Test func analyticsTellsOnceAWeek() {
        let notifier = notifier
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        AtlasNotifications.analyticsFindings(2, now: now, preferences: preferences, notifier: notifier)
        AtlasNotifications.analyticsFindings(3, now: now.addingTimeInterval(86400), preferences: preferences, notifier: notifier)
        #expect(notifier.sent.map(\.body) == ["2 new things to try, from your App Store numbers."])
        #expect(preferences.lastAnalyticsNotice == now)
    }

    /// Concepts that come in behind a hidden sheet ask for a choice; with
    /// the sheet open, nothing is sent.
    @Test func readyConceptsTellOnlyBehindAHiddenSheet() {
        let notifier = notifier
        var run = EventArtworkStudioTestData.run(step: .choose)
        AtlasNotifications.conceptsArrived(run, notifier: notifier)
        #expect(notifier.sent.isEmpty)
        run.isHidden = true
        AtlasNotifications.conceptsArrived(run, notifier: notifier)
        #expect(notifier.sent.first?.title == "Concepts are ready")
        preferences.needsYou = false
        AtlasNotifications.conceptsArrived(run, notifier: notifier)
        #expect(notifier.sent.count == 1)
    }

    @Test func soundOnlyWhenAskedFor() {
        #expect(notifier.sound == nil)
        preferences.playsSound = true
        #expect(notifier.sound != nil)
    }

    /// The Dock count leaves suggestions out.
    @Test func theDockCountIsWhatNeedsYou() {
        let needs = [
            BackgroundNeed(id: "autopilot-1", title: "Choose the look", detail: "", destination: .reviewPush),
            BackgroundNeed(id: "suggestions-1", title: "3 suggestions", detail: "", destination: .reviewPush, isSuggestion: true),
        ]
        #expect(MenuBarController.dockCount(needs: needs, showsCount: true) == 1)
        #expect(MenuBarController.dockCount(needs: needs, showsCount: false) == nil)
        #expect(MenuBarController.dockCount(needs: [needs[1]], showsCount: true) == nil)
    }
}
