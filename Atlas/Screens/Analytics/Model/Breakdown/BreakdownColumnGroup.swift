//
//  BreakdownColumnGroup.swift
//  Atlas
//

import Foundation

/// Which numbers Break It Down's columns show: the store funnel, or
/// subscribers and what people do after the download (from Apple's newer
/// reports, which name the page, campaign and source).
enum BreakdownColumnGroup: String, Hashable, Sendable, CaseIterable, Identifiable {
    case funnel
    case afterDownload

    var id: String { rawValue }

    var title: String {
        switch self {
        case .funnel: String(localized: "Store funnel")
        case .afterDownload: String(localized: "Subscribers and after download")
        }
    }
}
