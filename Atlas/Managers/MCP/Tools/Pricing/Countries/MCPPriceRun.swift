//
//  MCPPriceRun.swift
//  Atlas
//

import Foundation

/// One `propose_prices` call's proposals on their way through the
/// proposers: each country's outcome, its result and its activity line,
/// then the call's result (one proposal's, or a batch's with counts).
@MainActor
struct MCPPriceRun {
    /// One country's proposal, with an outcome decided before the
    /// proposers run (a price point ID that isn't one, no suggestion).
    struct Item {
        var proposal: MCPPriceProposal
        var territory: Territory?
        var preset: MCPPriceProposer.Outcome?

        /// The proposal with its price point ID turned into the point's price.
        @MainActor
        static func prepare(_ proposal: MCPPriceProposal, territory: Territory?, sheet: MCPPriceSheet) -> Item {
            guard let territory, proposal.pricePointID != nil else { return Item(proposal: proposal, territory: territory) }
            let (resolved, refusal) = proposal.resolvingPoint(in: sheet.ladder(for: territory), territory: territory)
            return Item(proposal: resolved, territory: territory, preset: refusal.map { .refused(reason: $0, nearest: []) })
        }
    }

    private(set) var results: [JSONValue] = []
    private(set) var outcomes: [MCPPriceProposer.Outcome] = []
    private(set) var logLines: [MCPToolOutcome.LogLine] = []
    /// A withdraw call: what left reads "withdrawn", counted apart.
    var reportsWithdrawals = false

    /// The changes the call queued, for its how sure.
    var queuedIDs: [PendingChange.ID] {
        outcomes.compactMap { if case let .queued(changeID, _) = $0 { changeID } else { nil } }
    }

    mutating func add(_ proposal: MCPPriceProposal, territoryID: String?, _ outcome: MCPPriceProposer.Outcome, target: String) {
        outcomes.append(outcome)
        results.append(result(proposal, territoryID: territoryID, outcome: outcome))
        logLines.append(Self.logLine(outcome, target: target))
    }

    /// Runs the items through the product's proposer: a subscription's one
    /// country at a time, an in-app purchase's together as its schedule.
    mutating func propose(_ items: [Item], sheet: MCPPriceSheet, source: ChangeSource) {
        var decided: [MCPPriceProposer.Outcome?] = items.map(\.preset)
        if sheet.product.isInAppPurchase {
            let open = items.indices.filter { decided[$0] == nil }
            let iapOutcomes = MCPInAppPurchasePriceProposer(sheet: sheet, source: source).propose(open.map { (items[$0].proposal, items[$0].territory) })
            for (index, outcome) in zip(open, iapOutcomes) {
                decided[index] = outcome
            }
        } else {
            let proposer = MCPPriceProposer(sheet: sheet, source: source)
            for index in items.indices where decided[index] == nil {
                let item = items[index]
                guard let territory = item.territory else {
                    let reason = MCPPriceProposal.unknownTerritoryMessage(item.proposal.territory, product: sheet.product)
                    decided[index] = .refused(reason: reason, nearest: [])
                    continue
                }
                decided[index] = item.proposal.isAutomatic
                    ? proposer.proposeAutomatic(in: territory)
                    : proposer.propose(item.proposal.price, in: territory)
            }
        }
        for (item, outcome) in zip(items, decided) {
            guard let outcome else { continue }
            add(item.proposal, territoryID: item.territory?.id, outcome, target: sheet.target(item.territory?.name ?? item.proposal.territory))
        }
    }

    /// One proposal's result, or a batch's results with counts.
    func outcome(isBatch: Bool) -> MCPToolOutcome {
        guard isBatch || results.count != 1 else { return MCPToolOutcome(result: results[0], isError: false, logLines: logLines) }
        var summary: [String: JSONValue] = [
            "results": .array(results),
            "queued": .int(outcomes.count { if case .queued = $0 { true } else { false } }),
            "unchanged": .int(outcomes.count { if case let .unchanged(_, withdrew) = $0 { !(withdrew && reportsWithdrawals) } else { false } }),
            "refused": .int(outcomes.count { if case .refused = $0 { true } else { false } }),
        ]
        if reportsWithdrawals {
            summary["withdrawn"] = .int(outcomes.count { if case .unchanged(_, true) = $0 { true } else { false } })
        }
        return MCPToolOutcome(result: .object(summary), isError: false, logLines: logLines)
    }

    // MARK: - Private

    private func result(_ proposal: MCPPriceProposal, territoryID: String?, outcome: MCPPriceProposer.Outcome) -> JSONValue {
        var result: [String: JSONValue] = ["territory": .string(territoryID ?? proposal.territory)]
        if proposal.isAutomatic {
            result["automatic"] = true
        } else if let pointID = proposal.pricePointID {
            result["pricePointId"] = .string(pointID)
        } else if !reportsWithdrawals, proposal.price > 0 {
            result["price"] = MCPPriceValue.json(proposal.price)
        }
        switch outcome {
        case let .queued(changeID, competing):
            result["status"] = "queued"
            result["changeId"] = .string(changeID)
            if competing {
                result["note"] = "The person set another price here too. Both wait in Review & Push, where they pick one."
            }
        case let .unchanged(note, withdrew):
            result["status"] = withdrew && reportsWithdrawals ? "withdrawn" : "unchanged"
            result["note"] = .string(note)
        case let .refused(reason, nearest):
            result["status"] = "refused"
            result["reason"] = .string(reason)
            if !nearest.isEmpty { result["nearest"] = .array(nearest.map(MCPPriceValue.json)) }
        }
        return .object(result)
    }

    private static func logLine(_ outcome: MCPPriceProposer.Outcome, target: String) -> MCPToolOutcome.LogLine {
        switch outcome {
        case .queued: MCPToolOutcome.LogLine(target: target, outcome: .proposed)
        case .unchanged: MCPToolOutcome.LogLine(target: target, outcome: .read)
        case let .refused(reason, _): MCPToolOutcome.LogLine(target: target, outcome: .refused, reason: reason)
        }
    }
}
