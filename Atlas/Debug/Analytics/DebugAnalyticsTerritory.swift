//
//  DebugAnalyticsTerritory.swift
//  Atlas
//

#if DEBUG
import Foundation

/// One territory of Lumen's canned 28 days.
struct DebugAnalyticsTerritory {
    var code: String
    var impressions: Double
    var views: Double
    var downloads: Double
    var trials: Double
    var proceeds: Double
    /// Trial → paid.
    var paidRate: Double

    init(_ code: String, _ impressions: Double, _ views: Double, _ downloads: Double, _ trials: Double, _ proceeds: Double, _ paidRate: Double) {
        self.code = code
        self.impressions = impressions
        self.views = views
        self.downloads = downloads
        self.trials = trials
        self.proceeds = proceeds
        self.paidRate = paidRate
    }
}
#endif
