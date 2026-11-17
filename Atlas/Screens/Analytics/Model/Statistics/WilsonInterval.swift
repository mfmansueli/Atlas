//
//  WilsonInterval.swift
//  Atlas
//

import Foundation

/// The Wilson score interval of a proportion at 90%.
struct WilsonInterval: Hashable, Sendable {
    var low: Double
    var high: Double
    /// The proportion itself.
    var value: Double
    var halfWidth: Double

    static let zero = WilsonInterval(low: 0, high: 0, value: 0, halfWidth: 0)
}
