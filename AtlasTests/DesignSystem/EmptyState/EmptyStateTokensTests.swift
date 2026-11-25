//
//  EmptyStateTokensTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// Rule zero: the empty states' sizes in `Metrics` are the ones
/// `design-tokens.json → emptyState` holds, and each size takes the
/// symbol and title README-DS §14 gives it.
@Suite("Empty state tokens")
struct EmptyStateTokensTests {
    private let emptyState: [String: Any]

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "design-tokens", withExtension: "json"), "design-tokens.json is in the app")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let tokens = try #require(object as? [String: Any])
        emptyState = try #require(tokens["emptyState"] as? [String: Any], "design-tokens.json has an emptyState group")
    }

    private static let metrics: [String: CGFloat] = [
        "symbol": Metrics.emptyStateSymbol,
        "inlineSymbol": Metrics.emptyStateInlineSymbol,
        "textWidth": Metrics.emptyStateTextWidth,
        "lift": Metrics.emptyStateLift,
    ]

    @Test func everySizeMatchesTheJSON() throws {
        let names = Set(emptyState.keys.filter { !$0.hasPrefix("$") })
        #expect(names == Set(Self.metrics.keys), "the JSON names every empty-state metric, and only those")
        for (name, value) in Self.metrics {
            let number = try #require(emptyState[name] as? NSNumber, "\(name) is a number")
            #expect(CGFloat(number.doubleValue) == value, "\(name)")
        }
    }

    @Test func aPageIsLargerThanAListsAndSitsAboveTheMiddle() {
        #expect(EmptyStateSize.page.symbolSize == 44)
        #expect(EmptyStateSize.inline.symbolSize == 32)
        #expect(EmptyStateSize.page.titleStyle == .title2)
        #expect(EmptyStateSize.inline.titleStyle == .title3)
        #expect(EmptyStateSize.page.bottomInset > EmptyStateSize.page.topInset, "a little above the middle")
        #expect(EmptyStateSize.inline.topInset == EmptyStateSize.inline.bottomInset, "where the rows would be")
    }
}
