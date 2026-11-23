//
//  EncryptionKeyStoreTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Each app's last `report_encryption_key`, kept as JSON and read back by
/// a new launch; a new report replaces it.
@MainActor
@Suite("Encryption key store")
struct EncryptionKeyStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "EncryptionKeyStore-\(UUID().uuidString)")

    private func report(_ status: EncryptionKeyReport.Status, appID: String = "1") -> EncryptionKeyReport {
        EncryptionKeyReport(
            appID: appID, status: status, value: status == .couldNotAdd ? nil : .no,
            places: [.init(file: "Lumen/Info.plist", line: 42, target: "Lumen")],
            client: "Claude Code", date: Date(timeIntervalSince1970: 1_795_000_000)
        )
    }

    @Test func aReportIsKeptPerAppAndReadByTheNextLaunch() {
        let store = EncryptionKeyStore(directory: directory)
        store.setReport(report(.added))
        #expect(store.report(for: "1")?.status == .added)
        #expect(store.report(for: "2") == nil)

        let next = EncryptionKeyStore(directory: directory)
        #expect(next.report(for: "1") == report(.added))
        #expect(next.report(for: "1")?.places.first?.text == "Lumen/Info.plist:42 — Lumen")
    }

    @Test func aNewReportReplacesTheLastAndRemovingForgetsIt() {
        let store = EncryptionKeyStore(directory: directory)
        store.setReport(report(.couldNotAdd))
        store.setReport(report(.alreadyThere))
        #expect(EncryptionKeyStore(directory: directory).report(for: "1")?.status == .alreadyThere)
        store.removeReport(for: "1")
        #expect(store.report(for: "1") == nil)
        #expect(EncryptionKeyStore(directory: directory).report(for: "1") == nil)
    }

    @Test func withoutADirectoryItStaysInMemory() {
        let store = EncryptionKeyStore()
        store.setReport(report(.added, appID: "9"))
        #expect(store.report(for: "9")?.isDone == true)
        #expect(!report(.couldNotAdd).isDone)
    }
}
