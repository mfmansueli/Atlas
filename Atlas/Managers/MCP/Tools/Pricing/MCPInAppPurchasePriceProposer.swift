//
//  MCPInAppPurchasePriceProposer.swift
//  Atlas
//

import Foundation

/// `propose_prices` for an in-app purchase: each country's price point, or
/// back to Apple's automatic price, checked like Prices by Country checks
/// them. They wait together as the purchase's one price-schedule change
/// (`InAppPurchaseCountryPrices`); a person's change there stays primary
/// and the assistant's version becomes its alternative.
@MainActor
struct MCPInAppPurchasePriceProposer {
    let sheet: MCPPriceSheet
    let source: ChangeSource

    var queue: ChangeQueue { sheet.workspace.changes }

    var changeID: PendingChange.ID { InAppPurchaseCountryPrices.changeID(productID: sheet.product.id) }

    /// The territories whose price points the change needs: the proposed
    /// ones and those already waiting.
    var queuedTerritoryIDs: [String] {
        queue.change(id: changeID).map { Array(InAppPurchaseCountryPrices.edits(of: $0).keys) } ?? []
    }

    func propose(_ proposals: [(MCPPriceProposal, Territory?)]) -> [MCPPriceProposer.Outcome] {
        let builder = InAppPurchaseCountryPrices(appID: sheet.app.id, product: sheet.product, sheet: sheet.sheet)
        let existing = queue.change(id: changeID)
        let isOwn = existing?.source == source
        var edits = existing.map { InAppPurchaseCountryPrices.edits(of: $0) } ?? [:]
        var outcomes: [MCPPriceProposer.Outcome] = []
        var didChange = false
        for (proposal, territory) in proposals {
            guard let territory, sheet.sheet.prices[territory.id] != nil else {
                outcomes.append(.refused(reason: MCPPriceProposal.unknownTerritoryMessage(proposal.territory, product: sheet.product), nearest: []))
                continue
            }
            let edit: CountryPriceEdit
            if proposal.isAutomatic {
                guard territory.id != sheet.sheet.baseTerritoryID else {
                    outcomes.append(.refused(reason: MCPPriceProposer.baseRefusal(territory), nearest: []))
                    continue
                }
                edit = .automatic
            } else {
                let ladder = sheet.ladder(for: territory)
                guard let point = ladder.point(at: proposal.price) else {
                    outcomes.append(MCPPriceProposer.notAPricePoint(proposal.price, in: territory, ladder: ladder))
                    continue
                }
                edit = .price(point.customerPrice)
            }
            guard builder.isToday(edit, territoryID: territory.id) else {
                edits[territory.id] = edit
                didChange = true
                outcomes.append(.queued(changeID: changeID, competing: false))
                continue
            }
            // Today's price: the assistant's own proposal there leaves; the
            // person's stays.
            if edits[territory.id] != nil, isOwn {
                edits[territory.id] = nil
                didChange = true
                let note = String(localized: "That’s today’s price, so your earlier proposal for this territory was withdrawn.")
                outcomes.append(.unchanged(note: note, withdrew: true))
            } else {
                outcomes.append(.unchanged(note: String(localized: "That’s already today’s price in App Store Connect; nothing was queued."), withdrew: false))
            }
        }
        guard didChange else { return outcomes }
        let ladder = { (territoryID: String) in sheet.territories.territory(alpha3: territoryID).map(sheet.ladder(for:)) }
        if let change = builder.change(edits: edits, ladder: ladder, source: source) {
            queue.upsert(change)
        } else {
            queue.discard(id: changeID)
        }
        let stored = queue.change(id: changeID)
        let competing = stored != nil && stored?.source != source && stored?.alternative?.source == source
        return outcomes.map { outcome in
            if case let .queued(id, _) = outcome { return .queued(changeID: id, competing: competing) }
            return outcome
        }
    }
}
