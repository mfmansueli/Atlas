//
//  ReviewRiskCodeTarget.swift
//  Atlas
//

import Foundation

/// What a code pattern finds: an account signal or a permission in use.
enum ReviewRiskCodeTarget: Hashable, Sendable {
    case signal(ReviewRiskCodeSignal)
    case permission(ReviewRiskPermission)
}
