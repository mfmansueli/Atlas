//
//  RefreshTokensTests.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Atlas

/// Rule zero: Refresh's sizes in `Metrics` are the ones
/// `design-tokens.json → refresh` holds (board 90).
@Suite("Refresh tokens")
struct RefreshTokensTests {
    private static let metrics: [String: CGFloat] = [
        "buttonSize": Metrics.refreshButtonSize,
        "dotSize": Metrics.refreshDotSize,
    ]

    @Test func everySizeMatchesTheJSON() throws {
        let url = try #require(Bundle.main.url(forResource: "design-tokens", withExtension: "json"), "design-tokens.json is in the app")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let tokens = try #require(object as? [String: Any])
        let refresh = try #require(tokens["refresh"] as? [String: Any], "design-tokens.json has a refresh group")
        #expect(Set(refresh.keys.filter { !$0.hasPrefix("$") }) == Set(Self.metrics.keys))
        for (name, value) in Self.metrics {
            let number = try #require(refresh[name] as? NSNumber, "\(name) is a number")
            #expect(CGFloat(number.doubleValue) == value, "\(name)")
        }
    }
}
