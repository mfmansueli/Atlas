//
//  ProposePriceTestTool.swift
//  Atlas
//

import Foundation

/// `propose_price_test` (board 76): suggests a 28-day price test in one
/// region for a subscription. It becomes a card in the product's Results
/// with Set Up Test…, which opens the same sheet filled in; the person
/// starts it. Nothing is queued or pushed.
struct ProposePriceTestTool: MCPTool {
    var now: () -> Date = { .now }
    var store: @MainActor () -> PriceTestStore = { .shared }

    let definition = MCPToolDefinition(
        name: "propose_price_test",
        title: "Suggest a price test",
        description: """
        Suggests a price test: one region (americas, europe, asiaPacific or africaMiddleEast) pays a different price \
        for one subscription for 28 days, compared with a region whose price stays the same, so Results can say what \
        the price did and that region's suggestions can become Sure. step is -10, -20, -30, 10, 20 (percent) or \
        suggested (each country to its suggested price). Read get_prices and get_price_tests first: a region needs 30 \
        starts and 100 page views in 28 days, and one test per region runs at a time. Give a title (at most 8 words, \
        e.g. “Test suggested prices in Asia Pacific”) and why with one number. It waits as a card in the product's \
        Results; the person sets it up and starts it. You never start, change or end a test. withdraw: true takes \
        your card back.
        """,
        inputSchema: MCPToolDefinition.schema(
            MCPToolDefinition.withLayers([
                "appId": MCPToolDefinition.string("The app's Apple ID, bundle ID, SKU or name, from list_apps."),
                "productId": MCPToolDefinition.string("The subscription's Apple ID, product ID or name."),
                "region": MCPToolDefinition.string("americas, europe, asiaPacific or africaMiddleEast."),
                "step": MCPToolDefinition.string("-10, -20, -30, 10, 20 (percent from today's prices) or suggested."),
                "title": MCPToolDefinition.string("What to test, at most 8 words, e.g. “Test suggested prices in Asia Pacific”."),
                "why": MCPToolDefinition.why("Why test it, for the person."),
                "withdraw": ["type": "boolean", "description": "true: take back your suggested tests for this product."],
            ]),
            required: ["appId", "productId"]
        ),
        proposalKind: .prices
    )

    func call(_ arguments: MCPToolArguments, in context: MCPToolContext) async throws -> MCPToolOutcome {
        let catalog = try await MCPPriceCatalog.load(app: arguments.string("appId"), in: context.workspace)
        let product = try catalog.requireProduct(arguments.string("productId"))
        let target = String(localized: "\(catalog.app.name) · \(product.name) · Price test", comment: "kind:other")
        guard context.allows(.prices) else { return .refused(MCPProposalKind.prices.refusal, target: target) }
        if let refusal = PriceTestProposalCheck.actingRefusal(arguments.values) { return .refused(refusal, target: target) }
        let store = store()
        if try arguments.optionalBool("withdraw") == true {
            let mine = store.book(for: catalog.app.id).suggestions.filter { $0.productID == product.id && $0.source == context.clientName }
            guard !mine.isEmpty else {
                return .refused(String(localized: "No suggested test of yours waits for \(product.name).", comment: "kind:error"), target: target)
            }
            store.update(catalog.app.id) { book in
                book.suggestions.removeAll { $0.productID == product.id && $0.source == context.clientName }
            }
            return MCPToolOutcome(result: ["status": "withdrawn"], isError: false, logLines: [.init(target: target, outcome: .proposed)])
        }
        guard !product.isInAppPurchase else {
            return .refused(String(localized: "Price tests are for subscriptions; \(product.name) is an in-app purchase.", comment: "kind:error"), target: target)
        }
        let regionText = try arguments.string("region")
        guard let region = PriceTestProposalCheck.region(regionText) else {
            throw MCPToolError.invalidArgument(name: "region", expected: "americas, europe, asiaPacific or africaMiddleEast")
        }
        guard let step = try PriceTestStep(argument: arguments.string("step")) else {
            throw MCPToolError.invalidArgument(name: "step", expected: "-10, -20, -30, 10, 20 or suggested")
        }
        let title = try arguments.string("title")
        let why = try arguments.string("why")
        if let refusal = PriceTestProposalCheck.textRefusal(title: title, why: why) { return .refused(refusal, target: target) }
        let tests = store.tests(for: catalog.app.id).filter { test in
            test.state != .queued || context.workspace.changes.change(id: PriceTestChanges.changeID(.start, testID: test.id)) != nil
        }
        if let refusal = PriceTestProposalCheck.busyRefusal(region, tests: tests, today: now()) { return .refused(refusal, target: target) }
        let suggestion = try PriceTestSuggestion(
            id: "pts-\(UUID().uuidString.prefix(8).lowercased())", productID: product.id, region: region, step: step,
            title: title, why: why, layers: arguments.layers(), source: context.clientName, receivedAt: now()
        )
        store.update(catalog.app.id) { book in
            // A new suggestion for the same region replaces yours.
            book.suggestions.removeAll { $0.productID == product.id && $0.region == region && $0.source == context.clientName }
            book.suggestions.append(suggestion)
        }
        return MCPToolOutcome(
            result: [
                "status": "suggested",
                "suggestionId": .string(suggestion.id),
                "showsIn": .string("\(product.name) → Results, as a card with Set Up Test…. The person starts the test; nothing is queued or pushed."),
            ],
            isError: false,
            logLines: [.init(target: target, outcome: .proposed)]
        )
    }
}
