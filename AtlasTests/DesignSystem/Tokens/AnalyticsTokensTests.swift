//
//  AnalyticsTokensTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// Rule zero: Analytics' sizes in `Metrics` are the ones
/// `design-tokens.json → analytics` holds (board 92).
@Suite("Analytics tokens")
struct AnalyticsTokensTests {
    private let analytics: [String: Any]

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "design-tokens", withExtension: "json"), "design-tokens.json is in the app")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let tokens = try #require(object as? [String: Any])
        analytics = try #require(tokens["analytics"] as? [String: Any], "design-tokens.json has an analytics group")
    }

    private static let metrics: [String: CGFloat] = [
        "breakdownCompactWidth": Metrics.breakdownCompactWidth,
        "inspectorWidth": Metrics.inspectorWidth,
        "changeChartHeight": Metrics.changeChartHeight,
        "changeResultsRowWidth": Metrics.changeResultsRowWidth,
        "originTile": Metrics.analyticsOriginTile,
    ]

    @Test func everySizeMatchesTheJSON() throws {
        let names = Set(analytics.keys.filter { !$0.hasPrefix("$") })
        #expect(names == Set(Self.metrics.keys), "the JSON names every Analytics metric, and only those")
        for (name, value) in Self.metrics {
            let number = try #require(analytics[name] as? NSNumber, "\(name) is a number")
            #expect(CGFloat(number.doubleValue) == value, "\(name)")
        }
    }
}
