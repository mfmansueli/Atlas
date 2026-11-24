//
//  NominationsViewModel+Queue.swift
//  Atlas
//

import Foundation

/// Nominations' Review & Push rows, each its own: Add to Review & Push
/// (create or update the draft), Submit… and Archive… after their
/// confirmation, Delete Draft, and taking any of them out again.
extension NominationsViewModel {
    /// The nomination's rows in Review & Push, by kind.
    func queued(_ id: String) -> [NominationChangeBuilder.Kind: PendingChange] {
        builder.queued(for: id, in: queue.changes(for: app.id, section: .nominations))
    }

    /// Why it can't be added or submitted, each saying how to fix it; empty
    /// when it can.
    func problems(_ nomination: Nomination) -> [String] {
        var problems = nomination.content.problems(now: now())
        if keyCannotWrite { problems.insert(String(localized: "This key can’t create nominations.", comment: "kind:error"), at: 0) }
        return problems
    }

    /// The first problem, for a disabled button's help.
    func blockingReason(_ nomination: Nomination) -> String? {
        problems(nomination).first
    }

    /// Whether Add to Review & Push has something to add: a draft on this
    /// Mac not queued yet, or a draft in App Store Connect with edits.
    func canAddToReviewPush(_ nomination: Nomination) -> Bool {
        guard nomination.state == .draft else { return false }
        let queued = queued(nomination.id)
        if nomination.isInAppStoreConnect { return isEdited(nomination) && queued[.update] == nil }
        return queued[.create] == nil
    }

    // MARK: - Adding

    /// Add to Review & Push: the draft's Create row (on this Mac) or Update
    /// row (in App Store Connect). Refused with the problems when it isn't
    /// ready.
    @discardableResult
    func addToReviewPush(_ id: String, source: ChangeSource = .you, layers: SuggestionLayers? = nil) -> Bool {
        guard let nomination = nomination(id), nomination.state == .draft, problems(nomination).isEmpty else { return false }
        let before = queue.changes(for: app.id, section: .nominations)
        guard let change = try? saveChange(nomination, source: source) else { return false }
        queue.upsert(change)
        if let layers { queue.attach(layers, to: change.id) }
        store.noteQueued(id, at: now(), for: app.id)
        store.setRefusal(nil, nominationID: id, for: app.id)
        showsRefusalDetails = false
        show(String(localized: "In Review & Push. Nothing is sent until you push.", comment: "kind:toast")) { [weak self] in
            self?.restore(before)
        }
        return true
    }

    /// Submit…'s confirmation: the draft's save row if it needs one, then
    /// its Submit row. Only the person confirms this; an assistant's
    /// request to submit opens the same sheet.
    func confirmSubmit(_ id: String) {
        sheet = nil
        guard let nomination = nomination(id), nomination.state == .draft, problems(nomination).isEmpty else { return }
        let before = queue.changes(for: app.id, section: .nominations)
        var changes: [PendingChange] = []
        let queued = queued(id)
        let needsSave = !nomination.isInAppStoreConnect || (isEdited(nomination) && queued[.update] == nil)
        if needsSave, let save = try? saveChange(nomination, source: queued[.create]?.source ?? .you) { changes.append(save) }
        guard let submit = try? builder.submit(nomination, now: now()) else { return }
        changes.append(submit)
        queue.upsert(contentsOf: changes)
        store.noteQueued(id, at: now(), for: app.id)
        store.setRefusal(nil, nominationID: id, for: app.id)
        removeRequests(id, action: .submit)
        show(String(localized: "Submit is in Review & Push. Nothing is sent until you push.", comment: "kind:toast")) { [weak self] in
            self?.restore(before)
        }
    }

