//
//  CannedURLProbe.swift
//  AtlasTests
//

import Foundation
import Synchronization
@testable import Atlas

/// Answers each URL with a canned status (else `.opens`) and records
/// what was opened.
final class CannedURLProbe: ReviewRiskURLProbing {
    private let statuses: [String: ReviewRiskURLStatus]
    private let opened = Mutex<[String]>([])

    init(_ statuses: [String: ReviewRiskURLStatus] = [:]) {
        self.statuses = statuses
    }

    var openedURLs: [String] { opened.withLock { $0 } }

    func probe(_ url: URL) async -> ReviewRiskURLStatus {
        opened.withLock { $0.append(url.absoluteString) }
        return statuses[url.absoluteString] ?? .opens
    }
}
