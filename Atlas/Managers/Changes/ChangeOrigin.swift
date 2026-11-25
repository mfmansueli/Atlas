//
//  ChangeOrigin.swift
//  Atlas
//

import Foundation

/// Why an assistant sent a proposal, when Atlas started the run for a
/// reason of its own: a Look for Improvements run's proposals carry its
/// id, so what the person makes of them can be measured. Proposals from
/// every other run, or from the person's own assistant, have none.
enum ChangeOrigin: Hashable, Codable, Sendable {
    /// A Look for Improvements run (`WatchCenter`).
    case watch(runID: UUID)

    var watchRunID: UUID? {
        switch self {
        case let .watch(runID): runID
        }
    }
}
