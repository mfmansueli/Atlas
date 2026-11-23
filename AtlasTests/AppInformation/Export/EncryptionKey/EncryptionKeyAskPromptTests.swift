//
//  EncryptionKeyAskPromptTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Add It to the Project asks Claude Code: the shipping target by
/// bundle ID, the build setting in every configuration or the Info.plist,
/// YES with the approved code, other targets left alone, no commit unless
/// the project says so, never push or upload; and the run may edit only
/// with the commands that checks it.
@Suite("Encryption key prompt")
struct EncryptionKeyAskPromptTests {
    private let port: UInt16 = 47321

    private static func prompt(_ answer: EncryptionKeyAnswer) -> String {
        EncryptionKeyAskPrompt.text(app: "Lumen Journal", appID: "6450000001", bundleID: "dev.example.lumen", answer: answer)
    }

    @Test func noGoesWhereTheProjectKeepsItsSettings() {
        let prompt = Self.prompt(EncryptionKeyAnswer(value: .no, basis: .confirmed))
        #expect(prompt.contains("PRODUCT_BUNDLE_IDENTIFIER is dev.example.lumen"))
        #expect(prompt.contains("GENERATE_INFOPLIST_FILE = YES"))
        #expect(prompt.contains("INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO"))
        #expect(prompt.contains("every build configuration of that target"))
        #expect(prompt.contains("<key>ITSAppUsesNonExemptEncryption</key><false/>"))
        #expect(prompt.contains("Leave other targets alone"))
        #expect(prompt.contains("such as a watchOS app"))
        #expect(prompt.contains("report alreadyThere"))
        #expect(prompt.contains("Commit only when the project's own instructions"))
        #expect(prompt.contains("Never push."))
        #expect(prompt.contains("Don't build, archive or upload"))
        #expect(prompt.contains("report_encryption_key"))
        #expect(prompt.contains("the answers confirmed on the Export Compliance page"))
        #expect(!prompt.contains("ITSEncryptionExportComplianceCode"))
    }

    @Test func yesNamesTheApprovedDeclarationsCode() {
        let prompt = Self.prompt(EncryptionKeyAnswer(value: .yes, code: "a1b2c3", declarationID: "decl-1", basis: .build(number: "42")))
        #expect(prompt.contains("INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = YES"))
        #expect(prompt.contains("INFOPLIST_KEY_ITSEncryptionExportComplianceCode = a1b2c3"))
        #expect(prompt.contains("<key>ITSEncryptionExportComplianceCode</key><string>a1b2c3</string>"))
        #expect(prompt.contains("decl-1"))
        #expect(prompt.contains("build 42’s answer"))
    }

    @Test func theRunEditsTheProjectButNeverBuildsPushesOrUploads() {
        let purpose = EncryptionKeyAskPrompt.purpose
        #expect(purpose == .encryptionKey)
        #expect(purpose.permissions == .encryptionKey)
        #expect(purpose.title == "Add the export compliance key")
        let permissions = ClaudeCodePermissions.encryptionKey
        let rules = permissions.allowRules(port: port)
        #expect(permissions.tools.contains("Edit"))
        #expect(rules.contains("Write"))
        #expect(rules.contains("Bash(plutil -lint *)"))
        #expect(rules.contains("Bash(xcodebuild -showBuildSettings*)"))
        #expect(rules.contains("Bash(git commit:*)"))
        #expect(!rules.contains("Bash(xcodebuild:*)"))
        #expect(!rules.contains { $0.contains("curl") })
        #expect(permissions.denyRules.contains("Bash(git push:*)"))
        #expect(permissions.denyRules.contains("Bash(xcrun altool:*)"))
        #expect(permissions.denyRules.contains("Bash(xcodebuild archive*)"))
        #expect(permissions.systemPrompt.contains("only when the project's own instructions"))
        #expect(permissions.systemPrompt.contains("Never push."))
        #expect(!ClaudeCodeInvocation.longCommandRuns.contains(permissions))
    }
}
