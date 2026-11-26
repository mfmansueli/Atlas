//
//  RefreshRun.swift
//  Atlas
//

import Foundation

/// One Refresh while it runs: the parts it still waits for and the problem
/// any part had. The window starts one (`WorkspaceNavigator.refresh()`),
/// each part reports when its read ends, and once the last is in the run
/// gives the window's new `RefreshState`.
///
/// A part that failed ends the run as soon as the parts the window reads
/// itself (the app list and the version) are in: the open section shows
/// its own error, so the arrow doesn't turn on while it gives up.
struct RefreshRun: Hashable, Sendable {
    /// The parts whose read hasn't ended.
    private(set) var waiting: Set<RefreshPart>
    /// The parts whose read has ended, well or not.
    private(set) var finished: Set<RefreshPart> = []
    /// The first problem a part had (no network wins over the rest).
    private(set) var problem: RefreshProblem?
    /// When the window last read App Store Connect without a problem.
    let lastUpdated: Date?

    init(parts: Set<RefreshPart> = Set(RefreshPart.allCases), lastUpdated: Date?) {
        waiting = parts
        self.lastUpdated = lastUpdated
    }

    /// Every part is in, or a problem leaves nothing more worth waiting for.
    var isDone: Bool {
        waiting.isEmpty || (problem != nil && waiting.isSubset(of: [.section]))
    }

    /// `part` ended, with `problem` when it didn't read. False when the run
    /// wasn't waiting for it (it ended already), so nothing changed.
    @discardableResult
    mutating func finish(_ part: RefreshPart, problem: RefreshProblem? = nil) -> Bool {
        guard waiting.remove(part) != nil else { return false }
        finished.insert(part)
        if let problem { self.problem = problem.merged(with: self.problem) }
        return true
    }

    /// The window's state once the run is done: updated now, or what went
    /// wrong, keeping the time of the last good read. A key that can only
    /// read (`readOnlyRole`) shows "View only".
    func state(at now: Date, readOnlyRole: String? = nil) -> RefreshState {
        switch problem {
        case .offline:
            return .offline(since: lastUpdated ?? now)
        case let .failed(copy):
            return .failed(copy, lastUpdated: lastUpdated)
        case nil:
            if let readOnlyRole { return .readOnly(role: readOnlyRole, lastUpdated: now) }
            return .updated(now)
        }
    }

    // MARK: - The key's role

    /// App Store Connect's roles that can't change an app's information,
    /// as Settings → Accounts names them. The API doesn't tell a key its
    /// role, so today a key is "Team key" until the person names its role,
    /// and no key shows View only yet.
    static let readOnlyRoles: Set<String> = ["Developer", "Finance", "Sales", "Customer Support", "Access to Reports", "Sales and Reports"]

    /// `role` when it can only read, for "View only"; nil for a role that
    /// can push, or one Atlas doesn't know.
    static func readOnlyRole(_ role: String?) -> String? {
        guard let role, readOnlyRoles.contains(role) else { return nil }
        return role
    }
}
