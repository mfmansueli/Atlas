//
//  MCPPriceProposalCheck.swift
//  Atlas
//

import Foundation

/// propose_prices' checks beyond the price point, like an edit in Prices
/// by Country:
///
/// - No price stands on a simulated grid: the tool reads Apple's points
///   first (it waits for the read rather than refusing, since only
///   Apple's points can be pushed), and refuses a country whose points
///   still aren't here.
/// - How sure can't be higher than what Atlas's own evidence supports in
///   the country (`PriceConfidenceRule`, get_prices' `howSure`): the
///   refusal says how far it goes and why, so the assistant sends it
///   again. A price from the project's own code (evidence `project`)
///   mirrors a price rather than judging demand, so it isn't capped.
@MainActor
struct MCPPriceProposalCheck {
    let sheet: MCPPriceSheet
    let pooling: ConversionPooling
    let mirrorsProject: Bool

    init(sheet: MCPPriceSheet, evidence: [MCPPriceEvidence]) {
        self.sheet = sheet
        pooling = sheet.pooling
        mirrorsProject = MCPPriceEvidence.mirrorsProject(evidence)
    }

    /// The item with its refusal, when it has none yet.
    func checked(_ item: MCPPriceRun.Item) -> MCPPriceRun.Item {
        guard item.preset == nil, let territory = item.territory, let reason = refusal(for: item.proposal, in: territory) else { return item }
        var item = item
        item.preset = .refused(reason: reason, nearest: [])
        return item
    }

    /// Why the proposal can't be queued in the territory, or nil.
    func refusal(for proposal: MCPPriceProposal, in territory: Territory) -> String? {
        guard let current = sheet.sheet.prices[territory.id]?.current else { return nil }
        // An in-app purchase back on Apple's automatic price needs no point.
        let needsPoint = !(proposal.isAutomatic && sheet.product.isInAppPurchase)
        if needsPoint, !sheet.sheet.hasRealGrid(territory.id) { return Self.gridRefusal(territory) }
        // Today's price withdraws; how sure doesn't matter then.
        let isToday = !proposal.isAutomatic && !PricingRow.differs(proposal.price, current.customerPrice)
        guard let claimed = proposal.confidence, !mirrorsProject, !isToday,
              let atlas = sheet.confidence(in: territory, pooling: pooling), claimed > atlas.howSure
        else { return nil }
        return Self.capRefusal(territory, atlas: atlas)
    }

    /// "Checking Apple's prices in Brazil first. Try again in a minute."
    static func gridRefusal(_ territory: Territory) -> String {
        String(localized: "Checking Apple’s prices in \(territory.name) first. Try again in a minute.", comment: "kind:other")
    }

    /// "In Brazil, how sure can be at most Not very sure (1): Purchasing
    /// power only: no sales yet. Send confidence 1 or leave it out."
    static func capRefusal(_ territory: Territory, atlas: PriceConfidence) -> String {
        let word = atlas.howSure.word
        let value = atlas.howSure.rawValue
        return value == HowSure.notVerySure.rawValue
            ? String(
                localized: "In \(territory.name), how sure can be at most \(word) (\(value)): \(atlas.reason) Send confidence \(value) or leave it out.",
                comment: "kind:other"
            )
            : String(
                localized: "In \(territory.name), how sure can be at most \(word) (\(value)): \(atlas.reason) Send confidence \(value) or lower.",
                comment: "kind:other"
            )
    }
}
