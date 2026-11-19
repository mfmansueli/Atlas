//
//  NotificationPreferencesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Settings → Notifications (board 48): the switches, kept, and the weekly
/// Analytics notice.
@MainActor
@Suite("Notification preferences")
struct NotificationPreferencesTests {
    @Test func theDesignsDefaults() {
        let preferences = NotificationPreferences(defaults: nil)
        #expect(preferences.needsYou)
        #expect(preferences.reviewStatus)
        #expect(preferences.pushFinished)
        #expect(preferences.newReviews == .lowRatings)
        #expect(preferences.analytics == .weekly)
        #expect(!preferences.playsSound)
        #expect(preferences.showsMenuBarDot)
        #expect(preferences.showsDockCount)
    }

    @Test func theyAreKept() throws {
        let name = "NotificationPreferencesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = NotificationPreferences(defaults: defaults)
        preferences.needsYou = false
        preferences.newReviews = .all
        preferences.analytics = .never
        preferences.playsSound = true
        preferences.showsDockCount = false
        let read = NotificationPreferences(defaults: defaults)
        #expect(!read.needsYou)
        #expect(read.newReviews == .all)
        #expect(read.analytics == .never)
        #expect(read.playsSound)
        #expect(!read.showsDockCount)
    }

    @Test func reviewLevels() {
        #expect(ReviewNoticeLevel.lowRatings.includes(rating: 3))
        #expect(!ReviewNoticeLevel.lowRatings.includes(rating: 4))
        #expect(ReviewNoticeLevel.all.includes(rating: 5))
        #expect(!ReviewNoticeLevel.never.includes(rating: 1))
        #expect(ReviewNoticeLevel.allCases.map(\.title) == ["Never", "3 stars or lower", "Every review"])
    }

    @Test func theAnalyticsNoticeComesOnceAWeek() {
        let preferences = NotificationPreferences(defaults: nil)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(preferences.analyticsNoticeIsDue(now: now))
        preferences.lastAnalyticsNotice = now.addingTimeInterval(-3 * 86400)
        #expect(!preferences.analyticsNoticeIsDue(now: now))
        preferences.lastAnalyticsNotice = now.addingTimeInterval(-8 * 86400)
        #expect(preferences.analyticsNoticeIsDue(now: now))
        preferences.analytics = .never
        #expect(!preferences.analyticsNoticeIsDue(now: now))
    }

    @Test func permissionFromMacOS() {
        #expect(NotificationPermission(.authorized) == .allowed)
        #expect(NotificationPermission(.denied) == .blocked)
        #expect(NotificationPermission(.notDetermined) == .notAsked)
    }
}
