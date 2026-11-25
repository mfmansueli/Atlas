//
//  ProposePricesTool+Bulk.swift
//  Atlas
//

import Foundation

// `propose_prices` over a selection of countries, as Prices by Country's
// selection works: one price for countries sharing a currency, Set N to
// Automatic, Accept N Suggested, or taking back the assistant's own
// proposals. Every country then goes through the same proposer as one
// country's price.
extension ProposePricesTool {
    func callBulk(
        _ request: MCPPriceBulkRequest,
        appID: String,
        productID: String,
        arguments: MCPToolArguments,
        in context: MCPToolContext
    ) async throws -> MCPToolOutcome {
        let layers = try arguments.layers()
        let evidence = try MCPPriceEvidence.read(arguments.values["evidence"])
        let catalog = try await MCPPriceCatalog.load(app: appID, in: context.workspace)
        let target = "\(catalog.app.name) · \(productID)"
        if let refusal = Self.refusal(for: productID, in: catalog), request.action != .withdraw || catalog.product(matching: productID) == nil {
            return .refused(refusal, target: target)
        }
        let product = try catalog.requireProduct(productID)
        guard var sheet = try await catalog.sheetIfPriced(for: product) else {
            return .refused(catalog.noStartingPriceMessage(product), target: "\(catalog.app.name) · \(product.name)")
        }
        let resolution = request.selection.resolve(in: sheet.countryRows())
        guard !resolution.rows.isEmpty || !resolution.unknown.isEmpty else {
            return .refused(Self.emptySelectionRefusal(product), target: sheet.target)
        }
        if case .price = request.action, let refusal = MCPPriceBulkAction.currencyRefusal(resolution.rows) {
            return .refused(refusal, target: sheet.target)
        }
        let problems = request.action == .withdraw ? [] : MCPPriceEvidence.problems(evidence, sales: sheet.sheet.sales, productName: product.name)
        guard problems.isEmpty else { return .refused(problems.joined(separator: " "), target: sheet.target) }

        var run = MCPPriceRun()
        run.reportsWithdrawals = request.action == .withdraw
        for unknown in resolution.unknown {
            let proposal = MCPPriceProposal(territory: unknown, price: 0)
            let reason = MCPPriceProposal.unknownTerritoryMessage(unknown, product: product)
            run.add(proposal, territoryID: nil, .refused(reason: reason, nearest: []), target: sheet.target(unknown))
        }
        let waiting = product.isInAppPurchase ? MCPInAppPurchasePriceProposer(sheet: sheet, source: context.source).queuedTerritoryIDs : []
        try await sheet.loadExactLadders(for: resolution.rows.map(\.id) + waiting)

        if request.action == .withdraw {
            let outcomes = MCPPriceWithdrawer(sheet: sheet, source: context.source).withdraw(resolution.rows.map(\.territory))
            for (row, outcome) in zip(resolution.rows, outcomes) {
                run.add(MCPPriceProposal(territory: row.id, price: 0), territoryID: row.id, outcome, target: sheet.target(row.territory.name))
            }
            return run.outcome(isBatch: request.isBatch)
        }
        let check = MCPPriceProposalCheck(sheet: sheet, evidence: evidence)
        let items = resolution.rows.map { row in
            var item = Self.item(for: row, action: request.action)
            item.proposal.confidence = layers?.confidence
            return check.checked(item)
        }
        run.propose(items, sheet: sheet, source: context.source, details: MCPPriceEvidence.details(evidence) ?? layers?.details)
        run.attachLayers(to: context.workspace.changes)
        return run.outcome(isBatch: request.isBatch)
    }

    /// What the action proposes in one country, or why nothing goes there.
    private static func item(for row: CountryPriceRow, action: MCPPriceBulkAction) -> MCPPriceRun.Item {
        switch action {
        case let .price(price):
            return MCPPriceRun.Item(proposal: MCPPriceProposal(territory: row.id, price: price), territory: row.territory)
        case .automatic:
            let proposal = MCPPriceProposal(territory: row.id, price: 0, isAutomatic: true)
            if row.isBase {
                return MCPPriceRun.Item(proposal: proposal, territory: row.territory, preset: .unchanged(note: baseNote(row), withdrew: false))
            }
            if row.source == .automatic, row.queued == nil || row.queued?.isAutomatic == true {
                let note = MCPPriceBulkAction.alreadyAutomaticNote(row)
                return MCPPriceRun.Item(proposal: proposal, territory: row.territory, preset: .unchanged(note: note, withdrew: false))
            }
            return MCPPriceRun.Item(proposal: proposal, territory: row.territory)
        case .acceptSuggestions:
            guard let suggestion = row.suggestion else {
                let proposal = MCPPriceProposal(territory: row.id, price: 0)
                let note = MCPPriceBulkAction.noSuggestionNote(row)
                return MCPPriceRun.Item(proposal: proposal, territory: row.territory, preset: .unchanged(note: note, withdrew: false))
            }
            return MCPPriceRun.Item(proposal: MCPPriceProposal(territory: row.id, price: suggestion.customerPrice), territory: row.territory)
        case .withdraw:
            return MCPPriceRun.Item(proposal: MCPPriceProposal(territory: row.id, price: 0), territory: row.territory)
        }
    }

    /// The base territory in a group sent to automatic.
    private static func baseNote(_ row: CountryPriceRow) -> String {
        String(localized: "\(row.territory.name) has the base price, which the others follow; it stays.")
    }

    /// `territories` named nothing the product is sold in.
    private static func emptySelectionRefusal(_ product: PricingProduct) -> String {
        String(localized: """
        No country of \(product.name) matches territories. Send codes (BRA), "all", a region, "currency:EUR", \
        "suggested", "setByYou" or "automatic"; get_prices lists the countries and how each is set.
        """)
    }
}
