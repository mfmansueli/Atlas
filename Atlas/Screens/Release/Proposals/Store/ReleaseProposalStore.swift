//
//  ReleaseProposalStore.swift
//  Atlas
//

import Foundation
import Observation

/// The release actions assistants proposed over MCP, waiting on the
/// version card for the person, and what became of the recent ones (for
/// `get_release`). JSON beside `ReleaseStore`'s in Application Support when
/// given a directory; in memory otherwise (tests, DEBUG scenes).
@MainActor
@Observable
final class ReleaseProposalStore {
    static let shared = ReleaseProposalStore(directory: sharedDirectory)

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return ReleaseStore.defaultDirectory
    }

    /// Oldest first.
    private(set) var proposals: [ReleaseProposal] = []
    @ObservationIgnored private let directory: URL?
    @ObservationIgnored var now: () -> Date = { .now }

    /// How many settled proposals each app keeps.
    static let keptPerApp = 20

    init(directory: URL? = nil) {
        self.directory = directory
        guard let directory, let data = try? Data(contentsOf: Self.file(in: directory)) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        proposals = (try? decoder.decode([ReleaseProposal].self, from: data)) ?? []
    }

    // MARK: - Reading

    /// The app's proposals, oldest first.
    func proposals(for appID: StoreApp.ID) -> [ReleaseProposal] {
        proposals.filter { $0.appID == appID }
    }

    /// The ones still waiting for the person.
    func pending(for appID: StoreApp.ID) -> [ReleaseProposal] {
        proposals(for: appID).filter(\.isPending)
    }

    func proposal(id: ReleaseProposal.ID) -> ReleaseProposal? {
        proposals.first { $0.id == id }
    }

    // MARK: - Writing

    /// Keeps `proposal`, replacing what the same assistant still had
    /// waiting for the app on that platform (one at a time). Returns the
    /// ids it replaced.
    @discardableResult
    func add(_ proposal: ReleaseProposal) -> [ReleaseProposal.ID] {
        var replaced: [ReleaseProposal.ID] = []
        for index in proposals.indices {
            let old = proposals[index]
            guard old.isPending, old.appID == proposal.appID, old.platform == proposal.platform, old.client == proposal.client else { continue }
            proposals[index].status = .replaced
            proposals[index].resolvedAt = now()
            replaced.append(old.id)
        }
        proposals.append(proposal)
        trim(proposal.appID)
        save()
        return replaced
    }

    /// Settles a waiting proposal: dismissed by the person, or withdrawn
    /// by its assistant. Returns whether it was waiting.
    @discardableResult
    func resolve(_ id: ReleaseProposal.ID, as status: ReleaseProposal.Status) -> Bool {
        guard let index = proposals.firstIndex(where: { $0.id == id }), proposals[index].isPending else { return false }
        proposals[index].status = status
        proposals[index].resolvedAt = now()
        trim(proposals[index].appID)
        save()
        return true
    }

    /// The person did `action` on the version: the proposals asking for it
    /// are confirmed.
    func settle(_ action: ReleaseProposal.Action, appID: StoreApp.ID, versionID: String) {
        let ids = proposals.filter { $0.isPending && $0.appID == appID && $0.versionID == versionID && $0.action == action }.map(\.id)
        for id in ids {
            resolve(id, as: .confirmed)
        }
    }

    /// Drops the oldest settled ones past `keptPerApp`.
    private func trim(_ appID: StoreApp.ID) {
        let settled = proposals.filter { $0.appID == appID && !$0.isPending }
        guard settled.count > Self.keptPerApp else { return }
        let dropped = Set(settled.prefix(settled.count - Self.keptPerApp).map(\.id))
        proposals.removeAll { dropped.contains($0.id) }
    }

    // MARK: - File

    private func save() {
        guard let directory else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? encoder.encode(proposals).write(to: Self.file(in: directory), options: .atomic)
    }

    private static func file(in directory: URL) -> URL {
        directory.appending(path: "release-proposals.json")
    }
}
