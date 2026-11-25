//
//  ReviewRiskLedgerEntry.swift
//  Atlas
//

import Foundation

/// What Atlas keeps about one app's App Review risks between launches:
/// what the person dismissed, what an assistant confirmed or cleared in
/// the project, and the last report, so the Overview, the Submit sheet
/// and Look for Improvements don't need to check again to show it.
struct ReviewRiskLedgerEntry: Codable, Hashable, Sendable {
    /// Risk ID → when the person dismissed it.
    var dismissed: [String: Date] = [:]
    /// Risk ID → the risk an assistant confirmed.
    var reported: [String: ReviewRisk] = [:]
    /// Risk ID → an assistant's word that it isn't there.
    var cleared: [String: ReviewRiskVerdict] = [:]
    var lastReport: ReviewRiskReport?

    init() {}

    /// Every field is optional when decoding, so entries saved before a
    /// field existed still load.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dismissed = try container.decodeIfPresent([String: Date].self, forKey: .dismissed) ?? [:]
        reported = try container.decodeIfPresent([String: ReviewRisk].self, forKey: .reported) ?? [:]
        cleared = try container.decodeIfPresent([String: ReviewRiskVerdict].self, forKey: .cleared) ?? [:]
        lastReport = try container.decodeIfPresent(ReviewRiskReport.self, forKey: .lastReport)
    }
}
