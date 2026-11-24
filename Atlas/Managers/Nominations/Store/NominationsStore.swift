//
//  NominationsStore.swift
//  Atlas
//

import Foundation
import Observation

/// What this Mac keeps of each app's nominations (`NominationsArchive`):
/// drafts not in App Store Connect yet, unpushed edits, assistants'
/// suggestions and Apple's last refusal. JSON in Application Support when
/// given a directory; in memory otherwise (tests, DEBUG scenes).
/// Nominations, the sidebar's count and the MCP tools read it.
@MainActor
@Observable
final class NominationsStore {
    static let shared = NominationsStore(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/Nominations")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    private var archives: [StoreApp.ID: NominationsArchive] = [:]
    @ObservationIgnored private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory
    }

    // MARK: - Reading

    func archive(for appID: StoreApp.ID) -> NominationsArchive {
        if let archive = archives[appID] { return archive }
        let archive = directory.flatMap { Self.read(at: Self.file(appID, in: $0)) } ?? NominationsArchive()
        archives[appID] = archive
        return archive
    }

    func drafts(for appID: StoreApp.ID) -> [Nomination] {
        archive(for: appID).drafts
    }

    func edit(for appID: StoreApp.ID, nominationID: String) -> NominationContent? {
        archive(for: appID).edits[nominationID]
    }

    func proposals(for appID: StoreApp.ID) -> [NominationProposal] {
        archive(for: appID).proposals
    }

    func actionRequests(for appID: StoreApp.ID, nominationID: String? = nil) -> [NominationActionRequest] {
        archive(for: appID).actionRequests.filter { nominationID == nil || $0.nominationID == nominationID }
    }

    func refusal(for appID: StoreApp.ID, nominationID: String) -> NominationRefusal? {
        archive(for: appID).refusals[nominationID]
    }

    func isDismissed(_ key: String, for appID: StoreApp.ID) -> Bool {
        archive(for: appID).dismissedBuiltIns.contains(key)
    }

    /// The purple count on the section: what assistants suggested and the
    /// person hasn't decided yet.
    func count(for appID: StoreApp.ID) -> Int {
        let archive = archive(for: appID)
        return archive.proposals.count + archive.actionRequests.count
    }

    // MARK: - Drafts and edits

    /// Adds a draft on this Mac, or replaces the one with its ID.
    func save(_ draft: Nomination, for appID: StoreApp.ID) {
        update(appID) { archive in
            if let index = archive.drafts.firstIndex(where: { $0.id == draft.id }) {
                archive.drafts[index] = draft
            } else {
                archive.drafts.append(draft)
            }
        }
    }

    func removeDraft(_ id: String, for appID: StoreApp.ID) {
        update(appID) { archive in
            archive.drafts.removeAll { $0.id == id }
            archive.queuedAt[id] = nil
            archive.refusals[id] = nil
            archive.actionRequests.removeAll { $0.nominationID == id }
            archive.proposals.removeAll { $0.nominationID == id }
        }
    }

    /// The fields of a draft App Store Connect has, as edited here; nil
    /// forgets the edits.
    func setEdit(_ content: NominationContent?, nominationID: String, for appID: StoreApp.ID) {
        update(appID) { $0.edits[nominationID] = content }
    }

    func noteQueued(_ nominationID: String, at date: Date, for appID: StoreApp.ID) {
        update(appID) { $0.queuedAt[nominationID] = date }
    }

    // MARK: - Refusals and dismissals

    func setRefusal(_ refusal: NominationRefusal?, nominationID: String, for appID: StoreApp.ID) {
        update(appID) { $0.refusals[nominationID] = refusal }
    }

    func dismissBuiltIn(_ key: String, for appID: StoreApp.ID) {
        update(appID) { _ = $0.dismissedBuiltIns.insert(key) }
    }

    func restoreBuiltIn(_ key: String, for appID: StoreApp.ID) {
        update(appID) { _ = $0.dismissedBuiltIns.remove(key) }
    }

    // MARK: - Assistants

    /// An assistant's nomination; one from the same assistant for the same
    /// draft (or a new one with the same name) replaces it. Returns the
    /// IDs it replaced.
    @discardableResult
    func add(_ proposal: NominationProposal, for appID: StoreApp.ID) -> [String] {
        var replaced: [String] = []
        update(appID) { archive in
            let same = archive.proposals.filter { other in
                other.client == proposal.client && other.nominationID == proposal.nominationID
                    && (proposal.nominationID != nil || other.content.trimmedName.lowercased() == proposal.content.trimmedName.lowercased())
            }
            replaced = same.map(\.id)
            archive.proposals.removeAll { replaced.contains($0.id) }
            archive.proposals.append(proposal)
        }
        return replaced
    }

