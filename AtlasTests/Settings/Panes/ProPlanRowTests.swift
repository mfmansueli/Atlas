//
//  ProPlanRowTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Settings → Atlas Pro's top row (board 48).
@MainActor
@Suite("Atlas Pro plan row")
struct ProPlanRowTests {
    private let renews = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2027, month: 11, day: 2))!

    private func row(_ status: ProStatus, isPro: Bool = true) -> ProPlanRow {
        ProPlanRow(status: status, isPro: isPro, offers: DebugProStore.offers) {}
    }

    @Test func aYearlyPlanSaysWhenItRenewsAndWhatItCosts() {
        let row = row(.subscribed(plan: .yearly, until: renews, isTrial: false))
        #expect(row.title == "Atlas Pro · Yearly")
        #expect(row.detail.contains("$59.99 a year"))
        #expect(row.detail.hasSuffix("billed by the App Store"))
        #expect(row.detail.hasPrefix("Renews "))
    }

    @Test func monthlyAndTrial() {
        #expect(row(.subscribed(plan: .monthly, until: nil, isTrial: true)).title == "Atlas Pro · Monthly · free trial")
        #expect(row(.subscribed(plan: .monthly, until: nil, isTrial: false)).detail == "$9.99 a month · billed by the App Store")
    }

    @Test func freeAndLifetime() {
        #expect(row(.free, isPro: false).title == "Atlas Free")
        #expect(row(.free, isPro: false).detail == "Free does it one at a time. Pro does it all at once.")
        #expect(row(.lifetime).title == "Atlas Pro · Lifetime")
    }

    @Test func theIncludesListIsTheDesigns() {
        #expect(ProSettingsPane.includes.count == 7)
        #expect(ProSettingsPane.includes.first?.free == "Free: 1 app, 1 account")
    }
}
