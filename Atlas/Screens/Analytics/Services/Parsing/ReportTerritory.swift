//
//  ReportTerritory.swift
//  Atlas
//

import Foundation

/// Reads a report's territory, which Apple writes as a two-letter code in
/// Sales and Trends and may write as a code or a name in analytics reports.
enum ReportTerritory {
    private static let byName: [String: String] = Dictionary(
        TerritoryCatalog.standard.territories.map { ($0.name.lowercased(), $0.alpha2) },
        uniquingKeysWith: { first, _ in first }
    )

    /// The ISO alpha-2 code, or "" when the value names no App Store territory.
    static func alpha2(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if let territory = TerritoryCatalog.standard.territory(code: trimmed) { return territory.alpha2 }
        if let code = byName[trimmed.lowercased()] { return code }
        return trimmed.count == 2 ? trimmed.uppercased() : ""
    }
}
