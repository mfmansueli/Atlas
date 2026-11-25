//
//  ReviewRiskFactsLoader+Content.swift
//  Atlas
//

import Foundation

extension ReviewRiskFactsLoader {
    /// Age rating, App Review information, categories and App Compliance,
    /// with what waits in Review & Push on top, and the words the content
    /// checks read. Built from what the run already read (no extra calls
    /// to App Store Connect); nil when neither App Information nor App
    /// Compliance could be read.
    func contentFacts(for app: StoreApp, shared: ReviewRiskSharedContent) async -> ReviewRiskContentFacts? {
        guard shared.appInformation != nil || shared.compliance != nil else { return nil }
        let sectionChanges = changes.changes(for: app.id, section: .appInformation)
        let ids = shared.appInformation?.ids ?? AppInformationResourceIDs(appID: app.id, appInfoID: "")
        let builder = AppInformationChangeBuilder(appID: app.id, ids: ids, versionString: shared.appInformation?.version?.versionString)
        var facts = ReviewRiskContentFacts()
        var general = GeneralValues()
        var ageAnswers = AgeRatingAnswers()
        if let information = shared.appInformation {
            general = builder.general(information.general, with: sectionChanges)
            let ageRating = builder.ageRating(information.ageRating, with: sectionChanges)
            ageAnswers = ageRating.answers
            if information.ids.ageRatingDeclarationID != nil {
                facts.ageRating = ageRating.answers
                facts.unansweredQuestions = Self.unansweredQuestions(information.ageRating, builder: builder, changes: sectionChanges)
            }
            if information.version != nil {
                // A queued password lives in the Keychain: it counts as filled in.
                let review = builder.review(information.review, with: sectionChanges, password: { Self.queuedPasswordMark })
                facts.hasReviewInformation = true
                facts.signInRequired = review.signInRequired
                facts.hasDemoAccount = !review.userName.trimmingCharacters(in: .whitespaces).isEmpty && !review.password.isEmpty
                facts.reviewNotes = review.notes
            }
            facts.primaryCategory = general.primaryCategory
            facts.secondaryCategory = general.secondaryCategory
        }
        if let compliance = shared.compliance {
            let notes = services.appInformation.notes.notes(for: app.id)
            facts.compliance = ComplianceReport(
                appName: app.name,
                content: compliance,
                general: general,
                ageRating: ageAnswers,
                answers: notes.compliance,
                stopsSellingInChina: builder.stopsSelling(in: ComplianceRegion.chinaMainland, with: changes.changes(for: app.id))
            )
        }
        facts.texts = Self.contentTexts(shared.storePage, reviewNotes: facts.reviewNotes)
        if let page = shared.storePage {
            facts.supportURL = page.texts[page.primaryLocale]?[.supportURL] ?? ""
        }
        return facts
    }

    /// Stands for a queued demo account password, which only the Keychain
    /// holds.
    static let queuedPasswordMark = "queued"

    /// The questions App Store Connect has no answer for (`null`) and no
    /// queued change answers.
    static func unansweredQuestions(
        _ values: AgeRatingValues,
        builder: AppInformationChangeBuilder,
        changes: [PendingChange]
    ) -> [AgeRatingQuestion] {
        AgeRatingQuestion.allCases.filter { question in
            !values.isAnswered(question)
                && AppInformationChangeBuilder.change(builder.changeID(.ageRating, question.rawValue), in: changes) == nil
        }
    }

    /// Name, subtitle, description, keywords and promotional text in the
    /// primary language and Simplified Chinese (China mainland reads it),
    /// and the review notes.
    static func contentTexts(_ page: StorePageContent?, reviewNotes: String) -> [ReviewRiskText] {
        var texts: [ReviewRiskText] = []
        if let page {
            var locales = [page.primaryLocale]
            if let chinese = page.locales.first(where: { $0.code == StoreLocale.chineseSimplified.code }), chinese != page.primaryLocale {
                locales.append(chinese)
            }
            for locale in locales {
                let values = page.texts[locale] ?? [:]
                for field in ListingField.allCases where ReviewRiskSignalScanner.fields.contains(field) {
                    guard let text = values[field], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    texts.append(ReviewRiskText(
                        place: .storeListing,
                        field: field,
                        label: String(
                            localized: "\(field.title) · \(locale.name)",
                            comment: "kind:label · where an App Review risk shows: a store text in one language"
                        ),
                        locale: locale.code,
                        text: text,
                        key: "storeListing.\(field.rawValue).\(locale.code)"
                    ))
                }
            }
        }
        if !reviewNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            texts.append(ReviewRiskText(
                place: .reviewNotes,
                field: nil,
                label: ReviewRiskSignalScanner.reviewNotesPlace,
                locale: "",
                text: reviewNotes,
                key: "reviewNotes"
            ))
        }
        return texts
    }
}
