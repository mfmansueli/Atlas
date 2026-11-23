//
//  ScreenshotExtras+TestProposals.swift
//  Atlas
//

import Foundation

/// The Product Page Optimization tests assistants proposed, kept with the
/// extras they test.
extension ScreenshotExtras {
    /// Extras with nothing made, to hold a proposal for an app Autopilot
    /// made no artwork for (a treatment from the library).
    static func holdingProposals(at date: Date) -> ScreenshotExtras {
        ScreenshotExtras(directionName: "", madeAt: date)
    }

    /// The ones waiting for the person, oldest first.
    var openTestProposals: [ProductPageTestProposal] {
        (testProposals ?? []).filter(\.isOpen)
    }

    func testProposal(id: ProductPageTestProposal.ID) -> ProductPageTestProposal? {
        testProposals?.first { $0.id == id }
    }

    /// Adds `proposal`, in place of the same assistant's open one for the
    /// same placement; the ID it replaced, if any.
    @discardableResult
    mutating func receive(_ proposal: ProductPageTestProposal) -> ProductPageTestProposal.ID? {
        var proposals = testProposals ?? []
        let replaced = proposals.first { $0.isOpen && $0.client == proposal.client && $0.placement == proposal.placement }
        proposals.removeAll { $0.id == replaced?.id }
        proposals.append(proposal)
        testProposals = proposals
        return replaced?.id
    }

    /// Moves an open proposal to `status`; false when it isn't open (or
    /// isn't there).
    @discardableResult
    mutating func decideTestProposal(
        id: ProductPageTestProposal.ID, status: ProductPageTestProposalStatus, outcome: String? = nil, at date: Date
    ) -> Bool {
        guard var proposals = testProposals, let index = proposals.firstIndex(where: { $0.id == id }), proposals[index].isOpen else {
            return false
        }
        proposals[index].status = status
        proposals[index].outcome = outcome
        proposals[index].decidedAt = date
        testProposals = proposals
        return true
    }
}
