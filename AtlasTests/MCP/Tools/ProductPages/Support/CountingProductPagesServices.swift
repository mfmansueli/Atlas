//
//  CountingProductPagesServices.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Product Pages' services that answer with one snapshot and count the
/// reads, to tell a kept read from one of App Store Connect.
@MainActor
final class CountingProductPagesServices: ProductPagesServices {
    var snapshot: ProductPagesSnapshot
    private(set) var reads = 0
    private(set) var cancelled: [String] = []

    init(_ snapshot: ProductPagesSnapshot) {
        self.snapshot = snapshot
    }

    func pages(for _: StoreApp) async throws -> ProductPagesSnapshot {
        reads += 1
        return snapshot
    }

    func submit(versionID _: String, of _: StoreApp) async throws {}

    var canCancelSubmission: Bool { true }

    func cancelSubmission(versionID: String, of _: StoreApp) async throws {
        cancelled.append(versionID)
    }
}
