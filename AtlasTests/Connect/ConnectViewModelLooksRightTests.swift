//
//  ConnectViewModelLooksRightTests.swift
//  AtlasTests
//

import CryptoKit
import Foundation
import Testing
@testable import Atlas

/// The green check beside each Connect field (README-Welcome): shown once
/// the value has the right form, while typing too.
@MainActor
@Suite("ConnectViewModel looks right")
struct ConnectViewModelLooksRightTests {
    private func model() -> ConnectViewModel {
        ConnectViewModel(checker: FakeKeyChecker()) { _, _ in }
    }

    @Test func anEmptyFormHasNoChecks() {
        let vm = model()
        #expect(!vm.issuerIDLooksRight)
        #expect(!vm.keyIDLooksRight)
        #expect(!vm.keyFileLooksRight)
    }

    @Test func theIssuerIDIsAUUID() {
        let vm = model()
        vm.issuerID = "69a6de7f-3c2e-47e3"
        #expect(!vm.issuerIDLooksRight)
        vm.issuerID = "69a6de70-3c1f-47e3-e053-5b8c7c11a4d1"
        #expect(vm.issuerIDLooksRight)
        vm.issuerID = "  69a6de70-3c1f-47e3-e053-5b8c7c11a4d1 "
        #expect(vm.issuerIDLooksRight, "Spaces from a paste don't count")
    }

    @Test func theKeyIDIsTenLettersAndDigits() {
        let vm = model()
        vm.keyID = "2X9R4H"
        #expect(!vm.keyIDLooksRight)
        vm.keyID = "2X9R4HXF3-"
        #expect(!vm.keyIDLooksRight)
        vm.keyID = "2X9R4HXF34"
        #expect(vm.keyIDLooksRight)
    }

    /// No wait for the field to be left, unlike the red hints.
    @Test func theCheckShowsWhileTyping() {
        let vm = model()
        vm.keyID = "2X9R4HXF34"
        #expect(vm.keyIDLooksRight)
        #expect(!vm.leftFields.contains(.keyID))
    }

    @Test func onlyAReadableP8KeyFileLooksRight() {
        let vm = model()
        vm.importKey(ImportedPrivateKey(fileName: "notes.txt", pem: "Remember to rotate the keys."))
        #expect(!vm.keyFileLooksRight)
        vm.importKey(ImportedPrivateKey(fileName: "AuthKey_2X9R4HXF34.p8", pem: P256.Signing.PrivateKey().pemRepresentation))
        #expect(vm.keyFileLooksRight)
        vm.removeKey()
        #expect(!vm.keyFileLooksRight)
    }
}
