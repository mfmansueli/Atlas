//
//  ReviewPushViewModel+Extras.swift
//  Atlas
//

import Foundation

/// Autopilot's extras in Review & Push, in the same scope as the
/// screenshots: each app's header, search image and App Previews, their own
/// push, and the Product Page Optimization sheet.
extension ReviewPushViewModel {
    var extras: ExtrasPushController { screenshots.extras }

    var extrasPlans: [ExtrasReviewPlan] {
        switch scope {
        case .thisApp: extras.plans(for: selectedAppID.map { [$0] } ?? [])
        case .allApps: extras.orderedPlans
        // A page's own screenshots are its changes, not Autopilot's extras.
        case .productPage: []
        case let .section(section):
            section == .screenshots ? extras.plans(for: selectedAppID.map { [$0] } ?? []) : []
        }
    }

    var showsExtras: Bool { !extrasPlans.isEmpty }

    /// The extras waiting in scope.
    var visibleExtras: [ExtrasReviewItem] { extrasPlans.flatMap(\.items) }

    /// Discard All's part for the extras.
    func discardVisibleExtras() async {
        await screenshots.discardExtras(visibleExtras)
    }

    func undoExtrasDiscards(_ plan: ExtrasReviewPlan) async {
        await screenshots.undoExtrasDiscards(appIDs: [plan.appID])
    }

    func pushExtras(_ plan: ExtrasReviewPlan) {
        screenshots.pushExtras([plan])
    }

    /// “Asset Library…”: the app's uploaded files, to delete leftovers.
    func openAssetLibrary(_ plan: ExtrasReviewPlan) {
        extras.library = screenshots.assetLibraryModel(appID: plan.appID)
    }

    /// “Test with Product Page Optimization…”.
    func openTest(_ plan: ExtrasReviewPlan, placement: ProductPageTestPlacement) {
        extras.test = screenshots.testModel(for: plan, placement: placement)
    }

    /// “Review Test…” on an assistant's proposed test: the sheet, prefilled.
    func openProposedTest(_ plan: ExtrasReviewPlan, proposal: ProductPageTestProposal) {
        extras.test = screenshots.proposedTestModel(for: plan, proposal: proposal)
    }

    /// “Dismiss” on a proposed test: it leaves Review & Push.
    func dismissTestProposal(_ plan: ExtrasReviewPlan, proposal: ProductPageTestProposal) async {
        await screenshots.decideTestProposal(appID: plan.appID, id: proposal.id, status: .dismissed)
    }
}
