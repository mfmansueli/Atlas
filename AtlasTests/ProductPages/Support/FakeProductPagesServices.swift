//
//  FakeProductPagesServices.swift
//  AtlasTests
//

import CoreGraphics
import Foundation
@testable import Atlas

/// Canned pages for the Custom Product Pages tests, recording what's sent
/// to App Review.
@MainActor
final class FakeProductPagesServices: ProductPagesServices {
    var snapshot = DebugProductPagesData.snapshot
    var readError: AppStoreConnectError?
    var submitError: AppStoreConnectError?
    var cancels = true
    var cancelError: (any Error)?
    private(set) var reads = 0
    private(set) var submitted: [String] = []
    private(set) var cancelled: [String] = []

    func pages(for _: StoreApp) async throws -> ProductPagesSnapshot {
        reads += 1
        if let readError { throw readError }
        return snapshot
    }

    func submit(versionID: String, of _: StoreApp) async throws {
        if let submitError { throw submitError }
        submitted.append(versionID)
    }

    var canCancelSubmission: Bool { cancels }

    func cancelSubmission(versionID: String, of _: StoreApp) async throws {
        if let cancelError { throw cancelError }
        cancelled.append(versionID)
    }

    func screenshotImage(_: LiveScreenshot, pixelWidth _: Int) async -> CGImage? { nil }

    /// Private diary as if its creation was pushed: in App Store Connect,
    /// its first version in `state`.
    func pushPrivateDiary(_ state: ProductPageState) {
        snapshot.pages.append(DebugProductPagesData.pushedPrivateDiary(state))
    }
}
