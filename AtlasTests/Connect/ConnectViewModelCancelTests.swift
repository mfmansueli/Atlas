//
//  ConnectViewModelCancelTests.swift
//  AtlasTests
//

import CryptoKit
import Foundation
import Testing
@testable import Atlas

/// "Add Another Key…"'s check step (`addkey-check`): Connect starts a
/// check Cancel can stop, which leaves the form as it was, with no error
/// and nothing saved.
@MainActor
@Suite("ConnectViewModel cancel")
struct ConnectViewModelCancelTests {
    /// A check App Store Connect never answers.
    private struct SilentChecker: KeyChecker {
        func check(_: AppStoreConnectCredentials) async throws -> KeyAccessCheck {
            try await Task.sleep(for: .seconds(3600))
            throw CancellationError()
        }
    }

    /// What `onConnect` was handed.
    private final class Saved {
        var count = 0
    }

    private static let key = ImportedPrivateKey(fileName: "AuthKey_2X9R4HXF34.p8", pem: P256.Signing.PrivateKey().pemRepresentation)

    private func filled(_ checker: any KeyChecker, saved: Saved) -> ConnectViewModel {
        let model = ConnectViewModel(checker: checker) { _, _ in saved.count += 1 }
        model.issuerID = TestKeys.issuerID
        model.importKey(Self.key)
        return model
    }

    /// Waits, at most about two seconds, for `condition`.
    private func wait(until condition: () -> Bool) async {
        for _ in 0..<200 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func connectChecksTheKeyAndSavesIt() async {
        let saved = Saved()
        let checker = FakeKeyChecker()
        let model = filled(checker, saved: saved)
        model.startConnect()
        await wait { saved.count == 1 && !model.isVerifying }
        #expect(saved.count == 1)
        #expect(checker.checked.count == 1)
        #expect(model.failure == nil)
    }

    @Test func cancelStopsTheCheckWithNoErrorAndNothingSaved() async {
        let saved = Saved()
        let model = filled(SilentChecker(), saved: saved)
        model.startConnect()
        await wait { model.isVerifying }
        #expect(model.isVerifying)
        #expect(!model.canConnect, "No second check while one runs")

        model.cancelConnect()
        await wait { !model.isVerifying }
        #expect(!model.isVerifying)
        #expect(model.failure == nil)
        #expect(saved.count == 0)
        #expect(model.privateKey == Self.key, "The form stays filled in")
        #expect(model.canConnect)
    }

    @Test func theCheckingStepNamesTheTeamThatStays() {
        #expect(AddKeyCopy.checkingTitle == "Checking the new key…")
        #expect(AddKeyCopy.checkingMessage(keeping: "Northpier Studio").hasSuffix("Northpier Studio stays as it is."))
    }
}
