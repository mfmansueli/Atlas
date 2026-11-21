//
//  ChangeQueue.swift
//  Atlas
//

import Foundation
import Observation

/// Every pending change across all apps, in the order they were made. The
/// sections add to it (Pricing, Store Page, App Information, assistants);
/// the toolbar shows its count and Review & Push sends and removes them.
/// Shared through the SwiftUI environment.
@MainActor
@Observable
final class ChangeQueue {
    private(set) var changes: [PendingChange] = []
    /// Set when the saved queue couldn't be read or written.
    private(set) var persistenceError: String?

    private let persistence: (any ChangeQueuePersistence)?

    init(persistence: (any ChangeQueuePersistence)? = nil, changes: [PendingChange] = []) {
        self.persistence = persistence
        self.changes = changes
        if let persistence, changes.isEmpty {
            do {
                self.changes = try persistence.load()
            } catch {
                persistenceError = error.localizedDescription
            }
        }
    }

    // MARK: - Reading

    var totalCount: Int { changes.count }

    func change(id: PendingChange.ID) -> PendingChange? {
        changes.first { $0.id == id }
    }

    func changes(for appID: StoreApp.ID) -> [PendingChange] {
        changes.filter { $0.appID == appID }
    }

    func changes(for appID: StoreApp.ID, section: AppWorkspaceSection) -> [PendingChange] {
        changes.filter { $0.appID == appID && $0.section == section }
    }

    func count(for appID: StoreApp.ID) -> Int {
        changes.count { $0.appID == appID }
    }

    func hasChanges(for appID: StoreApp.ID) -> Bool {
        changes.contains { $0.appID == appID }
    }

    // MARK: - Changing

    /// Adds a change, or replaces the one with the same id in place. When the
    /// person and an assistant both edit the same field to different values,
    /// both versions are kept and the review sheet asks which to push.
    func upsert(_ change: PendingChange) {
        upsert(contentsOf: [change])
    }

    func upsert(contentsOf newChanges: [PendingChange]) {
        guard !newChanges.isEmpty else { return }
        var orphaned: Set<PendingChange.ID> = []
        for change in newChanges {
            if let index = changes.firstIndex(where: { $0.id == change.id }) {
                // Another version for the same platform: what was written
                // for the old number goes with it.
                if changes[index].requests != change.requests { orphaned.formUnion(dependents(of: [change.id])) }
                changes[index] = Self.merge(changes[index], with: change)
            } else {
                changes.append(change)
            }
        }
        orphaned.subtract(newChanges.map(\.id))
        changes.removeAll { orphaned.contains($0.id) }
        save()
    }

    /// The change to keep when `new` arrives for the same target as
    /// `existing`: the person's version stays primary and an assistant's
    /// different version becomes the alternative.
    private static func merge(_ existing: PendingChange, with new: PendingChange) -> PendingChange {
        let existingIsAssistant = existing.source.isAssistant
        let newIsAssistant = new.source.isAssistant
        guard existingIsAssistant != newIsAssistant, existing.newValue != new.newValue else {
            var replaced = new
            if replaced.alternative == nil, let alternative = existing.alternative, alternative.source.isAssistant != newIsAssistant {
                replaced.alternative = alternative
            }
            return replaced
        }
        var person = newIsAssistant ? existing : new
        let assistant = newIsAssistant ? new : existing
        person.alternative = ChangeAlternative(
            newValue: assistant.newValue,
            source: assistant.source,
            requests: assistant.requests,
            restoreRequests: assistant.restoreRequests,
            note: assistant.groupNote,
            blockedReason: assistant.blockedReason
        )
        return person
    }

    func discard(id: PendingChange.ID) {
        discard(ids: [id])
    }

    /// Removes the changes, and every change that depends on them: a new
    /// version's texts go with it.
    func discard(ids: some Sequence<PendingChange.ID>) {
        let ids = Set(ids)
        guard changes.contains(where: { ids.contains($0.id) }) else { return }
        let gone = ids.union(dependents(of: ids))
        changes.removeAll { gone.contains($0.id) }
        save()
    }

    /// Removes a change App Store Connect took. What depends on it stays:
    /// a new version's texts that failed go out again on the next push.
    func remove(pushed id: PendingChange.ID) {
        guard changes.contains(where: { $0.id == id }) else { return }
        changes.removeAll { $0.id == id }
        save()
    }

