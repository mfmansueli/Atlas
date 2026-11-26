//
//  ActivityRestore.swift
//  Atlas
//

import Foundation

/// Restore Previous Values: the values from before a push go back into
/// Review & Push as new changes, on the To Push tab. It never pushes; the
/// toast says so.
@MainActor
enum ActivityRestore {
    /// Queues `record`'s old values in `queue`; the toast to show, or nil
    /// when none of its changes can be put back.
    @discardableResult
    static func restore(_ record: PushRecord, into queue: ChangeQueue, at date: Date = .now) -> ToastMessage? {
        let restoring = record.restoringChanges(at: date)
        guard !restoring.isEmpty else { return nil }
        queue.upsert(contentsOf: restoring)
        return ToastMessage(text: ActivityText.restored(restoring.count))
    }
}
