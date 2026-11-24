//
//  MCPAppPriceAvailability.swift
//  Atlas
//

import Foundation

/// What the app price and availability tools share: one app's price and
/// availability read through the workspace, as JSON, and the territories
/// and prices an assistant names.
@MainActor
struct MCPAppPriceAvailability {
    let app: StoreApp
    let workspace: MCPWorkspace

    static func load(app identifier: String, in workspace: MCPWorkspace) async throws -> MCPAppPriceAvailability {
        try await MCPAppPriceAvailability(app: workspace.app(matching: identifier), workspace: workspace)
    }

    var services: any AppPriceAvailabilityServices { workspace.services.appPriceAvailability }
    var queue: ChangeQueue { workspace.changes }

    func price() async throws -> AppPriceState {
        do {
            return try await services.appPrice(for: app)
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read \(app.name)’s price: \(error.localizedDescription)"))
        }
    }

    func availability() async throws -> AppAvailabilityState {
        do {
            return try await services.availability(for: app)
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read where \(app.name) is sold: \(error.localizedDescription)"))
        }
    }

    func territories() async throws -> [AppTerritory] {
        do {
            return try await services.territories()
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read App Store Connect’s countries and regions: \(error.localizedDescription)"))
        }
    }

    func ladder(in territoryID: String) async throws -> PricePointLadder {
        do {
            return try await services.pricePoints(for: app, territoryID: territoryID)
        } catch {
            throw MCPToolError.unavailable(String(localized: "Couldn’t read Apple’s prices in \(AppTerritory.name(of: territoryID)): \(error.localizedDescription)"))
        }
    }

    // MARK: - Arguments

    /// A territory code (BRA or BR) or name, among `ids`.
    static func territoryID(matching code: String, among ids: [String]) -> String? {
        let wanted = code.trimmingCharacters(in: .whitespacesAndNewlines)
        let catalog = TerritoryCatalog.standard
        let id = catalog.territory(code: wanted)?.id
            ?? catalog.territories.first { $0.name.compare(wanted, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }?.id
            ?? wanted.uppercased()
        return ids.contains(id) ? id : nil
    }

    /// A price: 0 or "free" for Free, else a positive number.
    static func price(from value: JSONValue) -> Decimal? {
        if let text = value.stringValue?.trimmingCharacters(in: .whitespaces), text.lowercased() == "free" || Decimal(string: text) == 0 { return 0 }
        if value.intValue == 0 || value.doubleValue == 0 { return 0 }
        return MCPPriceValue.decimal(from: value)
    }

    /// The reason and evidence, as the change's detail shows them.
    static func reason(_ arguments: MCPToolArguments) throws -> String? {
        let evidence = try arguments.optionalStrings("evidence") ?? []
        let text = try [arguments.optionalString("reason"), evidence.isEmpty ? nil : evidence.joined(separator: "; ")]
            .compactMap(\.self)
            .joined(separator: " ")
        return text.isEmpty ? nil : text
    }

    // MARK: - JSON

    static func json(_ state: AppPriceState) -> JSONValue {
        guard case let .set(current) = state else { return ["state": "notSet"] }
        var result: [String: JSONValue] = [
            "state": "set",
            "baseTerritory": .string(current.baseTerritoryID),
            "currency": .string(current.currencyCode),
            "price": current.point.map { MCPPriceValue.json($0.customerPrice) } ?? .null,
            "proceeds": current.point.map { MCPPriceValue.json($0.proceeds) } ?? .null,
            "free": .bool(current.isFree),
        ]
        if !current.otherManualTerritoryIDs.isEmpty { result["setByHandIn"] = .array(current.otherManualTerritoryIDs.map { .string($0) }) }
        if current.laterChangeCount > 0 { result["scheduledChanges"] = .int(current.laterChangeCount) }
        return .object(result)
    }

    func json(_ state: AppAvailabilityState) -> JSONValue {
        guard let availability = state.availability else { return ["state": "notSet"] }
        let writes = AppAvailabilityChangeBuilder.queuedTerritoryWrites(in: queue, appID: app.id)
        var result: [String: JSONValue] = [
            "state": "set",
            "available": .int(availability.availableCount),
            "total": .int(availability.territories.count),
            "availableInNewTerritories": availability.availableInNewTerritories.map { .bool($0) } ?? .null,
            "notAvailable": .array(availability.territories.filter { !$0.isAvailable }.map { .string($0.territoryID) }),
        ]
        if let releaseDate = availability.preOrderReleaseDate { result["preOrderReleaseDate"] = .string(releaseDate) }
        let queued = availability.territories.compactMap { territory -> JSONValue? in
            guard let wanted = writes[territory.id], wanted != territory.isAvailable else { return nil }
            return ["territory": .string(territory.territoryID), "available": .bool(wanted)]
        }
        if !queued.isEmpty { result["queued"] = .array(queued) }
        return .object(result)
    }

    /// A queued change as `{changeId, value, by}`, or null.
    static func json(_ change: PendingChange?) -> JSONValue {
        guard let change else { return .null }
        return ["changeId": .string(change.id), "value": .string(change.newValue), "by": .string(change.source.title)]
    }

    /// `{price, proceeds}` for each point.
    static func json(_ points: [PricePoint], current: Decimal?) -> JSONValue {
        .array(points.map { point in
            var entry: [String: JSONValue] = [
                "price": MCPPriceValue.json(point.customerPrice),
                "proceeds": MCPPriceValue.json(point.proceeds.rounded(scale: 2)),
            ]
            if point.customerPrice == 0 { entry["free"] = true }
            if let current, point.customerPrice == current { entry["current"] = true }
            return .object(entry)
        })
    }

    /// The points around `price` (as `get_price_points` lists them), Free
    /// always among them.
    static func points(in ladder: PricePointLadder, around price: Decimal) -> [PricePoint] {
        var points = GetPricePointsTool.points(in: ladder, around: price)
        if let free = ladder.points.first(where: { $0.customerPrice == 0 }), !points.contains(free) { points.insert(free, at: 0) }
        return points
    }
}
