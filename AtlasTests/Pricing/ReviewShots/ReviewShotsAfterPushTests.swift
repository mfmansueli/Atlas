//
//  ReviewShotsAfterPushTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Pricing says once a push uploaded review screenshots: since when,
/// from the push history, and the toast with each product's state.
@Suite("ReviewShotsAfterPush")
struct ReviewShotsAfterPushTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_795_000_000)

    private func change(_ id: String, app: String = "app1", path: String = "/tmp/a.png") -> PendingChange {
        let step = PurchaseReviewScreenshotPush(owner: .subscription, ownerID: "sub", fileName: "a.png", fileSize: 1, path: path, checksum: "")
        return PendingChange(
            id: id, appID: app, section: .subscriptionPricing, group: "", title: "Monthly", oldValue: "", newValue: "", source: .you,
            requests: [step.request]
        )
    }

    @Test func sinceSaysTodayYesterdayOrTheDay() {
        #expect(ReviewShotsAfterPush.sinceLine(now, now: now, calendar: calendar).hasPrefix("In App Store Connect since today."))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)
        #expect(ReviewShotsAfterPush.sinceLine(yesterday, now: now, calendar: calendar).hasPrefix("In App Store Connect since yesterday."))
        let earlier = calendar.date(byAdding: .day, value: -9, to: now)
        #expect(!ReviewShotsAfterPush.sinceLine(earlier, now: now, calendar: calendar).contains("today"))
        #expect(ReviewShotsAfterPush.sinceLine(nil, now: now) == "In App Store Connect. Apple lets you replace it, not remove it.")
    }

    @Test func theLastPushThatSentItDates() {
        let id = "reviewScreenshot.app1.monthly"
        let old = PushRecord(date: now.addingTimeInterval(-500), appID: "app1", appName: "Lumen", title: "", pushed: [change(id)])
        let new = PushRecord(date: now, appID: "app1", appName: "Lumen", title: "", pushed: [change(id)])
        let other = PushRecord(date: now.addingTimeInterval(100), appID: "app1", appName: "Lumen", title: "", pushed: [change("price.x")])
        #expect(ReviewShotsAfterPush.uploadedAt(id, in: [old, new, other]) == now)
        #expect(ReviewShotsAfterPush.uploadedAt("reviewScreenshot.app1.annual", in: [old, new]) == nil)
        #expect(ReviewShotsAfterPush.pushedChangeIDs(in: [new, other], appID: "app1") == [id])
        #expect(ReviewShotsAfterPush.pushedChangeIDs(in: [new], appID: "app2").isEmpty)
        #expect(ReviewShotsAfterPush.uploadedFile(id, in: [new]) == nil, "Not on this Mac anymore")
    }

    @Test func theToastSaysEachState() {
        #expect(ReviewShotsAfterPush.toast(states: Array(repeating: "Ready to Submit", count: 3), name: nil)
            == "Uploaded. Atlas read each product again from App Store Connect: 3 products are Ready to Submit.")
        #expect(ReviewShotsAfterPush.toast(states: ["Ready to Submit"], name: "Lumen Plus Monthly")
            == "Uploaded. Atlas read Lumen Plus Monthly again from App Store Connect: it’s Ready to Submit.")
        #expect(ReviewShotsAfterPush.toast(states: ["Ready to Submit", "Missing Metadata", "Ready to Submit"], name: nil)
            == "Uploaded. Atlas read each product again from App Store Connect: 2 are Ready to Submit and 1 is Missing Metadata.")
    }
}
