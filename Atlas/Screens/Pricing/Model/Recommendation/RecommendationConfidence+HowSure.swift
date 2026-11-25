//
//  RecommendationConfidence+HowSure.swift
//  Atlas
//

import Foundation

/// A price suggestion's confidence in the house's three words (README-DS
/// §9): purchasing power alone is Not very sure.
extension RecommendationConfidence {
    var howSure: HowSure {
        switch self {
        case .low: .notVerySure
        case .medium: .fairlySure
        case .high: .sure
        }
    }
}
