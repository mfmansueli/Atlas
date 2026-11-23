//
//  ScreenshotPushController+TestProposals.swift
//  Atlas
//

import Foundation

/// Product Page Optimization tests assistants proposed (`propose_page_test`):
/// Review & Push opens one in “Test with Product Page Optimization…”,
/// prefilled, and records it as made once the person creates it, or as
/// dismissed. Either way it leaves the card and stays in the set with its
/// status, which `get_page_tests` reports.
extension ScreenshotPushController {
    /// The sheet for `proposal`, prefilled with its name, traffic,
    /// treatment and languages.
    func proposedTestModel(for plan: ExtrasReviewPlan, proposal: ProductPageTestProposal) -> ProductPageTestModel? {
        let model = testModel(for: plan, placement: proposal.placement, proposal: proposal)
        model?.onProposalMade = { [weak self] id, outcome in
            await self?.decideTestProposal(appID: plan.appID, id: id, status: .made, outcome: outcome)
        }
        return model
    }

    /// Moves an open proposal to `status`, saves the set and plans the
    /// app's extras again.
    func decideTestProposal(
        appID: StoreApp.ID, id: ProductPageTestProposal.ID, status: ProductPageTestProposalStatus, outcome: String? = nil
    ) async {
        guard let workspace, let app = apps[appID], let context = contexts[appID] else { return }
        do {
            var document = try await workspace.screenshots.loadDocument(for: app, primaryLocale: context.primaryLocale)
            guard var made = document.extras, made.decideTestProposal(id: id, status: status, outcome: outcome, at: now()) else { return }
            document.extras = made
            try await workspace.screenshots.saveDocument(document, for: app)
            planExtras(for: app, document: document, context: context)
            bumpRevision(for: appID)
        } catch {
            extras.recordError = String(localized: "Couldn’t change \(app.name)’s proposed test: \(error.localizedDescription)")
        }
    }
}
