//
//  PriceTestControlChoice.swift
//  Atlas
//

import Foundation

/// The sheet's Compared with pop-up: the region Atlas picks, one the
/// person picks, or none.
enum PriceTestControlChoice: Hashable, Sendable {
    /// The region with the most similar traffic, its price unchanged, and
    /// at least 30 starts (`PriceTestRules.automaticControl`).
    case automatic
    case region(TerritoryRegion)
    /// Before against during only: the result is less sure.
    case none
}
