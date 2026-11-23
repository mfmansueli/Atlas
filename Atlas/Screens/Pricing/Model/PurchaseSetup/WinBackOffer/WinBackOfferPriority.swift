//
//  WinBackOfferPriority.swift
//  Atlas
//

import Foundation

/// Which of a customer's win-back offers Apple shows first:
/// App Store Connect's `priority`.
enum WinBackOfferPriority: String, CaseIterable, Hashable, Sendable {
    case high = "HIGH"
    case normal = "NORMAL"

    var title: String {
        switch self {
        case .high: String(localized: "High")
        case .normal: String(localized: "Normal")
        }
    }
}
