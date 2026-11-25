//
//  WatchSignalTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

@Suite("Look for Improvements · findings")
struct WatchSignalTests {
    private typealias Data = WatchTestData

    @Test func identityIsKindAppAndSubject() {
        let signal = Data.signal(.crashesWorse, subject: "1.4", value: 3.2)
        #expect(signal.identity == "crashesWorse.6450000001.1.4")
    }

    @Test func fingerprintRoundsToTwoSignificantDigitsInNameOrder() {
        let signal = Data.signal(.reviewsAfterRelease, subject: "1.4", value: 8, numbers: ["low": 1234, "average": 3.24])
        #expect(signal.fingerprint == "reviewsAfterRelease.6450000001.1.4|average=3.2|low=1200")
        #expect(signal.id == signal.fingerprint)
    }

    @Test func smallMovesKeepTheFingerprint() {
        let first = Data.signal(.crashesWorse, subject: "1.4", value: 3.21, numbers: ["times": 3.21])
        let second = Data.signal(.crashesWorse, subject: "1.4", value: 3.24, numbers: ["times": 3.24])
        let third = Data.signal(.crashesWorse, subject: "1.4", value: 3.5, numbers: ["times": 3.5])
        #expect(first.fingerprint == second.fingerprint)
        #expect(first.fingerprint != third.fingerprint)
        #expect(first.identity == third.identity)
    }

    @Test func roundingIsTheSameWithAnyNumber() {
        #expect(WatchSignal.rounded(0) == "0")
        #expect(WatchSignal.rounded(.infinity) == "0")
        #expect(WatchSignal.rounded(7) == "7")
        #expect(WatchSignal.rounded(0.0456) == "0.046")
    }

    @Test func movingALotIsMoreThanAQuarter() {
        #expect(!Data.signal(value: 5).hasMovedALot(from: 4))
        #expect(Data.signal(value: 6).hasMovedALot(from: 4))
        #expect(Data.signal(value: 2).hasMovedALot(from: 4))
        #expect(Data.signal(value: 1).hasMovedALot(from: 0))
        #expect(!Data.signal(value: 0).hasMovedALot(from: 0))
    }

    @Test func localOnlyKindsAreTheOnesOnlyThePersonAnswers() {
        #expect(WatchSignalKind.allCases.filter(\.isLocalOnly) == [.submissionBlocked, .versionRejected])
    }

    @Test func archivesSurviveJSON() throws {
        var archive = WatchArchive()
        let signal = Data.signal(deadline: Data.now)
        archive.records[signal.identity] = WatchRecord(signal: signal, state: .sent(runID: UUID(), date: Data.now), firstSeen: Data.now, lastSeen: Data.now)
        archive.updateStats(for: .crashesWorse) { $0.intervalMultiplier = 4 }
        archive.append(WatchHistoryEntry(id: UUID(), appID: Data.lumen, appName: "Lumen", startedAt: Data.now, signals: [signal], result: .failed(reason: "x")))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        #expect(try decoder.decode(WatchArchive.self, from: encoder.encode(archive)) == archive)
    }

    @Test func theHistoryKeepsItsLimit() {
        var archive = WatchArchive()
        for index in 0..<WatchArchive.historyLimit + 5 {
            archive.append(WatchHistoryEntry(id: UUID(), appID: Data.lumen, appName: "\(index)", startedAt: Data.now, signals: []))
        }
        #expect(archive.history.count == WatchArchive.historyLimit)
        #expect(archive.history.first?.appName == "5")
    }
}
