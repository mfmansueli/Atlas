//
//  AccountDeletionCheck.swift
//  Atlas
//

import Foundation

/// 5.1.1(v): an app that creates accounts must let people delete them from
/// inside the app. Reads the Swift code: sign-up (Firebase `createUser`,
/// `signUp`, a sign-up screen or button) without anything that deletes an
/// account (`deleteAccount`, `currentUser?.delete()`, "Delete Account", a
/// deletion link) is likely rejected; sign-in alone only needs a look, since
/// the accounts may be made elsewhere. With Sign in with Apple, deleting an
/// account should revoke its token too.
struct AccountDeletionCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.accountDeletion

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let project = ReviewRiskProjectCheckSupport.readable(facts) else {
            return .notChecked(ReviewRiskProjectCheckSupport.unreadableReason(facts))
        }
        let signUps = project.matches(.signUp)
        let signIns = project.matches(.signIn) + project.matches(.appleSignIn) + project.matches(.thirdPartyLogin)
        let deletions = project.matches(.accountDeletion)
        if !deletions.isEmpty {
            return .risks(revokeRisk(project).map { [$0] } ?? [])
        }
        // Past the file limit, the deletion may be in a file Atlas didn't read.
        let partly = project.reachedFileLimit
        if !signUps.isEmpty {
            return .risks([missingDeletion(signUps, level: .likely, howSure: partly ? .notVerySure : .fairlySure, signsUp: true)])
        }
        if !signIns.isEmpty {
            return .risks([missingDeletion(signIns, level: .check, howSure: .notVerySure, signsUp: false)])
        }
        return .clear
    }

    private func missingDeletion(_ matches: [ReviewRiskCodeMatch], level: ReviewRiskLevel, howSure: HowSure, signsUp: Bool) -> ReviewRisk {
        let count = matches.count
        let title = signsUp
            ? String(localized: "No way to delete an account", comment: "kind:title · App Review risk: accounts can't be deleted in the app")
            : String(localized: "Check that accounts can be deleted", comment: "kind:title · App Review risk: accounts may not be deletable")
        let why = signsUp
            ? String(
                localized: "Sign-up shows in \(count) places in the code, but nothing deletes an account.",
                comment: "kind:why · App Review risk: accounts can't be deleted; the number of places in the code"
            )
            : String(
                localized: "Sign-in shows in \(count) places; an app that creates accounts must offer Delete Account.",
                comment: "kind:why · App Review risk: accounts may not be deletable; the number of places in the code"
            )
        let advice = signsUp
            ? String(
                localized: "Add Delete Account in the app (a direct link to a web page counts), then say where in the App Review notes.",
                comment: "kind:body · how to fix an App Review risk"
            )
            : String(
                localized: "If the app creates accounts, add Delete Account in it and say where in the App Review notes.",
                comment: "kind:body · how to fix an App Review risk"
            )
        return ReviewRisk(
            check: id,
            level: level,
            title: title,
            why: why,
            evidence: ReviewRiskProjectCheckSupport.evidence(matches),
            howSure: howSure,
            fix: ReviewRiskFix(advice: advice, tool: "suggest_fields", arguments: ["area": "info", "page": "review", "field": "notes"])
        )
    }

    /// Sign in with Apple, a deletion, and nothing that revokes the token.
    private func revokeRisk(_ project: ReviewRiskProjectFacts) -> ReviewRisk? {
        let apple = project.matches(.appleSignIn)
        guard !apple.isEmpty, project.matches(.appleTokenRevoke).isEmpty else { return nil }
        let count = apple.count
        return ReviewRisk(
            check: id,
            subject: "appleTokenRevoke",
            level: .check,
            title: String(
                localized: "Revoke Sign in with Apple on deletion",
                comment: "kind:title · App Review risk: deleting an account doesn't revoke its Sign in with Apple token"
            ),
            why: String(
                localized: "Sign in with Apple shows in \(count) places, but no code revokes its token when an account goes.",
                comment: "kind:why · App Review risk: Sign in with Apple token not revoked; the number of places in the code"
            ),
            evidence: ReviewRiskProjectCheckSupport.evidence(apple + project.matches(.accountDeletion), limit: 4),
            howSure: .notVerySure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "When an account is deleted, revoke its Sign in with Apple token with Apple’s REST API (often on your server).",
                    comment: "kind:body · how to fix an App Review risk"
                )
            )
        )
    }
}
