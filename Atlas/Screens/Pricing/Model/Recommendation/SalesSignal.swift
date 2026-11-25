//
//  SalesSignal.swift
//  Atlas
//

import Foundation

/// A territory's numbers over one window (28 or 90 days) from App Analytics
/// and Sales and Trends.
struct SalesSignal: Hashable, Sendable {
    var pageViews: Int
    /// Subscription starts: trial starts plus paid starts without a trial
    /// (purchases, for an in-app purchase).
    var starts: Int
    /// First downloads from App Analytics.
    var downloads = 0
    /// Free trial starts (introductory offers), from Sales and Trends.
    var trialStarts = 0
    /// Paid starts: paid subscriptions begun, with or without a trial first.
    var paidStarts = 0
    /// Proceeds after Apple's commission and tax, in US dollars.
    var proceeds: Decimal = 0

    /// Page view → start conversion, or nil without views.
    var conversion: Double? {
        pageViews > 0 ? Double(starts) / Double(pageViews) : nil
    }

    /// Two windows added together, e.g. a region's countries.
    static func + (lhs: Self, rhs: Self) -> Self {
        SalesSignal(
            pageViews: lhs.pageViews + rhs.pageViews,
            starts: lhs.starts + rhs.starts,
            downloads: lhs.downloads + rhs.downloads,
            trialStarts: lhs.trialStarts + rhs.trialStarts,
            paidStarts: lhs.paidStarts + rhs.paidStarts,
            proceeds: lhs.proceeds + rhs.proceeds
        )
    }

    static let zero = SalesSignal(pageViews: 0, starts: 0)
}

/// Older saved signals only had page views and starts.
extension SalesSignal: Codable {
    private enum CodingKeys: String, CodingKey {
        case pageViews, starts, downloads, trialStarts, paidStarts, proceeds
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pageViews = try container.decode(Int.self, forKey: .pageViews)
        starts = try container.decode(Int.self, forKey: .starts)
        downloads = try container.decodeIfPresent(Int.self, forKey: .downloads) ?? 0
        trialStarts = try container.decodeIfPresent(Int.self, forKey: .trialStarts) ?? 0
        paidStarts = try container.decodeIfPresent(Int.self, forKey: .paidStarts) ?? 0
        proceeds = try container.decodeIfPresent(Decimal.self, forKey: .proceeds) ?? 0
    }
}
