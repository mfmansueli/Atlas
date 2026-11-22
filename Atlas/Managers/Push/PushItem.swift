//
//  PushItem.swift
//  Atlas
//

import Foundation

/// One row of the push progress list: the change as it was when the push
/// started, and how far it got.
struct PushItem: Identifiable, Hashable, Sendable {
    var change: PendingChange
    var status: PushItemStatus = .queued
    /// Requests already accepted, so a retry resumes after them instead of
    /// sending them twice.
    var sentRequestCount = 0
    /// The ID App Store Connect gave a resource this change's `POST`
    /// created, for later requests that use `{createdID}`. Kept across a
    /// retry, like `sentRequestCount`.
    var createdID: String?
    /// Every resource this change's `POST`s created, by type, for later
    /// requests that use `{createdID:<type>}`. Kept across a retry.
    var createdIDs: [String: String] = [:]
    /// The name of a custom product page this change's create may have
    /// made: Apple failed on it (a 5xx or no answer), and the page wasn't
    /// there ready yet, or later writes failed. A retry that finds a page of
    /// this name goes on with it instead of refusing it as made by another
    /// push (`ProductPageCreate`). Kept across a retry, even after an edit.
    var mayHaveMadePage: String?
    /// How far a long step of a sending change got, e.g. "Prices · 40 of
    /// 175"; nil otherwise.
    var progressNote: String?

    var id: PendingChange.ID { change.id }

    /// The change's own requests went through and its option's are being
    /// sent now, e.g. "Publishing…" after a declaration was saved.
    var isSendingOption: Bool {
        guard status == .sending, let option = change.option, option.isEffective else { return false }
        return sentRequestCount >= change.requests.count
    }
}
