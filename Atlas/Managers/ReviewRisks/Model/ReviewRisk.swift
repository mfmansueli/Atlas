//
//  ReviewRisk.swift
//  Atlas
//

import Foundation

/// Something in an app that App Review may reject, found by one of Atlas's
/// checks (`ReviewRiskCheck`) or confirmed by an assistant that read the
/// project (`report_review_risk`). Written the way Atlas writes a card:
/// title (at most 8 words, result first), why (at most 110 characters,
/// one number), then evidence and the fix on demand.
struct ReviewRisk: Identifiable, Codable, Hashable, Sendable {
    /// Stable across runs, so a dismissal sticks: "\(check):\(subject)",
    /// e.g. "subscriptionTerms:app" or "storeTexts:description.de-DE.pricing".
    var id: String
    var check: ReviewRiskCheckID
    /// The guideline App Review would cite, e.g. "3.1.2(c)"; the check's
    /// own when nil.
    var guideline: String
    var level: ReviewRiskLevel
    var title: String
    var why: String
    var evidence: [ReviewRiskEvidence]
    var howSure: HowSure
    var fix: ReviewRiskFix
    /// Who found it: Atlas's own check, or the assistant named here.
    var foundBy: String?

    init(
        check: ReviewRiskCheckID,
        subject: String = "app",
        guideline: String? = nil,
        level: ReviewRiskLevel,
        title: String,
        why: String,
        evidence: [ReviewRiskEvidence] = [],
        howSure: HowSure = .sure,
        fix: ReviewRiskFix,
        foundBy: String? = nil
    ) {
        id = "\(check.rawValue):\(subject)"
        self.check = check
        self.guideline = guideline ?? check.guideline
        self.level = level
        self.title = title
        self.why = why
        self.evidence = evidence
        self.howSure = howSure
        self.fix = fix
        self.foundBy = foundBy
    }

    /// Most serious first, then surest, then the checks' order.
    static func ordered(_ lhs: ReviewRisk, _ rhs: ReviewRisk) -> Bool {
        if lhs.level != rhs.level { return lhs.level < rhs.level }
        if lhs.howSure != rhs.howSure { return lhs.howSure > rhs.howSure }
        let order = ReviewRiskCheckID.allCases
        let left = order.firstIndex(of: lhs.check) ?? 0
        let right = order.firstIndex(of: rhs.check) ?? 0
        return left != right ? left < right : lhs.id < rhs.id
    }
}
