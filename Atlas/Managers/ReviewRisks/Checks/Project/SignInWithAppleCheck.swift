//
//  SignInWithAppleCheck.swift
//  Atlas
//

import Foundation

/// 4.8: an app that signs people in with another company's account (Google,
/// Facebook, Amazon, LINE, Kakao, X, Microsoft, or Firebase, Supabase and
/// Auth0 with one of them) must offer Sign in with Apple or an equal option
/// too. Apps that only use the company's own accounts, or are for education
/// or business, are exempt: the advice says so. Also: Sign in with Apple in
/// the code without its entitlement.
struct SignInWithAppleCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.signInWithApple
    static let entitlement = "com.apple.developer.applesignin"
    /// `ReviewRiskCodePatterns`' name for AuthenticationServices' Sign in with Apple.
    static let nativeName = "Sign in with Apple"

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let project = ReviewRiskProjectCheckSupport.readable(facts) else {
            return .notChecked(ReviewRiskProjectCheckSupport.unreadableReason(facts))
        }
        let others = project.matches(.thirdPartyLogin)
        let apple = project.matches(.appleSignIn)
        let hasEntitlement = project.entitlements.contains(Self.entitlement)
        // Sign in with Apple on the web (Supabase, Auth0) needs no entitlement.
        let native = apple.filter { $0.what == Self.nativeName }
        if !native.isEmpty, !hasEntitlement {
            return .risks([missingEntitlement(native)])
        }
        guard !others.isEmpty, apple.isEmpty, !hasEntitlement else { return .clear }
        return .risks([missingAppleSignIn(others)])
    }

    private func missingAppleSignIn(_ others: [ReviewRiskCodeMatch]) -> ReviewRisk {
        let names = ReviewRiskProjectCheckSupport.names(others)
        let first = names.first ?? ""
        let count = others.count
        let title = names.count == 1
            ? String(
                localized: "\(first) without Sign in with Apple",
                comment: "kind:title · App Review risk: another company's sign-in (e.g. Google Sign-In) without Sign in with Apple"
            )
            : String(
                localized: "Other sign-ins without Sign in with Apple",
                comment: "kind:title · App Review risk: other companies' sign-in without Sign in with Apple"
            )
        return ReviewRisk(
            check: id,
            level: .likely,
            title: title,
            why: String(
                localized: "Another company’s sign-in shows in \(count) places, with no Sign in with Apple beside it.",
                comment: "kind:why · App Review risk: third-party sign-in without Sign in with Apple; the number of places in the code"
            ),
            evidence: ReviewRiskProjectCheckSupport.evidence(others),
            howSure: .fairlySure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: """
                    Add Sign in with Apple (or another sign-in that keeps email private) next to \(names.formatted(.list(type: .and))). \
                    Apps that only use your company’s own accounts, or are for education or business, are exempt.
                    """,
                    comment: "kind:body · how to fix an App Review risk; the sign-ins found"
                )
            )
        )
    }

    private func missingEntitlement(_ apple: [ReviewRiskCodeMatch]) -> ReviewRisk {
        let count = apple.count
        return ReviewRisk(
            check: id,
            subject: "entitlement",
            level: .check,
            title: String(
                localized: "Sign in with Apple capability missing",
                comment: "kind:title · App Review risk: the code uses Sign in with Apple but the target lacks its capability"
            ),
            why: String(
                localized: "The code uses Sign in with Apple in \(count) places, but no entitlements file turns it on.",
                comment: "kind:why · App Review risk: Sign in with Apple entitlement missing; the number of places in the code"
            ),
            evidence: ReviewRiskProjectCheckSupport.evidence(apple),
            howSure: .fairlySure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Add the Sign in with Apple capability to the app target in Xcode (Signing & Capabilities).",
                    comment: "kind:body · how to fix an App Review risk"
                )
            )
        )
    }
}
