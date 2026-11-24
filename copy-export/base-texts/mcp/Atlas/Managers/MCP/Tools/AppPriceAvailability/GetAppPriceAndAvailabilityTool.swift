//
//  GetAppPriceAndAvailabilityTool.swift
//  Atlas
//

import Foundation

/// `get_app_price_and_availability`: the app's own price (App Store
/// Connect's Price Schedule) and where it's sold (App Availability), with
/// what waits in Review & Push and, when asked, Apple's price points in a
/// territory.
struct GetAppPriceAndAvailabilityTool: MCPTool {
    let definition = MCPToolDefinition(
        name: "get_app_price_and_availability",
        title: "Get app price and availability",
        description: """
        Reads what an app itself costs to download and where it's sold, as App Store Connect's Pricing and \
        Availability page has them. price.state is "notSet" for an app that has never had a price (it can't be \
        sold until it has one) or "set" with the base territory, today's price there (0 is Free), Apple's proceeds \
        and anything a new price would replace. availability.state is "notSet" for an app without an availability, \
        else the counts, the territories it isn't sold in and whether new territories get it. queuedPrice and \
        queuedAvailability are what waits in Review & Push. Pass territory (and near, a price) to list Apple's price \
        points there: only those can be proposed with propose_app_price. Subscription and in-app purchase prices \
        are get_prices.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "territory": MCPToolDefinition.string("Lists Apple's price points in this territory, e.g. USA or US."),
                "near": ["type": "number", "description": "A price in the territory's currency to list points around. Defaults to today's."],
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let sale = try await MCPAppPriceAvailability.load(app: arguments.string("appId"), in: context.workspace)
        let price = try await sale.price()
        let availability = try await sale.availability()
        var result: [String: JSONValue] = [
            "app": .string(sale.app.name),
            "price": MCPAppPriceAvailability.json(price),
            "queuedPrice": MCPAppPriceAvailability.json(AppPriceChangeBuilder.queued(in: sale.queue, appID: sale.app.id)),
            "availability": sale.json(availability),
            "queuedAvailability": MCPAppPriceAvailability.json(AppAvailabilityChangeBuilder.queuedSetup(in: sale.queue, appID: sale.app.id)),
        ]
        if availability.availability == nil, let territories = try? await sale.territories() {
            result["territoryCount"] = .int(territories.count)
        }
        if let code = try arguments.optionalString("territory") {
            result["pricePoints"] = try await points(sale: sale, code: code, near: arguments.values["near"], current: price.current)
        }
        result["note"] = .string(Self.note(price: price, availability: availability))
        return .read(.object(result), target: "\(sale.app.name) · App price and availability")
    }

    private func points(sale: MCPAppPriceAvailability, code: String, near: JSONValue?, current: AppCurrentPrice?) async throws -> JSONValue {
        let territories = try await sale.territories()
        guard let territoryID = MCPAppPriceAvailability.territoryID(matching: code, among: territories.map(\.id)) else {
            throw MCPToolError.invalidArgument(name: "territory", expected: String(localized: "a territory code such as USA or US"))
        }
        let ladder = try await sale.ladder(in: territoryID)
        let today = current?.baseTerritoryID == territoryID ? current?.point?.customerPrice : nil
        let around = near.flatMap(MCPAppPriceAvailability.price(from:)) ?? today ?? 0
        return [
            "territory": .string(territoryID),
            "currency": .string(ladder.currencyCode),
            "count": .int(ladder.points.count),
            "points": MCPAppPriceAvailability.json(MCPAppPriceAvailability.points(in: ladder, around: around), current: today),
        ]
    }

    private static func note(price: AppPriceState, availability: AppAvailabilityState) -> String {
        var notes: [String] = []
        if price.current == nil {
            notes.append(String(localized: "No price yet: propose one with propose_app_price (0 for Free)."))
        }
        if availability.availability == nil {
            notes.append(String(localized: "No availability yet: propose one with propose_availability (every territory by default)."))
        } else {
            notes.append(String(localized: """
            Change single territories with propose_availability's makeAvailable and makeUnavailable. Apple's API can't \
            change availableInNewTerritories once the availability exists.
            """))
        }
        return notes.joined(separator: " ")
    }
}
