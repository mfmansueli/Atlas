//
//  AtlasNotifications.swift
//  Atlas
//

import Foundation

/// The words of Atlas's notifications, sent through `AtlasNotifier` when
/// Settings → Notifications allows them.
@MainActor
enum AtlasNotifications {
    /// A push ended: what landed, or how many didn't (always told).
    static func pushFinished(landed: Int, failed: Int, notifier: AtlasNotifier = .shared) {
        if failed > 0 {
            let total = landed + failed
            notifier.post(
                .pushFailed, title: String(localized: "Push stopped"),
                body: String(localized: "\(failed) of \(total) changes weren’t pushed. They’re still in Review & Push, each with Apple’s reason."),
                identifier: "push.finished"
            )
        } else if landed > 0 {
            let body = landed == 1
                ? String(localized: "1 change is on App Store Connect.")
                : String(localized: "\(landed) changes are on App Store Connect.")
            notifier.post(.pushFinished, title: String(localized: "Push finished"), body: body, identifier: "push.finished")
        }
    }

    /// Claude's concepts for an event came in behind a hidden
    /// sheet: the person chooses one.
    static func conceptsArrived(_ run: EventArtworkRun, notifier: AtlasNotifier = .shared) {
        guard run.isHidden, run.step == .choose else { return }
        notifier.post(
            .needsYou, title: String(localized: "Concepts are ready"),
            body: String(localized: "\(run.concepts.count) concepts for “\(run.eventName)” are ready. Choose one to finish the event’s images."),
            identifier: "artwork.\(run.appID).\(run.eventID)"
        )
    }

    /// Reviews that weren't there at the last check, the ones the level
    /// asks for.
    static func newReviews(
        _ reviews: [AppReview], appName: String, appID: StoreApp.ID, preferences: NotificationPreferences = .shared,
        notifier: AtlasNotifier = .shared
    ) {
        let told = reviews.filter { preferences.newReviews.includes(rating: $0.rating) }
        guard let first = told.first else { return }
        let body = told.count == 1
            ? String(localized: "\(first.rating)★ “\(first.title)”")
            : String(localized: "\(told.count) new reviews, the lowest \(told.map(\.rating).min() ?? first.rating)★.")
        notifier.post(.newReviews, title: String(localized: "New review for \(appName)"), body: body, identifier: "reviews.\(appID)")
    }

    /// Analytics' new findings, once a week at most.
    static func analyticsFindings(
        _ count: Int, now: Date, preferences: NotificationPreferences = .shared, notifier: AtlasNotifier = .shared
    ) {
        guard count > 0, preferences.analyticsNoticeIsDue(now: now) else { return }
        preferences.lastAnalyticsNotice = now
        let body = count == 1
            ? String(localized: "1 new thing to try, from your App Store numbers.")
            : String(localized: "\(count) new things to try, from your App Store numbers.")
        notifier.post(.analytics, title: String(localized: "Analytics has something new"), body: body, identifier: "analytics.weekly")
    }
}
