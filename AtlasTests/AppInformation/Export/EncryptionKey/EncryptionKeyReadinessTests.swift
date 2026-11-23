//
//  EncryptionKeyReadinessTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// When Add It to the Project is on: only for a settled answer (the
/// person's, a confirmed assistant's, or the build's flag that nothing
/// contradicts), never for an assistant's unconfirmed suggestion, and YES
/// only with an approved declaration's code.
@Suite("Encryption key readiness")
struct EncryptionKeyReadinessTests {
    private static let exempt = ExportComplianceAnswers(answers: [.usesEncryption: true, .isExempt: true])
    private static let notExempt = ExportComplianceAnswers(answers: [
        .usesEncryption: true, .isExempt: false, .proprietary: false, .thirdParty: true, .availableInFrance: true,
    ])

    private static func declaration(state: String, code: String?, answers: ExportComplianceAnswers = notExempt) -> ExportEncryptionDeclaration {
        ExportEncryptionDeclaration(id: "decl-1", state: state, codeValue: code, createdDate: "2026-11-01T10:00:00Z", answers: answers)
    }

    private static func notes(_ answers: ExportComplianceAnswers?, evidence client: String? = nil) -> AppInformationNotes {
        var notes = AppInformationNotes()
        notes.exportAnswers = answers
        notes.exportEvidence = client.map { AssistantEvidence(client: $0, summary: "", why: "", evidence: []) }
        return notes
    }

    @Test func thePersonsExemptAnswerIsReadyAsNo() throws {
        let readiness = EncryptionKeyReadiness.make(notes: Self.notes(Self.exempt), export: ExportComplianceValues())
        let answer = try #require(readiness.answer)
        #expect(answer.value == .no)
        #expect(answer.basis == .confirmed)
        #expect(answer.snippet == "<key>ITSAppUsesNonExemptEncryption</key>\n<false/>")
        #expect(answer.buildSettings == ["INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO"])
    }

    @Test func anUnconfirmedAssistantSuggestionNeverIs() {
        let readiness = EncryptionKeyReadiness.make(
            notes: Self.notes(Self.exempt, evidence: "Claude Code"),
            export: ExportComplianceValues(buildID: "b", buildNumber: "42", usesNonExemptEncryption: false)
        )
        #expect(readiness.answer == nil)
        #expect(readiness.reason == .unconfirmedSuggestion(client: "Claude Code"))
        #expect(readiness.reason?.text.contains("Confirm or reject Claude Code’s answers first") == true)
    }

    @Test func nothingAnsweredOrHalfAnsweredIsBlocked() {
        #expect(EncryptionKeyReadiness.make(notes: AppInformationNotes(), export: ExportComplianceValues()).reason == .notAnswered)
        let half = ExportComplianceAnswers(answers: [.usesEncryption: true])
        #expect(EncryptionKeyReadiness.make(notes: Self.notes(half), export: ExportComplianceValues()).reason == .incomplete)
    }

    @Test func theBuildsFlagAloneIsReadyWhenNothingContradictsIt() throws {
        let export = ExportComplianceValues(buildID: "b", buildNumber: "42", usesNonExemptEncryption: false)
        let answer = try #require(EncryptionKeyReadiness.make(notes: AppInformationNotes(), export: export).answer)
        #expect(answer.value == .no)
        #expect(answer.basis == .build(number: "42"))
        #expect(answer.basisText == "build 42’s answer in App Store Connect")
    }

    @Test func aBuildFlagTheDeclarationContradictsIsBlocked() {
        var export = ExportComplianceValues(buildID: "b", buildNumber: "42", usesNonExemptEncryption: false)
        export.declaredAnswers = Self.notExempt
        let readiness = EncryptionKeyReadiness.make(notes: AppInformationNotes(), export: export)
        #expect(readiness.reason == .contradicts(buildNumber: "42"))
    }

    @Test func notExemptNeedsAnApprovedDeclarationsCode() throws {
        var export = ExportComplianceValues()
        export.declarations = [Self.declaration(state: "IN_REVIEW", code: nil)]
        #expect(EncryptionKeyReadiness.make(notes: Self.notes(Self.notExempt), export: export).reason == .needsApprovedDeclaration)

        export.declarations = [Self.declaration(state: "APPROVED", code: "a1b2c3", answers: Self.exempt)]
        #expect(EncryptionKeyReadiness.make(notes: Self.notes(Self.notExempt), export: export).reason == .needsApprovedDeclaration)

        export.declarations = [Self.declaration(state: "APPROVED", code: "a1b2c3")]
        let answer = try #require(EncryptionKeyReadiness.make(notes: Self.notes(Self.notExempt), export: export).answer)
        #expect(answer.value == .yes)
        #expect(answer.code == "a1b2c3")
        #expect(answer.declarationID == "decl-1")
        #expect(answer.snippet.contains("<true/>"))
        #expect(answer.snippet.contains("<key>ITSEncryptionExportComplianceCode</key>\n<string>a1b2c3</string>"))
        #expect(answer.buildSettings == [
            "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = YES", "INFOPLIST_KEY_ITSEncryptionExportComplianceCode = a1b2c3",
        ])
    }

    @Test func keyValuesReadTheWaysAnAssistantWritesThem() {
        #expect(EncryptionKeyValue(text: "no") == .no)
        #expect(EncryptionKeyValue(text: " YES ") == .yes)
        #expect(EncryptionKeyValue(text: "false") == .no)
        #expect(EncryptionKeyValue(text: "maybe") == nil)
    }
}
