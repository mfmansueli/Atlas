//
//  PooledSalesText.swift
//  Atlas
//

import Foundation

/// How Pricing says a thin country leans on its region's sales (board 76):
/// "Uses Europe’s sales" in the Source and Reason columns, "Too few sales
/// here, so Atlas uses Europe’s." in their help. One sentence per region,
/// so each language can write its own possessive.
enum PooledSalesText {
    /// "Uses Europe’s sales".
    static func short(_ region: TerritoryRegion) -> String {
        switch region {
        case .americas: String(localized: "Uses the Americas’ sales", comment: "kind:label")
        case .europe: String(localized: "Uses Europe’s sales", comment: "kind:label")
        case .asiaPacific: String(localized: "Uses Asia Pacific’s sales", comment: "kind:label")
        case .africaMiddleEast: String(localized: "Uses Africa & Middle East’s sales", comment: "kind:label")
        }
    }

    /// "Too few sales here, so Atlas uses Europe’s."
    static func tip(_ region: TerritoryRegion) -> String {
        switch region {
        case .americas: String(localized: "Too few sales here, so Atlas uses the Americas’.", comment: "kind:tooltip")
        case .europe: String(localized: "Too few sales here, so Atlas uses Europe’s.", comment: "kind:tooltip")
        case .asiaPacific: String(localized: "Too few sales here, so Atlas uses Asia Pacific’s.", comment: "kind:tooltip")
        case .africaMiddleEast: String(localized: "Too few sales here, so Atlas uses Africa & Middle East’s.", comment: "kind:tooltip")
        }
    }
}
