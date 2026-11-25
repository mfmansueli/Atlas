//
//  PriceLevelProvenance.swift
//  Atlas
//

import Foundation

/// Where one territory's value in an index comes from: its year and how it
/// was obtained.
struct PriceLevelProvenance: Hashable, Sendable {
    /// The year the value describes, e.g. 2025; nil when the source doesn't say.
    var year: Int?
    var method: PriceLevelMethod

    var isFallback: Bool { method == .fallback }
}