    /// Discards every change matching `predicate`, e.g. all of one app's, or
    /// "Reject All" from one assistant, with what depends on them.
    func discardAll(where predicate: (PendingChange) -> Bool) {
        discard(ids: changes.filter(predicate).map(\.id))
    }

    /// The changes that depend on `ids`, directly or through another one.
    func dependents(of ids: some Sequence<PendingChange.ID>) -> Set<PendingChange.ID> {
        var found: Set<PendingChange.ID> = []
        var next = Set(ids)
        while !next.isEmpty {
            let more = changes.filter { change in
                change.dependsOn.map(next.contains) == true && !found.contains(change.id)
            }.map(\.id)
            found.formUnion(more)
            next = Set(more)
        }
        return found
    }

    /// Every proposal from one assistant ("Reject All from Claude Code"):
    /// its changes go, and its versions of fields the person also edited.
    func rejectAll(fromAssistant client: String) {
        let source = ChangeSource.assistant(client: client)
        let rejected = changes.filter { $0.source == source }.map(\.id)
        let gone = Set(rejected).union(dependents(of: rejected))
        changes.removeAll { gone.contains($0.id) }
        for index in changes.indices where changes[index].alternative?.source == source {
            changes[index].alternative = nil
        }
        save()
    }

    /// The person looked at an assistant's proposal and keeps it: it can
    /// be pushed now.
    func accept(id: PendingChange.ID) {
        accept(ids: [id])
    }

    func accept(ids: some Sequence<PendingChange.ID>) {
        let ids = Set(ids)
        guard changes.contains(where: { ids.contains($0.id) && $0.awaitingAcceptance != nil }) else { return }
        for index in changes.indices where ids.contains(changes[index].id) {
            changes[index].awaitingAcceptance = nil
        }
        save()
    }

    // MARK: - Conflicts

    /// Records that App Store Connect has a different value now; the change
    /// is skipped until it's resolved.
    func markRemoteConflict(id: PendingChange.ID, _ conflict: RemoteConflict) {
        update(id) { $0.remoteConflict = conflict }
    }

    /// "Keep mine": push this value anyway, over App Store Connect's.
    func keepMine(id: PendingChange.ID) {
        update(id) { change in
            guard let conflict = change.remoteConflict else { return }
            change.conflictCheck?.expected = conflict.remoteRawValue
            change.oldValue = conflict.remoteDisplayValue
            change.remoteConflict = nil
        }
    }

    /// "Use App Store Connect's": the change is dropped.
    func useRemote(id: PendingChange.ID) {
        discard(id: id)
    }

    /// Picks the person's version or the assistant's of a field both
    /// edited. The assistant's takes its reason and its block along.
    func resolveAlternative(id: PendingChange.ID, keepAlternative: Bool) {
        update(id) { change in
            guard let alternative = change.alternative else { return }
            if keepAlternative {
                change.newValue = alternative.newValue
                change.source = alternative.source
                change.requests = alternative.requests
                change.restoreRequests = alternative.restoreRequests
                change.blockedReason = alternative.blockedReason
                if let note = alternative.note { change.groupNote = note }
            }
            change.alternative = nil
        }
    }

    /// An assistant's version of a change the person queued, kept beside
    /// it as the alternative (replacing an older one); the person's stays
    /// what's pushed until they pick. Nil `alternative` takes it back.
    func setAlternative(_ alternative: ChangeAlternative?, id: PendingChange.ID) {
        update(id) { $0.alternative = alternative }
    }

    // MARK: - Options

    /// Flips a change's option (e.g. "Publish to the App Store") in review.
    /// An option that can't be turned on stays off.
    func setOption(id: PendingChange.ID, isOn: Bool) {
        update(id) { change in
            guard var option = change.option, option.isEnabled || !isOn else { return }
            option.isOn = isOn
            change.option = option
        }
    }

    private func update(_ id: PendingChange.ID, _ body: (inout PendingChange) -> Void) {
        guard let index = changes.firstIndex(where: { $0.id == id }) else { return }
        body(&changes[index])
        save()
    }

    private func save() {
        guard let persistence else { return }
        do {
            try persistence.save(changes)
            persistenceError = nil
        } catch {
            persistenceError = error.localizedDescription
        }
    }
}
