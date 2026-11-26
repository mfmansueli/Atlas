//
//  RefreshProblemTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What a part's error means for Refresh: no network is "Offline"; Apple
/// not answering or refusing is "Couldn’t update", in Atlas's words with
/// Apple's text kept for Show Details; a cancelled read is no problem.
@Suite("Refresh · problems")
struct RefreshProblemTests {
    @Test func noNetworkIsOffline() {
        #expect(RefreshProblem.make(for: URLError(.notConnectedToInternet)) == .offline)
        #expect(RefreshProblem.make(for: URLError(.networkConnectionLost)) == .offline)
    }

    @Test func aTimeoutIsAppleNotAnsweringInTime() throws {
        let problem = try #require(RefreshProblem.make(for: URLError(.timedOut)))
        guard case let .failed(copy) = problem else { return Issue.record("a timeout isn't offline") }
        #expect(copy.summary == "App Store Connect didn’t answer in time.")
        #expect(copy.details?.contains("-1001") == true, "the code only in the details")
    }

    @Test func appleSErrorsAreInAtlassWords() throws {
        let problem = try #require(RefreshProblem.make(for: AppStoreConnectError.server(statusCode: 503, detail: nil)))
        guard case let .failed(copy) = problem else { return Issue.record("a 503 isn't offline") }
        #expect(copy.summary == "Apple didn’t answer. Try again in a minute.")
        #expect(copy.details?.contains("503") == true)
        #expect(!copy.summary.contains("503"), "Apple's code never in the message")
    }

    @Test func aCancelledReadIsNoProblem() {
        #expect(RefreshProblem.make(for: CancellationError()) == nil)
        #expect(RefreshProblem.make(for: URLError(.cancelled)) == nil)
    }

    @Test func aSectionsErrorIsReadBack() {
        let text = AppleErrorCopy(summary: "Prices didn’t load. Try again in a minute.", details: "HTTP 503").text
        #expect(RefreshProblem.copy(fromText: text) == AppleErrorCopy(summary: "Prices didn’t load. Try again in a minute.", details: "HTTP 503"))
        #expect(RefreshProblem.copy(fromText: "Apps didn’t load.") == AppleErrorCopy(summary: "Apps didn’t load.", details: nil))
    }

    @Test func offlineSaysMoreThanTheErrorsItCauses() {
        let failed = RefreshProblem.failed(AppleErrorCopy(summary: "Try again.", details: nil))
        #expect(failed.merged(with: .offline) == .offline)
        #expect(RefreshProblem.offline.merged(with: failed) == .offline)
        #expect(failed.merged(with: nil) == failed)
    }
}