    @discardableResult
    func removeProposal(_ id: String, for appID: StoreApp.ID) -> NominationProposal? {
        var removed: NominationProposal?
        update(appID) { archive in
            removed = archive.proposals.first { $0.id == id }
            archive.proposals.removeAll { $0.id == id }
        }
        return removed
    }

    /// An assistant's request to submit or archive; the same one for the
    /// same nomination replaces it.
    @discardableResult
    func add(_ request: NominationActionRequest, for appID: StoreApp.ID) -> [String] {
        var replaced: [String] = []
        update(appID) { archive in
            replaced = archive.actionRequests.filter { $0.nominationID == request.nominationID && $0.action == request.action }.map(\.id)
            archive.actionRequests.removeAll { replaced.contains($0.id) }
            archive.actionRequests.append(request)
        }
        return replaced
    }

    @discardableResult
    func removeActionRequest(_ id: String, for appID: StoreApp.ID) -> NominationActionRequest? {
        var removed: NominationActionRequest?
        update(appID) { archive in
            removed = archive.actionRequests.first { $0.id == id }
            archive.actionRequests.removeAll { $0.id == id }
        }
        return removed
    }

    // MARK: - After a read

    /// What a read of App Store Connect found (`remote`), against the
    /// app's Nominations changes in Review & Push: a draft on this Mac whose
    /// Create row went and that App Store Connect now has (by name) gives
    /// way to it; edits whose Update row went, or of a nomination that's no
    /// longer a draft, are forgotten; assistants' requests about
    /// nominations that are gone or moved on go too.
    func reconcile(remote: [Nomination], changes: [PendingChange], for appID: StoreApp.ID) {
        let builder = NominationChangeBuilder(appID: appID)
        let remoteDrafts = remote.filter { $0.state == .draft }
        update(appID) { archive in
            archive.drafts.removeAll { draft in
                guard let queued = archive.queuedAt[draft.id], builder.queued(for: draft.id, in: changes)[.create] == nil else { return false }
                return remoteDrafts.contains { remote in
                    remote.content.trimmedName == draft.content.trimmedName && (remote.createdDate ?? .distantFuture) >= queued.addingTimeInterval(-60)
                }
            }
            for id in archive.edits.keys {
                let queued = builder.queued(for: id, in: changes)
                let isDraft = remoteDrafts.contains { $0.id == id }
                if !isDraft || (archive.queuedAt[id] != nil && queued[.update] == nil) { archive.edits[id] = nil }
            }
            let known = Set(remote.map(\.id) + archive.drafts.map(\.id))
            archive.queuedAt = archive.queuedAt.filter { known.contains($0.key) && !builder.queued(for: $0.key, in: changes).isEmpty }
            archive.actionRequests.removeAll { request in
                let state = remote.first { $0.id == request.nominationID }?.state ?? (archive.drafts.contains { $0.id == request.nominationID } ? .draft : nil)
                switch request.action {
                case .submit: return state != .draft
                case .archive: return state != .submitted
                }
            }
            archive.proposals.removeAll { proposal in
                guard let id = proposal.nominationID else { return false }
                return !remoteDrafts.contains { $0.id == id } && !archive.drafts.contains { $0.id == id }
            }
        }
    }

    /// An app's whole state at once: Delete Draft's Undo, DEBUG scenes and
    /// tests.
    func load(_ archive: NominationsArchive, for appID: StoreApp.ID) {
        update(appID) { $0 = archive }
    }

    // MARK: - Files

    private func update(_ appID: StoreApp.ID, _ change: (inout NominationsArchive) -> Void) {
        var archive = archive(for: appID)
        change(&archive)
        guard archive != archives[appID] else { return }
        archives[appID] = archive
        guard let directory else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? encoder.encode(archive).write(to: Self.file(appID, in: directory), options: .atomic)
    }

    private static func file(_ appID: StoreApp.ID, in directory: URL) -> URL {
        directory.appending(path: "nominations-\(appID).json")
    }

    private static func read(at url: URL) -> NominationsArchive? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(NominationsArchive.self, from: data)
    }
}
