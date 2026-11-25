//
//  ResultVerdict.swift
//  Atlas
//

import Foundation

/// How a changed territory did, in plain words. Results compare; they don't
/// prove a price caused anything.
enum ResultVerdict: String, CaseIterable, Hashable, Sendable {
    /// Page view → start conversion up (90% interval above zero) and
    /// proceeds no lower.
    case better
    /// No difference the interval can tell from chance, or conversion and
    /// proceeds moved in opposite directions.
    case aboutTheSame
    /// Conversion down (90% interval below zero) and proceeds no higher.
    /// Offers Restore, which queues the old price for review.
    case worse
    /// Under 28 days or 30 starts on a side.
    case tooLittleData

    var title: String {
        switch self {
        case .better: String(localized: "Better", comment: "kind:label")
        case .aboutTheSame: String(localized: "About the same", comment: "kind:label")
        case .worse: String(localized: "Worse", comment: "kind:label")
        case .tooLittleData: String(localized: "Too few to tell", comment: "kind:label")
        }
    }

    var offersRestore: Bool { self == .worse }

    /// Whether the territory counts toward the summary.
    var hasEnoughData: Bool { self != .tooLittleData }
}
