//
//  MeaningDrift.swift
//  Atlas
//

import Foundation

/// A word in MEANS that moved away from the original: "inspirations"
/// where the original says "prompts". MEANS underlines it, with the
/// original in its tooltip.
struct MeaningDrift: Hashable, Codable, Sendable {
    /// The word or phrase exactly as MEANS has it.
    var phrase: String
    /// What the original says there.
    var original: String
}
