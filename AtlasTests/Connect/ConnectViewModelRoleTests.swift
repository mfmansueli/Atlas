//
//  ConnectViewModelRoleTests.swift
//  AtlasTests
//

import CryptoKit
import Foundation
import Testing
@testable import Atlas

/// A key whose role is too low: the error stays under the fields, the
/// file is cleared so Connect waits for another one, and a new file clears
/// the old verdict.
@MainActor
@Suite("ConnectViewModel · role too low")
struct ConnectViewModelRoleTests {
    private let checker = FakeKeyChecker()

    private func key() -> ImportedPrivateKey {
        ImportedPrivateKey(fileName: "AuthKey_2X9R4HXF34.p8", pem: P256.Signing.PrivateKey().pemRepresentation)
    }

    private func filledModel() -> ConnectViewModel {
        let vm = ConnectViewModel(checker: checker) { _, _ in }
        vm.issuerID = TestKeys.issuerID
        vm.importKey(key())
        return vm
    }

    @Test func roleTooLowClearsTheKeyFile() async {
        checker.error = AppStoreConnectError.forbidden(detail: nil)
        let vm = filledModel()
        await vm.connect()
        #expect(vm.failure == .roleTooLow)
        #expect(vm.privateKey == nil)
        #expect(!vm.canConnect)
        #expect(vm.keyID == "2X9R4HXF34", "The IDs stay; only the file was wrong")
    }

    @Test func otherFailuresKeepTheKeyFile() async {
        checker.error = AppStoreConnectError.unauthorized
        let vm = filledModel()
        await vm.connect()
        #expect(vm.failure == .rejected)
        #expect(vm.privateKey != nil)
        #expect(vm.canConnect)
    }

    @Test func anotherFileClearsTheOldFailure() async {
        checker.error = AppStoreConnectError.forbidden(detail: nil)
        let vm = filledModel()
        await vm.connect()
        vm.importKey(key())
        #expect(vm.failure == nil)
        #expect(vm.canConnect)
    }
}
