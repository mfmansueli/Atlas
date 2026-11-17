//
//  AnalyticsActivity.swift
//  Atlas
//

import Foundation

/// What Analytics is doing for one app right now.
enum AnalyticsActivity: Hashable, Sendable {
    case idle
    /// Downloading Apple's reports; `finished` of the steps are done.
    case loading(finished: Int)
    case failed(String)

    /// The steps the loading card lists.
    static var steps: [String] {
        [
            String(localized: "Impressions, page views and downloads"),
            String(localized: "Sales and subscriptions"),
        ]
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
