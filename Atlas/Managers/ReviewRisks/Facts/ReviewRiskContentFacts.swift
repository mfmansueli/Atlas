//
//  ReviewRiskContentFacts.swift
//  Atlas
//

import Foundation

/// Age rating, App Review information, categories and App Compliance, as
/// App Review will see them: App Store Connect's values with what waits in
/// Review & Push on top. Read by `ReviewRiskFactsLoader+Content.swift`.
/// A part that couldn't be read is nil.
struct ReviewRiskContentFacts: Hashable, Sendable {
    /// The age rating answers with the queued ones on top; nil when App
    /// Information couldn't be read or the app has no questionnaire yet.
    var ageRating: AgeRatingAnswers?
    /// Questions App Store Connect has no answer for and nothing queued
    /// answers, in the questionnaire's order.
    var unansweredQuestions: [AgeRatingQuestion] = []
    /// App Review information was read (the three fields below mean
    /// something).
    var hasReviewInformation = false
    /// "Sign-in required" is on.
    var signInRequired = false
    /// A demo account's user name and password are filled in (or queued).
    var hasDemoAccount = false
    /// App Review's notes for the version, queued ones on top.
    var reviewNotes = ""
    /// Category IDs, e.g. `SOCIAL_NETWORKING`.
    var primaryCategory: String?
    var secondaryCategory: String?
    /// The App Compliance page as App Information builds it (Apple's
    /// countries, the person's answers, stopping sales in China mainland
    /// from the queue); nil when it couldn't be read.
    var compliance: ComplianceReport?
    /// The primary language's Support URL from the store page, for 1.2
    /// when the links weren't read: "" when it's empty, nil when the store
    /// page couldn't be read.
    var supportURL: String?
    /// The words the content checks read when `ReviewRiskFacts.texts` is
    /// missing: name, subtitle, description, keywords and promotional text
    /// in the primary language and Simplified Chinese, and the review notes.
    var texts: [ReviewRiskText] = []

    init(
        ageRating: AgeRatingAnswers? = nil,
        unansweredQuestions: [AgeRatingQuestion] = [],
        hasReviewInformation: Bool = false,
        signInRequired: Bool = false,
        hasDemoAccount: Bool = false,
        reviewNotes: String = "",
        primaryCategory: String? = nil,
        secondaryCategory: String? = nil,
        compliance: ComplianceReport? = nil,
        supportURL: String? = nil,
        texts: [ReviewRiskText] = []
    ) {
        self.ageRating = ageRating
        self.unansweredQuestions = unansweredQuestions
        self.hasReviewInformation = hasReviewInformation
        self.signInRequired = signInRequired
        self.hasDemoAccount = hasDemoAccount
        self.reviewNotes = reviewNotes
        self.primaryCategory = primaryCategory
        self.secondaryCategory = secondaryCategory
        self.compliance = compliance
        self.supportURL = supportURL
        self.texts = texts
    }

    /// Sold in China mainland and staying there: the declarations are the
    /// person's to answer. False when China mainland comes off sale with
    /// the next push, or the page couldn't be read.
    var isSoldInChina: Bool {
        guard let compliance else { return false }
        return compliance.chinaDeclarations.isSoldThere && !compliance.stopsSellingInChina
    }

    /// The answer is Yes (or Infrequent, Frequent).
    func answers(_ question: AgeRatingQuestion) -> Bool {
        ageRating?[question].isPresent ?? false
    }
}
