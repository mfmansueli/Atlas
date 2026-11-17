//
//  ComplianceRegion.swift
//  Atlas
//

import Foundation

/// The countries and regions each regulation applies in, by App Store
/// Connect's territory IDs.
enum ComplianceRegion {
    /// The 27 member states, where the Digital Services Act applies.
    static let europeanUnion: Set<String> = [
        "AUT", "BEL", "BGR", "HRV", "CYP", "CZE", "DNK", "EST", "FIN", "FRA", "DEU", "GRC", "HUN", "IRL",
        "ITA", "LVA", "LTU", "LUX", "MLT", "NLD", "POL", "PRT", "ROU", "SVK", "SVN", "ESP", "SWE",
    ]

    static let chinaMainland = "CHN"
    static let vietnam = "VNM"

    /// Where Apple asks for the regulated medical device declaration: the
    /// European Economic Area, the United Kingdom and the United States.
    static let medicalDevice: Set<String> = europeanUnion.union(["ISL", "LIE", "NOR", "GBR", "USA"])
}
