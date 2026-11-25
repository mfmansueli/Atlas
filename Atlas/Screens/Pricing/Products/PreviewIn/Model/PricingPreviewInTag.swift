//
//  PricingPreviewInTag.swift
//  Atlas
//

import Foundation

/// Why a product's price in "Preview in" is changing: an open price
/// suggestion, or a change already waiting in Review & Push.
enum PricingPreviewInTag: Equatable, Sendable {
    case suggested
    case notPushed

    var title: String {
        switch self {
        case .suggested: String(localized: "Suggested", comment: "kind:pill")
        case .notPushed: String(localized: "Not pushed", comment: "kind:pill")
        }
    }
}
