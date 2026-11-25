//
//  PriceTestReturnDay.swift
//  Atlas
//

import Foundation

/// The old prices' `startDate` in a price test's Review & Push item: the
/// test starts when the person pushes, so day 28 is only known then. The
/// push fills it in (`PushController`), the same day it records the test
/// as running (`PriceTestStore.record(push:)`).
enum PriceTestReturnDay {
    static let token = "{priceTestReturnDay}"

    /// Day 28 from `today` (GMT), as App Store Connect takes it: "2026-12-23".
    static func day(from today: Date) -> String {
        AnalyticsDay(today).adding(PriceTest.days).iso
    }

    static func resolving(_ request: PushRequest, today: Date = .now) -> PushRequest {
        guard request.bodyText?.contains(token) == true else { return request }
        return request.replacing(token, with: day(from: today))
    }
}
