//
//  HowSureWeighting.swift
//  Atlas
//

import Foundation

/// The banner's how sure, weighted by traffic: the highest level L such
/// that at least 80% of the suggested countries' page views (90 days) are
/// in countries at L or better. Without any page views, Not very sure: a
/// few countries without traffic can't make the whole suggestion sure.
enum HowSureWeighting {
    struct Entry: Hashable, Sendable {
        var level: HowSure
        var pageViews: Int
    }

    /// 80%, as a fraction: covered × 5 ≥ total × 4.
    static let shareNumerator = 4
    static let shareDenominator = 5

    static func level(_ entries: [Entry]) -> HowSure {
        let total = entries.reduce(0) { $0 + max(0, $1.pageViews) }
        guard total > 0 else { return .notVerySure }
        for level in [HowSure.sure, .fairlySure] {
            let covered = entries.filter { $0.level >= level }.reduce(0) { $0 + max(0, $1.pageViews) }
            if covered * shareDenominator >= total * shareNumerator { return level }
        }
        return .notVerySure
    }
}
