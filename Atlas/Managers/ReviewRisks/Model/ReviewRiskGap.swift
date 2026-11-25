//
//  ReviewRiskGap.swift
//  Atlas
//

import Foundation

/// A check that couldn't run, and why: "no project folder", "App Store
/// Connect didn't answer". The list says it, so nobody reads silence as
/// "nothing found".
struct ReviewRiskGap: Codable, Hashable, Sendable {
    var check: ReviewRiskCheckID
    var reason: String
}
