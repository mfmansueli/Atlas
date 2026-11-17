//
//  ComplianceAnswersTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The App Compliance answers kept on this Mac: they survive a relaunch,
/// and notes saved before they existed still load.
@MainActor
@Suite("ComplianceAnswers")
struct ComplianceAnswersTests {
    @Test func answersRoundTripThroughTheNotes() throws {
        var notes = AppInformationNotes()
        notes.compliance = ComplianceAnswers(
            trader: .trader,
            traderDetails: TraderDetails(name: "Northpier Studio Ltd", address: "14 Harbour Road", phone: "+353 1 555 0142", email: "support@northpier.dev"),
            addsICPNumber: true,
            icpNumber: "沪ICP备2026012345号-2A",
            declared: [.medicalDevice]
        )
        let decoded = try JSONDecoder().decode(AppInformationNotes.self, from: JSONEncoder().encode(notes))
        #expect(decoded.compliance == notes.compliance)
        #expect(decoded == notes)
    }

    @Test func notesSavedBeforeAppComplianceStillLoad() throws {
        let old = Data(#"{"overrideReason":"Grief themes","commonTasks":["writing an entry"]}"#.utf8)
        let notes = try JSONDecoder().decode(AppInformationNotes.self, from: old)
        #expect(notes.overrideReason == "Grief themes")
        #expect(notes.compliance == ComplianceAnswers())
    }

    @Test func answersSavedWithFewerFieldsStillLoad() throws {
        let partial = Data(#"{"trader":"nonTrader"}"#.utf8)
        let answers = try JSONDecoder().decode(ComplianceAnswers.self, from: partial)
        #expect(answers.trader == .nonTrader)
        #expect(answers.traderDetails == nil)
        #expect(!answers.addsICPNumber)
        #expect(answers.declared.isEmpty)
    }

    @Test func theDefaultsStoreKeepsThemPerApp() throws {
        let suite = "ComplianceAnswersTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var notes = AppInformationNotes()
        notes.compliance.trader = .nonTrader
        DefaultsAppInformationNotesStore(defaults: defaults).setNotes(notes, for: "1")

        let reopened = DefaultsAppInformationNotesStore(defaults: defaults)
        #expect(reopened.notes(for: "1").compliance.trader == .nonTrader)
        #expect(reopened.notes(for: "2").compliance.trader == nil)
    }

    @Test func traderDetailsReadAsOneLineAndAsLinesToPaste() {
        let details = TraderDetails(name: "Northpier Studio Ltd", address: " ", phone: "+353 1 555 0142", email: "support@northpier.dev")
        #expect(details.summary == "Northpier Studio Ltd · +353 1 555 0142 · support@northpier.dev")
        #expect(details.pasteboardText == "Name: Northpier Studio Ltd\nAddress: \nPhone: +353 1 555 0142\nEmail: support@northpier.dev")
        #expect(details[.email] == "support@northpier.dev")
    }
}
