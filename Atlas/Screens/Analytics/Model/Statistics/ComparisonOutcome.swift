//
//  ComparisonOutcome.swift
//  Atlas
//

import Foundation

/// What two periods' rates say about each other.
enum ComparisonOutcome: Hashable, Sendable {
    /// Under 100 and 5 on either side.
    case tooFew
    /// The difference could be chance.
    case same
    case higher(ComparisonConfidence)
    case lower(ComparisonConfidence)

    /// "higher, sure", "about the same", "Too few to tell".
    var title: String {
        switch self {
        case .tooFew: String(localized: "Too few to tell")
        case .same: String(localized: "about the same")
        case let .higher(confidence): String(localized: "higher, \(confidence.title)")
        case let .lower(confidence): String(localized: "lower, \(confidence.title)")
        }
    }

    /// The verdict word Pricing → Results uses too.
    var verdict: String {
        switch self {
        case .tooFew: String(localized: "Too few to tell")
        case .same: String(localized: "About the same")
        case let .higher(confidence): String(localized: "Better · \(confidence.title)")
        case let .lower(confidence): String(localized: "Worse · \(confidence.title)")
        }
    }

    var isLower: Bool {
        if case .lower = self { return true }
        return false
    }

    var isHigher: Bool {
        if case .higher = self { return true }
        return false
    }
}
