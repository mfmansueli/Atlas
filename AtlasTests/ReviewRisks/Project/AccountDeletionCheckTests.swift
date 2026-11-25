//
//  AccountDeletionCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `AccountDeletionCheck` (5.1.1(v)): sign-up without a way to delete the
/// account, sign-in alone, and Sign in with Apple's token on deletion.
@Suite("Review risks · account deletion")
struct AccountDeletionCheckTests {
    private typealias Fixtures = ReviewRiskProjectFixtures
    private let check = AccountDeletionCheck()

    private func risks(_ outcome: ReviewRiskOutcome) -> [ReviewRisk] {
        if case let .risks(risks) = outcome { return risks }
        return []
    }

    @Test func withoutAProjectFolderItSaysWhereToChooseOne() {
        #expect(check.run(Fixtures.facts(nil)) == .notChecked(ReviewRiskProjectCheckSupport.noProject))
    }

    @Test func aFolderWithoutSwiftFilesIsNotChecked() {
        #expect(check.run(Fixtures.facts(Fixtures.project(swiftFiles: 0))) == .notChecked(ReviewRiskProjectCheckSupport.noSwiftFiles))
    }

    @Test func signUpWithoutDeletionIsLikely() throws {
        let project = Fixtures.scanned("""
        struct SignUpView: View {
            func submit() async throws {
                try await Auth.auth().createUser(withEmail: email, password: password)
            }
        }
        """, file: "Lumen/Account/SignUpView.swift")
        let risk = try #require(risks(check.run(Fixtures.facts(project))).first)
        #expect(risk.id == "accountDeletion:app")
        #expect(risk.level == .likely)
        #expect(risk.howSure == .fairlySure)
        #expect(risk.guideline == "5.1.1(v)")
        #expect(risk.evidence.first?.place == "Lumen/Account/SignUpView.swift:1")
        #expect(risk.fix.tool == "suggest_fields")
        #expect(risk.fix.arguments == ["area": "info", "page": "review", "field": "notes"])
        #expect(risk.why.count <= AssistantTextLimits.why)
        #expect(AssistantTextLimits.titleRefusal(risk.title, field: "title") == nil)
    }

    @Test func signUpWithDeleteAccountIsClear() {
        let project = Fixtures.scanned("""
        try await Auth.auth().createUser(withEmail: email, password: password)
        Button("Delete Account", role: .destructive) { confirming = true }
        """)
        #expect(check.run(Fixtures.facts(project)) == .clear)
    }

    @Test func signInAloneOnlyNeedsALook() throws {
        let project = Fixtures.scanned("""
        try await Auth.auth().signIn(withEmail: email, password: password)
        """)
        let risk = try #require(risks(check.run(Fixtures.facts(project))).first)
        #expect(risk.level == .check)
        #expect(risk.howSure == .notVerySure)
    }

    @Test func anAppWithoutAccountsIsClear() {
        let project = Fixtures.scanned("""
        struct JournalView: View {
            var body: some View { Text("Today") }
        }
        """)
        #expect(check.run(Fixtures.facts(project)) == .clear)
    }

    @Test func pastTheFileLimitItIsLessSure() throws {
        var project = Fixtures.project()
        project.add(Fixtures.match("Firebase createUser"), for: .signal(.signUp))
        project.reachedFileLimit = true
        let risk = try #require(risks(check.run(Fixtures.facts(project))).first)
        #expect(risk.howSure == .notVerySure)
    }

    @Test func signInWithAppleAndDeletionWithoutRevokingNeedsALook() throws {
        var project = Fixtures.project()
        project.add(Fixtures.match("Sign in with Apple", line: 4), for: .signal(.appleSignIn))
        project.add(Fixtures.match("an account deletion", line: 40), for: .signal(.accountDeletion))
        let risk = try #require(risks(check.run(Fixtures.facts(project))).first)
        #expect(risk.id == "accountDeletion:appleTokenRevoke")
        #expect(risk.level == .check)

        project.add(Fixtures.match("Sign in with Apple token revoke", line: 44), for: .signal(.appleTokenRevoke))
        #expect(check.run(Fixtures.facts(project)) == .clear)
    }
}
