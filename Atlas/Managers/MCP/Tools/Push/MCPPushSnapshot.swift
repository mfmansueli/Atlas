//
//  MCPPushSnapshot.swift
//  Atlas
//

import Foundation

/// What Review & Push is doing, as the MCP tools read it: whether a push
/// runs, and where each change of the push running now (or the one that
/// just finished, until the person clears it) stands. Read from
/// `PushController` when a tool runs; tools never start, stop or retry a
/// push.
struct MCPPushSnapshot: Hashable, Sendable {
    /// One change in the push.
    struct Item: Hashable, Sendable {
        var changeID: PendingChange.ID
        var appID: StoreApp.ID
        var section: AppWorkspaceSection
        /// The event a change of In-App Events belongs to.
        var groupID: String?
        var title: String
        var status: PushItemStatus
        /// How far a long step got, e.g. "Uploading event card · part 2 of 3".
        var progressNote: String?

        /// `queued`, `sending` (with `progress`), `done`, `failed` (with
        /// `reason`), `conflict` or `notSent` (with `reason`).
        var statusName: String {
            switch status {
            case .queued: "queued"
            case .sending: "sending"
            case .done: "done"
            case .failed: "failed"
            case .conflict: "conflict"
            case .notSent: "notSent"
            }
        }

        /// `{changeId, eventId, title, status, progress | reason}`.
        var json: JSONValue {
            var object: [String: JSONValue] = [
                "changeId": .string(changeID), "title": .string(title), "status": .string(statusName),
            ]
            if let groupID { object["eventId"] = .string(groupID) }
            switch status {
            case .sending:
                if let progressNote { object["progress"] = .string(progressNote) }
            case let .failed(reason), let .notSent(reason):
                object["reason"] = .string(reason)
            case .conflict:
                object["reason"] = "App Store Connect has a different value now: it waits in Review & Push for the person."
            case .queued, .done:
                break
            }
            return .object(object)
        }
    }

    var isRunning: Bool
    var items: [Item]

    init(isRunning: Bool, items: [Item] = []) {
        self.isRunning = isRunning
        self.items = items
    }

    @MainActor
    init(_ push: PushController) {
        self.init(isRunning: push.isRunning, items: push.items.map { item in
            Item(
                changeID: item.id, appID: item.change.appID, section: item.change.section, groupID: item.change.groupID,
                title: item.change.title, status: item.status, progressNote: item.progressNote
            )
        })
    }

    /// The changes of one app's section in the push.
    func items(appID: StoreApp.ID, section: AppWorkspaceSection) -> [Item] {
        items.filter { $0.appID == appID && $0.section == section }
    }
}
