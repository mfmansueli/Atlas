//
//  SignInWithAppleCheckTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// `SignInWithAppleCheck` (4.8): another company's sign-in without Sign in
/// with Apple, and Sign in with Apple without its capability.
@Suite("Review risks · Sign in with Apple")
struct SignInWithAppleCheckTests {
    private typealias Fixtures = ReviewRiskProjectFixtures
    private let check = SignInWithAppleCheck()

    private func risks(_ outcome: ReviewRiskOutcome) -> [ReviewRisk] {
        if case let .risks(risks) = outcome { return risks }
        return []
    }

    @Test func withoutAProjectFolderItIsNotChecked() {
        #expect(check.run(Fixtures.facts(nil)) == .notChecked(ReviewRiskProjectCheckSupport.noProject))
    }

    @Test func googleSignInAloneIsLikely() throws {
        let project = Fixtures.scanned("""
        import GoogleSignIn
        GIDSignIn.sharedInstance.signIn(withPresenting: root)
        """, file: "Lumen/Login/LoginView.swift")
        let risk = try #require(risks(check.run(Fixtures.facts(project))).first)
        #expect(risk.id == "signInWithApple:app")
        #expect(risk.level == .likely)
        #expect(risk.howSure == .fairlySure)
        #expect(risk.title.contains("Google Sign-In"))
        #expect(risk.evidence.map(\.place) == ["Lumen/Login/LoginView.swift:1", "Lumen/Login/LoginView.swift:2"])
        #expect(risk.fix.advice.contains("exempt"))
        #expect(risk.why.count <= AssistantTextLimits.why)
        #expect(AssistantTextLimits.titleRefusal(risk.title, field: "title") == nil)
    }

    @Test func twoSignInsAreNamedInTheAdvice() throws {
        var project = Fixtures.project()
        project.add(Fixtures.match("Google Sign-In", line: 1), for: .signal(.thirdPartyLogin))
        project.add(Fixtures.match("Facebook Login", line: 2), for: .signal(.thirdPartyLogin))
        let risk = try #require(risks(check.run(Fixtures.facts(project))).first)
        #expect(!risk.title.contains("Google"))
        #expect(risk.fix.advice.contains("Google Sign-In"))
        #expect(risk.fix.advice.contains("Facebook Login"))
    }

    @Test func withSignInWithAppleBesideItItIsClear() {
        var project = Fixtures.scanned("""
        import GoogleSignIn
        SignInWithAppleButton(.signIn) { _ in } onCompletion: { _ in }
        """)
        project.entitlements = [SignInWithAppleCheck.entitlement]
        #expect(check.run(Fixtures.facts(project)) == .clear)
    }

    @Test func theEntitlementAloneCountsAsSignInWithApple() {
        var project = Fixtures.project()
        project.add(Fixtures.match("Google Sign-In"), for: .signal(.thirdPartyLogin))
        project.entitlements = [SignInWithAppleCheck.entitlement]
        #expect(check.run(Fixtures.facts(project)) == .clear)
    }

    @Test func signInWithAppleWithoutTheCapabilityNeedsALook() throws {
        let project = Fixtures.scanned("""
        let request = ASAuthorizationAppleIDProvider().createRequest()
        """)
        let risk = try #require(risks(check.run(Fixtures.facts(project))).first)
        #expect(risk.id == "signInWithApple:entitlement")
        #expect(risk.level == .check)
    }

    @Test func signInWithAppleOnTheWebNeedsNoCapability() {
        let project = Fixtures.scanned("""
        try await supabase.auth.signInWithOAuth(provider: .apple)
        """)
        #expect(check.run(Fixtures.facts(project)) == .clear)
    }

    @Test func dependenciesAloneAndFacebookAnalyticsAreNotASignIn() {
        var project = Fixtures.scanned("""
        import FacebookCore
        AppEvents.shared.logEvent(.completedRegistration)
        """)
        project.packages = ["googlesignin-ios", "facebook-ios-sdk"]
        #expect(check.run(Fixtures.facts(project)) == .clear)
    }
}
