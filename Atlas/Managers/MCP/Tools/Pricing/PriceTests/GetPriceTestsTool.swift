//
//  GetPriceTestsTool.swift
//  Atlas
//

import Foundation

/// `get_price_tests` (board 76): an app's price tests, queued, running
/// and finished, with their countries, comparison and result, and the
/// tests you suggested that wait. Read-only.
struct GetPriceTestsTool: MCPTool {
    var now: () -> Date = { .now }
    var store: @MainActor () -> PriceTestStore = { .shared }

    let definition = MCPToolDefinition(
        name: "get_price_tests",
        title: "Get the price tests",
        description: """
        Lists an app's price tests, newest first: product, region, step, state (queued, running, endedEarly, kept, \
        done) and phase (queued, running, waitingForResult, ready, kept, ended, done), day of 28, start and end, the \
        comparison region, each country's old → test price, and once Apple's reports cover the 28 days the result: \
        verdict (better, aboutTheSame, worse, tooLittleData), howSure, points against the comparison with its 90% \
        range, and both regions' 28 days before and during. suggestions are tests you proposed with \
        propose_price_test that wait. Read-only: you never start, change or end a test.
        """,
        inputSchema: MCPToolDefinition.schema(
            [
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "productId": MCPToolDefinition.string("Only this subscription: its Apple ID, product ID or name."),
            ],
            required: ["appId"]
        )
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let product = try arguments.optionalString("productId").map { try catalog.requireProduct($0) }
        let book = store().book(for: catalog.app.id)
        let today = now()
        let tests = book.tests
            .filter { product == nil || $0.productID == product?.id }
            .filter { $0.state != .queued || context.workspace.changes.change(id: PriceTestChanges.changeID(.start, testID: $0.id)) != nil }
            .sorted { $0.createdAt > $1.createdAt }
        let suggestions = book.suggestions.filter { product == nil || $0.productID == product?.id }
        var result: [String: JSONValue] = [
            "appId": .string(catalog.app.id),
            "app": .string(catalog.app.name),
            "tests": .array(tests.map { Self.json($0, today: today) }),
            "suggestions": .array(suggestions.map(Self.json)),
        ]
        if tests.isEmpty { result["note"] = "No price tests yet. Suggest one with propose_price_test; the person starts it." }
        return .read(.object(result), target: String(localized: "\(catalog.app.name) · Price tests", comment: "kind:other"))
    }

    static func json(_ test: PriceTest, today: Date) -> JSONValue {
        var object: [String: JSONValue] = [
            "id": .string(test.id),
            "productId": .string(test.productID),
            "product": .string(test.productName),
            "region": .string(test.region.rawValue),
            "step": .string(test.step.argument),
            "state": .string(test.state.rawValue),
            "phase": .string(phaseName(test.phase(on: today))),
            "keepsTestPrice": .bool(test.keepsTestPrice),
            "countries": .array(test.countries.map { country in
                [
                    "territory": .string(country.territoryID),
                    "currency": .string(country.currencyCode),
                    "old": MCPPriceValue.json(country.oldPrice),
                    "test": MCPPriceValue.json(country.testPrice),
                ]
            }),
        ]
        object["comparison"] = test.control.map { .string($0.rawValue) } ?? .null
        if let startedOn = test.startedOn { object["startedOn"] = .string(MCPPriceTrustJSON.day(startedOn)) }
        if let endsOn = test.endsOn { object["endsOn"] = .string(MCPPriceTrustJSON.day(endsOn)) }
        if test.isLive(on: today) { object["day"] = .int(test.day(on: today)) }
        if let result = test.result {
            var verdict: [String: JSONValue] = [
                "verdict": .string(result.verdict.rawValue),
                "verdictTitle": .string(result.verdict.title),
                "points": .double(rounded(result.points)),
                "low": .double(rounded(result.low)),
                "high": .double(rounded(result.high)),
                "testBefore": MCPPriceTrustJSON.signal(result.windows.testBefore),
                "testDuring": MCPPriceTrustJSON.signal(result.windows.testDuring),
            ]
            if let howSure = result.howSure { verdict["howSure"] = .string(howSure.word) }
            if let before = result.windows.controlBefore { verdict["comparisonBefore"] = MCPPriceTrustJSON.signal(before) }
            if let during = result.windows.controlDuring { verdict["comparisonDuring"] = MCPPriceTrustJSON.signal(during) }
            object["result"] = .object(verdict)
        }
        return .object(object)
    }

    static func json(_ suggestion: PriceTestSuggestion) -> JSONValue {
        [
            "suggestionId": .string(suggestion.id),
            "productId": .string(suggestion.productID),
            "region": .string(suggestion.region.rawValue),
            "step": .string(suggestion.step.argument),
            "title": .string(suggestion.title),
            "why": .string(suggestion.why),
            "source": .string(suggestion.source),
        ]
    }

    private static func phaseName(_ phase: PriceTestPhase) -> String {
        switch phase {
        case .queued: "queued"
        case .running: "running"
        case .waitingForResult: "waitingForResult"
        case .ready: "ready"
        case .kept: "kept"
        case .ended: "ended"
        case .done: "done"
        }
    }

    private static func rounded(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}
