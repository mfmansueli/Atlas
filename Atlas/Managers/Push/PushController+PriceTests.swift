//
//  PushController+PriceTests.swift
//  Atlas
//

import Foundation

/// A finished push in Pricing's own records: the price history keeps each
/// price change and, later, the 28 days either side for Results and
/// HowSure; a price test runs from the push that starts it (board 76).
extension PushController {
    func recordPricing(_ record: PushRecord) {
        priceHistory.record(push: record)
        PriceTestStore.shared.record(push: record)
    }
}
