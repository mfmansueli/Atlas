//
//  EncryptionDeclarationChangeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Export Compliance's encryption declaration: which one a build that
/// isn't exempt gets, and the writes that create it and link the build.
@Suite("Encryption declaration")
struct EncryptionDeclarationChangeTests {
    private typealias Support = AppInformationTestSupport
    private let builder = AppInformationTestSupport.builder
    private let export = ExportComplianceValues(buildID: "build-42", buildNumber: "42", usesNonExemptEncryption: nil)

    private static let nonExempt = ExportComplianceAnswers(answers: [
        .usesEncryption: true, .isExempt: false, .proprietary: false, .thirdParty: true, .availableInFrance: true,
    ])

    private static func declaration(_ id: String, state: String?, thirdParty: Bool = true) -> ExportEncryptionDeclaration {
        ExportEncryptionDeclaration(
            id: id,
            state: state,
            codeValue: state == "APPROVED" ? "code-\(id)" : nil,
            answers: ExportComplianceAnswers(answers: [.proprietary: false, .thirdParty: thirdParty, .availableInFrance: true])
        )
    }

    // MARK: - Which declaration

    @Test func exemptEncryptionNeedsNoDeclaration() {
        let exempt = ExportComplianceAnswers(answers: [.usesEncryption: true, .isExempt: true])
        #expect(EncryptionDeclarationPlan.plan(for: exempt, appDescription: "HTTPS", declarations: []) == nil)
        #expect(EncryptionDeclarationPlan.plan(for: ExportComplianceAnswers(answers: [.usesEncryption: false]), appDescription: "x", declarations: []) == nil)
    }

    @Test func anApprovedDeclarationWithTheSameAnswersIsReused() {
        let inReview = Self.declaration("decl-2", state: "IN_REVIEW")
        let approved = Self.declaration("decl-1", state: "APPROVED")
        let other = Self.declaration("decl-0", state: "APPROVED", thirdParty: false)
        let plan = EncryptionDeclarationPlan.plan(for: Self.nonExempt, appDescription: nil, declarations: [inReview, other, approved])
        #expect(plan == .link(approved))

        let rejected = Self.declaration("decl-3", state: "REJECTED")
        #expect(EncryptionDeclarationPlan.plan(for: Self.nonExempt, appDescription: nil, declarations: [rejected, other]) == nil)
        #expect(EncryptionDeclarationPlan.plan(for: Self.nonExempt, appDescription: nil, declarations: [inReview]) == .link(inReview))
    }

    @Test func otherwiseANewOneNeedsADescription() {
        #expect(EncryptionDeclarationPlan.plan(for: Self.nonExempt, appDescription: "  ", declarations: []) == nil)
        let plan = EncryptionDeclarationPlan.plan(for: Self.nonExempt, appDescription: " Sync uses libsodium. ", declarations: [])
        #expect(plan == .create(appDescription: "Sync uses libsodium.", answers: Self.nonExempt))
    }

    @Test func theStateReads() {
        #expect(Self.declaration("d", state: "APPROVED").summary == "Approved · code code-d")
        #expect(Self.declaration("d", state: "IN_REVIEW").summary == "In review")
        #expect(!Self.declaration("d", state: "EXPIRED").isUsable)
        #expect(Self.declaration("d", state: nil).isUsable)
    }

    // MARK: - The change

    @Test func aNewDeclarationIsCreatedAndTheBuildLinkedToIt() throws {
        let plan = EncryptionDeclarationPlan.create(appDescription: "Sync uses libsodium.", answers: Self.nonExempt)
        let source = ChangeSource.assistant(client: "Claude Code")
        let change = try #require(builder.declarationChange(plan, export: export, source: source, dependsOn: builder.encryptionChangeID))
        #expect(change.id == "appInformation.\(Support.appID).exportCompliance.v14.declaration")
        #expect(change.section == .appInformation)
        #expect(change.group == "App Information · Export Compliance")
        #expect(change.title == "Encryption declaration · build 42")
        #expect(change.dependsOn == builder.encryptionChangeID)
        #expect(change.restoreRequests.isEmpty)

        let post = try #require(change.requests.first)
        #expect(post.method == .post)
        #expect(post.path == "/v1/appEncryptionDeclarations")
        let attributes = Support.attributes(post)
        #expect(attributes["appDescription"] as? String == "Sync uses libsodium.")
        #expect(attributes["containsProprietaryCryptography"] as? Bool == false)
        #expect(attributes["containsThirdPartyCryptography"] as? Bool == true)
        #expect(attributes["availableOnFrenchStore"] as? Bool == true)
        #expect(Support.relationshipID(post, "app") == Support.appID)

        let link = change.requests[1]
        #expect(link.method == .patch)
        #expect(link.path == "/v1/builds/build-42")
        #expect(Support.relationshipID(link, "appEncryptionDeclaration") == "{createdID:appEncryptionDeclarations}")
        #expect(try link.resolvingCreatedIDs(["appEncryptionDeclarations": "decl-7"]).bodyText?.contains("decl-7") == true)

        #expect(change.creation?.title == "Create an encryption declaration")
        #expect(change.creation?.fields.map(\.id) == ["appDescription", "proprietary", "thirdParty", "availableInFrance"])
        #expect(change.creation?.fields.map(\.newValue) == ["Sync uses libsodium.", "No", "Yes", "Yes"])
    }

    @Test func withoutABuildOnlyTheDeclarationIsCreated() throws {
        let plan = EncryptionDeclarationPlan.create(appDescription: "Sync uses libsodium.", answers: Self.nonExempt)
        let change = try #require(builder.declarationChange(plan, export: ExportComplianceValues()))
        #expect(change.requests.map(\.path) == ["/v1/appEncryptionDeclarations"])
        #expect(change.title == "Encryption declaration")
        #expect(change.creation?.detail.contains("ITSEncryptionExportComplianceCode") == true)
    }

    @Test func anExistingDeclarationIsOnlyLinked() throws {
        let approved = Self.declaration("decl-1", state: "APPROVED")
        let change = try #require(builder.declarationChange(.link(approved), export: export))
        #expect(change.requests.count == 1)
        #expect(change.requests.first?.path == "/v1/builds/build-42")
        #expect(Support.relationshipID(change.requests.first, "appEncryptionDeclaration") == "decl-1")
        #expect(change.newValue == "Existing declaration · Approved · code code-decl-1")
        #expect(change.creation == nil)

        #expect(builder.declarationChange(.link(approved), export: ExportComplianceValues()) == nil)
    }
}
