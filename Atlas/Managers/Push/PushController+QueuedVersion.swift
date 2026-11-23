//
//  PushController+QueuedVersion.swift
//  Atlas
//

import Foundation

// A new version's texts: their placeholders filled in once the version is
// made, in this push or an earlier one (`QueuedVersionPushState`).
extension PushController {
    /// `request` with its new version's placeholders filled in, and the
    /// version whose App Review details it makes, if it does.
    func resolvingQueuedVersion(
        _ request: PushRequest,
        at index: Int,
        transport: any PushTransport
    ) async throws -> (request: PushRequest, makesReviewDetailFor: String?) {
        let appID = items[index].change.appID
        return try await queuedVersions.resolving(
            request,
            appID: appID,
            made: { queuedVersionMade($0, appID: appID) },
            transport: transport,
            note: { noteRequest($0) }
        )
    }

    /// After a `POST` that made a new version's App Review details: the
    /// next fields write into them.
    func noteReviewDetail(madeBy resolved: (request: PushRequest, makesReviewDetailFor: String?), at index: Int) {
        guard let versionID = resolved.makesReviewDetailFor, let id = items[index].createdIDs["appStoreReviewDetails"] else { return }
        queuedVersions.noteReviewDetail(id, versionID: versionID)
    }

    /// A new version's text whose version wasn't created, or a new
    /// subscription's offer whose subscription wasn't: it isn't sent, and
    /// waits in the queue.
    static func waitingStatus(_ error: any Error) -> PushItemStatus? {
        if let error = error as? QueuedSubscriptionPlaceholder.NotCreated { return .notSent(error.errorDescription ?? "") }
        guard let error = error as? QueuedVersionPlaceholder.NotCreated else { return nil }
        return .notSent(error.errorDescription ?? "")
    }

    /// A row's outcome for the push's tally.
    static func outcome(_ status: PushItemStatus, stop: String?) -> PushItemOutcome {
        if case let .failed(text) = status { return .failed(text, stop: stop) }
        return stop.map(PushItemOutcome.stopped) ?? .skipped
    }

    /// Where a new version a text waits for stands in this push: made, its
    /// change here and not made (yet), or not here.
    private func queuedVersionMade(_ placeholder: QueuedVersionPlaceholder, appID: StoreApp.ID) -> QueuedVersionPushState.Made {
        let wanted = NewAppVersion(versionString: placeholder.versionString, platform: placeholder.platform)
        let item = items.first { item in
            NewAppVersionChangeBuilder(appID: appID).owns(item.change) && NewAppVersionChangeBuilder.version(of: item.change) == wanted
        }
        guard let item else { return .notInPush }
        if item.status == .done, let id = item.createdIDs["appStoreVersions"] { return .made(id) }
        return .notMade
    }
}
