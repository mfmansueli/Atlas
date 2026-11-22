//
//  AutopilotCenter+RecaptureRequests.swift
//  Atlas
//

import Foundation

/// Captures the assistant asked to redo while no run was open for them
/// (`request_recapture`, `request_page_recapture`): they wait in
/// Screenshots for Accept, which opens the capture-only run (or turns on
/// the page's Capture Screens Again), or Decline.
extension AutopilotCenter {
    /// The app's requests waiting for the person, oldest first.
    func recaptureRequests(for appID: StoreApp.ID) -> [AutopilotRecaptureRequest] {
        planProposals(for: appID).recaptureRequests
    }

    /// Queues `request`; what it asks for again takes the place of what an
    /// earlier request still waits with.
    @discardableResult
    func queueRecapture(_ request: AutopilotRecaptureRequest, appID: StoreApp.ID) -> AutopilotRecaptureRequest {
        updatePlanProposals(appID) { proposals in
            proposals.recaptureRequests = proposals.recaptureRequests.map { $0.without(request) }.filter { !$0.isEmpty } + [request]
        }
        return request
    }

    /// Accept on a request for the set's captures: the capture-only run
    /// opens. With no saved run it's made from the set's captures:
    /// `fromCaptures` as the set is now, else the request's own. A page's
    /// request is the page's to accept (`PageShotsStudio.acceptRecapture`).
    @discardableResult
    func acceptRecapture(_ id: String, appID: StoreApp.ID, fromCaptures: AutopilotRecapturePlanFromCaptures? = nil) throws -> AutopilotRun {
        guard let request = recaptureRequests(for: appID).first(where: { $0.id == id }), request.page == nil else {
            throw AutopilotError(String(localized: "That request isn’t waiting any more."))
        }
        // The set as it is now, when it still has every capture asked for.
        let fresh = fromCaptures.flatMap { Set(request.targets).isSubset(of: $0.capturedTargets) ? $0 : nil }
        let run = try openRecapture(
            appID: appID, targets: request.targets, momentIDs: request.momentIDs, reason: request.reason, evidence: request.evidence,
            client: request.client, requestID: request.id, fromCaptures: fresh ?? request.fromCaptures
        )
        removeRecaptureRequest(id, appID: appID)
        return run
    }

    /// Decline: nothing is redone.
    func declineRecapture(_ id: String, appID: StoreApp.ID) {
        removeRecaptureRequest(id, appID: appID)
    }

    func removeRecaptureRequest(_ id: String, appID: StoreApp.ID) {
        updatePlanProposals(appID) { $0.recaptureRequests.removeAll { $0.id == id } }
    }

    /// A request's ID: "rr-1a2b3c4d".
    func makeRecaptureRequestID() -> String {
        "rr-" + makeID().prefix(8)
    }
}