    /// Archive…'s confirmation: the Archive row.
    func confirmArchive(_ id: String) {
        sheet = nil
        guard let nomination = nomination(id), nomination.state == .submitted, !keyCannotWrite,
              let change = try? builder.archive(nomination, now: now())
        else { return }
        let before = queue.changes(for: app.id, section: .nominations)
        queue.upsert(change)
        removeRequests(id, action: .archive)
        show(String(localized: "Archive is in Review & Push. Nothing is sent until you push.", comment: "kind:toast")) { [weak self] in
            self?.restore(before)
        }
    }

    // MARK: - Taking out

    /// Remove, Cancel Submit, Cancel Archive: the rows go, with what
    /// depends on them (a Submit goes with its draft's Create).
    func removeFromReviewPush(_ id: String, kinds: [NominationChangeBuilder.Kind]? = nil) {
        let before = queue.changes(for: app.id, section: .nominations)
        let rows = queued(id).filter { kinds?.contains($0.key) ?? true }
        guard !rows.isEmpty else { return }
        queue.discard(ids: rows.values.map(\.id))
        let text = kinds == [.submit]
            ? String(localized: "Submit removed from Review & Push.", comment: "kind:toast")
            : kinds == [.archive]
            ? String(localized: "Archive removed from Review & Push.", comment: "kind:toast")
            : String(localized: "Removed from Review & Push.", comment: "kind:toast")
        show(text) { [weak self] in self?.restore(before) }
    }

    /// Delete Draft: a draft on this Mac goes now (Undo brings it back);
    /// one in App Store Connect gets a Delete row instead of its others.
    func deleteDraft(_ id: String) {
        guard let nomination = nomination(id), nomination.state == .draft else { return }
        let before = queue.changes(for: app.id, section: .nominations)
        let archive = store.archive(for: app.id)
        queue.discard(ids: queued(id).values.map(\.id))
        if nomination.isInAppStoreConnect {
            queue.upsert(builder.delete(nomination, now: now()))
            store.setEdit(nil, nominationID: id, for: app.id)
            show(String(localized: "Delete is in Review & Push. Nothing is sent until you push.", comment: "kind:toast")) { [weak self] in
                guard let self else { return }
                restore(before)
                store.setEdit(archive.edits[id], nominationID: id, for: app.id)
            }
        } else {
            store.removeDraft(id, for: app.id)
            show(String(localized: "Deleted the draft.", comment: "kind:toast")) { [weak self] in
                guard let self else { return }
                store.load(archive, for: app.id)
                queue.upsert(contentsOf: before)
            }
        }
        selection = nil
    }

    // MARK: - Helpers

    /// The draft's Create or Update row as it stands now.
    func saveChange(_ nomination: Nomination, source: ChangeSource) throws -> PendingChange {
        if nomination.isInAppStoreConnect {
            return try builder.update(nomination, from: remote(nomination.id)?.content ?? NominationContent(), source: source, now: now())
        }
        return try builder.create(nomination, source: source, now: now())
    }

    /// After an edit, a queued Create or Update carries the new content; it
    /// goes (with its Submit) when the draft isn't ready any more.
    func followQueued(_ nomination: Nomination) {
        let queued = queued(nomination.id)
        guard let row = queued[.create] ?? queued[.update] else { return }
        guard problems(nomination).isEmpty, let change = try? saveChange(nomination, source: row.source) else {
            queue.discard(ids: queued.values.map(\.id))
            return
        }
        if nomination.isInAppStoreConnect, !isEdited(nomination) {
            queue.discard(id: row.id)
            return
        }
        queue.upsert(change)
        if let layers = row.layers { queue.attach(layers, to: change.id) }
    }

    /// Undo: the section's rows as they were.
    func restore(_ changes: [PendingChange]) {
        let now = queue.changes(for: app.id, section: .nominations)
        queue.discard(ids: now.map(\.id).filter { changeID in !changes.contains { $0.id == changeID } })
        queue.upsert(contentsOf: changes)
    }

    func removeRequests(_ id: String, action: NominationActionRequest.Action) {
        for request in store.actionRequests(for: app.id, nominationID: id) where request.action == action {
            store.removeActionRequest(request.id, for: app.id)
        }
    }
}
