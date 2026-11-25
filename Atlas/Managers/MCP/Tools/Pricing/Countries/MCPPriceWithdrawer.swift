//
//  MCPPriceWithdrawer.swift
//  Atlas
//

import Foundation

/// Takes back an assistant's own proposals for some countries of one
/// product: a subscription's change per country, or those countries in an
/// in-app purchase's one schedule change. The person's changes stay; an
/// assistant's version beside the person's leaves (for an in-app purchase,
/// that version covers every country, so it leaves whole).
@MainActor
struct MCPPriceWithdrawer {
    let sheet: MCPPriceSheet
    let source: ChangeSource

    var queue: ChangeQueue { sheet.workspace.changes }

    func withdraw(_ territories: [Territory]) -> [MCPPriceProposer.Outcome] {
        sheet.product.isInAppPurchase ? withdrawInAppPurchase(territories) : territories.map(withdrawSubscription)
    }

    /// "Your proposal for Brazil was withdrawn."
    static func withdrewNote(_ territory: Territory) -> String {
        String(localized: "Your proposal for \(territory.name) was withdrawn.")
    }

    /// Nothing of the caller's waits there.
    static func nothingNote(_ territory: Territory) -> String {
        String(localized: "No proposal of yours waits for \(territory.name); nothing changed.")
    }

    // MARK: - Private

    private func withdrawSubscription(_ territory: Territory) -> MCPPriceProposer.Outcome {
        guard let existing = sheet.queuedChange(for: territory) else { return .unchanged(note: Self.nothingNote(territory), withdrew: false) }
        if existing.source == source {
            queue.discard(id: existing.id)
        } else if existing.alternative?.source == source {
            queue.resolveAlternative(id: existing.id, keepAlternative: false)
        } else {
            return .unchanged(note: Self.nothingNote(territory), withdrew: false)
        }
        sheet.refreshSummary()
        return .unchanged(note: Self.withdrewNote(territory), withdrew: true)
    }

    private func withdrawInAppPurchase(_ territories: [Territory]) -> [MCPPriceProposer.Outcome] {
        let id = InAppPurchaseCountryPrices.changeID(productID: sheet.product.id)
        guard let existing = queue.change(id: id) else { return territories.map { .unchanged(note: Self.nothingNote($0), withdrew: false) } }
        if existing.alternative?.source == source {
            queue.resolveAlternative(id: id, keepAlternative: false)
            return territories.map { .unchanged(note: Self.withdrewNote($0), withdrew: true) }
        }
        guard existing.source == source else { return territories.map { .unchanged(note: Self.nothingNote($0), withdrew: false) } }
        var edits = InAppPurchaseCountryPrices.edits(of: existing)
        let outcomes = territories.map { territory -> MCPPriceProposer.Outcome in
            guard edits.removeValue(forKey: territory.id) != nil else { return .unchanged(note: Self.nothingNote(territory), withdrew: false) }
            return .unchanged(note: Self.withdrewNote(territory), withdrew: true)
        }
        let builder = InAppPurchaseCountryPrices(appID: sheet.app.id, product: sheet.product, sheet: sheet.sheet)
        let ladder = { (territoryID: String) in sheet.territories.territory(alpha3: territoryID).map(sheet.ladder(for:)) }
        if let change = builder.change(edits: edits, ladder: ladder, source: source) {
            queue.upsert(change)
        } else {
            queue.discard(id: id)
        }
        return outcomes
    }
}
