//
//  AppTerritory.swift
//  Atlas
//

import Foundation

/// One country or region as App Store Connect lists it (`GET
/// /v1/territories`), for the app's availability and price. Its name and
/// flag come from Atlas's table when it has the territory; the ID is what
/// goes to Apple, never the table's own list (it has territories Apple
/// refuses, such as Samoa).
struct AppTerritory: Identifiable, Hashable, Sendable {
    /// Alpha-3, e.g. "BRA".
    var id: String
    /// e.g. "BRL".
    var currencyCode: String

    init(id: String, currencyCode: String? = nil) {
        self.id = id
        self.currencyCode = currencyCode ?? TerritoryCatalog.standard.territory(alpha3: id)?.currencyCode ?? "USD"
    }

    /// The United States, the default base territory.
    static let unitedStates = AppTerritory(id: "USA", currencyCode: "USD")

    var name: String { Self.name(of: id) }

    /// Alpha-2 for the flag; nil for a territory Atlas's table lacks.
    var alpha2: String? { TerritoryCatalog.standard.territory(alpha3: id)?.alpha2 }

    /// "Brazil", or the ID for a territory Atlas's table lacks.
    static func name(of id: String) -> String {
        TerritoryCatalog.standard.territory(alpha3: id)?.name ?? id
    }

    /// Ordered by name, as the lists show them.
    static func sorted(_ territories: [AppTerritory]) -> [AppTerritory] {
        territories.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
