//
//  ContentRiskTestSupport.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Facts for the content and China mainland checks' tests: store texts,
/// review notes, age rating answers, App Compliance and the project, built
/// by hand.
enum ContentRiskTestSupport {
    static let appID = "6450000002"

    static func text(_ field: ListingField, _ text: String, locale: String = "en-US") -> ReviewRiskText {
        ReviewRiskText(
            place: .storeListing,
            field: field,
            label: "\(field.title) · \(locale)",
            locale: locale,
            text: text,
            key: "storeListing.\(field.rawValue).\(locale)"
        )
    }

    /// Every question answered None or No, then `overrides`.
    static func answers(_ overrides: [AgeRatingQuestion: AgeRatingAnswer] = [:]) -> AgeRatingAnswers {
        var answers = AgeRatingAnswers()
        for (question, answer) in overrides {
            answers[question] = answer
        }
        return answers
    }

    /// Sold in the United States, and in China mainland when `soldInChina`.
    static func compliance(
        soldInChina: Bool,
        answers: ComplianceAnswers = ComplianceAnswers(),
        stopsSellingInChina: Bool = false
    ) -> ComplianceReport {
        let territories = [
            ComplianceTerritory(id: "availability-USA", territoryID: "USA", isAvailable: true),
            ComplianceTerritory(id: "availability-CHN", territoryID: ComplianceRegion.chinaMainland, isAvailable: soldInChina),
        ]
        return ComplianceReport(
            appName: "Lumen",
            content: ComplianceContent(territories: territories),
            general: GeneralValues(primaryCategory: "LIFESTYLE"),
            ageRating: AgeRatingAnswers(),
            answers: answers,
            stopsSellingInChina: stopsSellingInChina
        )
    }

    /// Both China mainland declarations marked as declared, with `answers`.
    static func declared(_ answers: ComplianceAnswers = ComplianceAnswers()) -> ComplianceAnswers {
        var answers = answers
        answers.declared = [.aiGeneratedContent, .securityAssessment]
        return answers
    }

    static func facts(
        name: String = "Lumen",
        texts: [ReviewRiskText] = [],
        ageRating: AgeRatingAnswers? = ContentRiskTestSupport.answers(),
        unanswered: [AgeRatingQuestion] = [],
        reviewNotes: String = "",
        hasReviewInformation: Bool = true,
        primaryCategory: String? = "LIFESTYLE",
        compliance: ComplianceReport? = ContentRiskTestSupport.compliance(soldInChina: false, answers: ContentRiskTestSupport.declared()),
        supportURL: String? = "https://example.com/support",
        packages: Set<String>? = nil,
        imports: Set<String> = [],
        links: ReviewRiskLinkFacts? = nil
    ) -> ReviewRiskFacts {
        var facts = ReviewRiskFacts(appID: appID, appName: name, bundleID: "com.example.lumen", now: Date(timeIntervalSince1970: 1_790_000_000))
        var all = [text(.name, name)] + texts
        if !reviewNotes.isEmpty {
            all.append(ReviewRiskText(place: .reviewNotes, field: nil, label: "App Review notes", locale: "", text: reviewNotes, key: "reviewNotes"))
        }
        facts.content = ReviewRiskContentFacts(
            ageRating: ageRating,
            unansweredQuestions: unanswered,
            hasReviewInformation: hasReviewInformation,
            reviewNotes: reviewNotes,
            primaryCategory: primaryCategory,
            compliance: compliance,
            supportURL: supportURL,
            texts: all
        )
        if let packages {
            facts.project = ReviewRiskProjectFacts(folderName: name, packages: packages, imports: imports)
        }
        facts.links = links
        return facts
    }

    static func risks(_ outcome: ReviewRiskOutcome) -> [ReviewRisk] {
        guard case let .risks(risks) = outcome else { return [] }
        return risks
    }

    static func isNotChecked(_ outcome: ReviewRiskOutcome) -> Bool {
        if case .notChecked = outcome { return true }
        return false
    }
}
