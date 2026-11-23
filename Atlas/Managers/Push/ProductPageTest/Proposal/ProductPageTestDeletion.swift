//
//  ProductPageTestDeletion.swift
//  Atlas
//

import Foundation

/// Deleting a draft Product Page Optimization test, as a change in Review
/// & Push (`propose_page_test` with `action: deleteDraft`):
/// `DELETE /v2/appStoreVersionExperiments/{id}`, after checking the test is
/// still a draft. Apple's API can't stop a running test, and only a draft
/// is proposed for deletion: App Store Connect runs one test at a time, so
/// a leftover draft blocks the next one.
enum ProductPageTestDeletion {
    static let idPrefix = "pagetest.delete."

    static func changeID(experimentID: String) -> String {
        idPrefix + experimentID
    }

    /// The test IDs whose deletion waits in `changes`.
    static func queuedExperimentIDs(in changes: [PendingChange]) -> Set<String> {
        Set(changes.compactMap { $0.id.hasPrefix(idPrefix) ? String($0.id.dropFirst(idPrefix.count)) : nil })
    }

    /// "Product Page Optimization · Header: Interface vs Outcome".
    static func group(_ experiment: ProductPageExperiment) -> String {
        String(localized: "Product Page Optimization · \(experiment.name ?? experiment.id)")
    }

    static func change(appID: StoreApp.ID, experiment: ProductPageExperiment, source: ChangeSource, reason: String?) -> PendingChange {
        let traffic = experiment.trafficProportion.map { String(localized: ", \($0)% of visitors") } ?? ""
        let path = "/v2/appStoreVersionExperiments/\(experiment.id)"
        return PendingChange(
            id: changeID(experimentID: experiment.id),
            appID: appID,
            section: .screenshots,
            group: group(experiment),
            groupNote: reason.flatMap { $0.isEmpty ? nil : $0 },
            title: String(localized: "Delete the draft test"),
            oldValue: String(localized: "A draft in App Store Connect\(traffic)"),
            newValue: String(localized: "Deleted"),
            source: source,
            requests: [ProductPageExperimentRequests.deleteExperiment(id: experiment.id)],
            // Pushed only while it's still a draft: one sent to App Review
            // since shows as a conflict instead.
            conflictCheck: ConflictCheck(
                path: path + "?fields%5BappStoreVersionExperiments%5D=state", keyPath: ["data", "attributes", "state"], expected: experiment.state
            )
        )
    }
}
