//
//  AppInformationNeedsYou.swift
//  Atlas
//

import Foundation

/// What only the person can give on each App Information page, counted
/// for the page's card ("2 need you"): what Apple requires and the page
/// knows is missing. Suggestions don't count: they're the card's purple
/// "3 suggested", and accepting them often fills these in.
///
/// - General: the primary category, content rights (and, with
///   third-party content, that the rights are confirmed), and the
///   copyright while the version can still change.
/// - Age Rating: each question without an answer.
/// - App Compliance: each regulation waiting for an answer; once all are
///   answered, each still to enter in App Store Connect.
/// - Accessibility: nothing. The labels are voluntary.
/// - App Privacy: what waits in the worksheet (open questions, answers to
///   review), and at least one until it's marked published in App Store
///   Connect.
/// - App Review: each empty contact field, and the demo account's user
///   name and password while sign-in is required.
/// - Export Compliance: one until encryption is answered.
enum AppInformationNeedsYou {
    static func general(_ values: GeneralValues, asksCopyright: Bool) -> Int {
        var count = 0
        if values.primaryCategory == nil { count += 1 }
        switch values.contentRights {
        case nil: count += 1
        case .usesThirdPartyContent: if !values.rightsConfirmed { count += 1 }
        case .doesNotUseThirdPartyContent: break
        }
        if asksCopyright, values.copyright.trimmingCharacters(in: .whitespaces).isEmpty { count += 1 }
        return count
    }

    static func compliance(needCount: Int, toEnterCount: Int) -> Int {
        needCount > 0 ? needCount : toEnterCount
    }

    static func compliance(_ report: ComplianceReport) -> Int {
        compliance(needCount: report.needCount, toEnterCount: report.toEnterCount)
    }

    static func privacy(status: PrivacyWorksheetStatus, openQuestions: Int, unreviewed: Int) -> Int {
        if case .published = status { return 0 }
        return max(1, openQuestions + unreviewed)
    }

    static func review(_ values: AppReviewValues) -> Int {
        let contact = [values.firstName, values.lastName, values.phone, values.email].count {
            $0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard values.signInRequired else { return contact }
        return contact + [values.userName, values.password].count(where: \.isEmpty)
    }

    static func export(_ answers: ExportComplianceAnswers) -> Int {
        answers.usesNonExemptEncryption == nil ? 1 : 0
    }
}
