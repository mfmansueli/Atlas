//
//  InAppEventPriority.swift
//  Atlas
//

import Foundation

/// How an event ranks among the app's events on its product page.
enum InAppEventPriority: String, CaseIterable, Identifiable, Hashable, Sendable {
    case high = "HIGH"
    case normal = "NORMAL"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high: String(localized: "High")
        case .normal: String(localized: "Normal")
        }
    }
}
