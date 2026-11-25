//
//  TrademarksAndNamesCheck.swift
//  Atlas
//

import Foundation

/// Apple's trademarks used as the app's own (5.2.5) and names stuffed with
/// search terms (2.3.7), in every language's name, subtitle and keywords:
/// - "iPhone", "Apple Watch", "Siri"… in the name (Likely; "for iPhone" is
///   referential, a Check) or the subtitle (Likely; "for iPad" is fine);
///   "Mac" and "Apple" only as a Check, since they're often the word.
/// - Trademarks in the keywords: App Store search reads the platform
///   itself (Check).
/// - A name or subtitle with 3 separators or more (Likely), the same name
///   and subtitle, and keywords that repeat them (Check).
/// The description may say what the app runs on, so it isn't read here.
struct TrademarksAndNamesCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.trademarksAndNames

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let texts = facts.texts else {
            return .notChecked(facts.gap(for: id, fallback: String(localized: "Atlas couldn’t read the store texts.", comment: "kind:error")))
        }
        return .risks(texts.listingLocales.flatMap { locale -> [ReviewRisk] in
            let name = texts.listing(.name, locale: locale)
            let subtitle = texts.listing(.subtitle, locale: locale)
            let keywords = texts.listing(.keywords, locale: locale)
            var risks: [ReviewRisk] = []
            for text in [name, subtitle].compactMap(\.self) {
                risks += trademarkRisks(in: text)
                if let stuffed = stuffingRisk(in: text) { risks.append(stuffed) }
            }
            if let name, let subtitle, StoreTextNameStuffing.isSame(name.text, subtitle.text) {
                risks.append(sameRisk(name: name, subtitle: subtitle))
            }
            if let keywords {
                risks += keywordRisks(keywords, name: name?.text ?? facts.appName, subtitle: subtitle?.text ?? "")
            }
            return risks
        })
    }

    // MARK: - Trademarks

    private func trademarkRisks(in text: ReviewRiskText) -> [ReviewRisk] {
        let isName = text.field == .name
        let uses = StoreTextAppleTrademarks.uses(in: text.text).filter { isName || !$0.isReferential }
        guard !uses.isEmpty else { return [] }
        let clear = uses.filter { !$0.isAmbiguous && !$0.isReferential }
        let level: ReviewRiskLevel = clear.isEmpty ? .check : .likely
        let howSure: HowSure = clear.isEmpty ? .notVerySure : .fairlySure
        let terms = uses.map { "“\($0.term)”" }.formatted(.list(type: .and))
        let title = String(localized: "Apple trademark in \(text.label)", comment: "kind:title · an App Review risk; e.g. Name · German")
        let why = clear.isEmpty
            ? String(localized: "App Review may read \(terms) as Apple’s trademark, not the app’s (Guideline 5.2.5).", comment: "kind:why · an App Review risk")
            : String(localized: "App Review rejects Apple’s trademarks used as the app’s own (Guideline 5.2.5).", comment: "kind:why · an App Review risk")
        return [ReviewRisk(
            check: id,
            subject: "\(text.key).trademark",
            guideline: "5.2.5",
            level: level,
            title: title,
            why: why,
            evidence: uses.prefix(3).map {
                ReviewRiskEvidence(place: text.label, excerpt: ReviewRiskTextExcerpt.around($0.term, in: text.text), locale: text.locale)
            },
            howSure: howSure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Name the app by what it does; say which devices it runs on in the description.",
                    comment: "kind:fix · an App Review risk"
                ),
                tool: "propose_listing_text",
                arguments: ["field": text.field?.rawValue ?? "", "locale": text.locale]
            )
        )]
    }

    // MARK: - Stuffing

    private func stuffingRisk(in text: ReviewRiskText) -> ReviewRisk? {
        let separators = StoreTextNameStuffing.separators(in: text.text)
        guard separators.count >= StoreTextNameStuffing.separatorLimit else { return nil }
        let count = separators.count
        return ReviewRisk(
            check: id,
            subject: "\(text.key).stuffing",
            guideline: "2.3.7",
            level: .likely,
            title: String(localized: "Reads like a keyword list · \(text.label)", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "App Review rejects names packed with search terms; this one has \(count) separators.",
                comment: "kind:why · an App Review risk"
            ),
            evidence: [ReviewRiskEvidence(place: text.label, excerpt: text.text, locale: text.locale)],
            howSure: .fairlySure,
            fix: ReviewRiskFix(
                advice: String(localized: "Keep one name and one short phrase; search terms go in the keywords.", comment: "kind:fix · an App Review risk"),
                tool: "propose_listing_text",
                arguments: ["field": text.field?.rawValue ?? "", "locale": text.locale]
            )
        )
    }

    private func sameRisk(name: ReviewRiskText, subtitle: ReviewRiskText) -> ReviewRisk {
        let language = ReviewRiskTextExcerpt.localeName(name.locale)
        return ReviewRisk(
            check: id,
            subject: "storeListing.subtitle.\(name.locale).sameAsName",
            guideline: "2.3.7",
            level: .check,
            title: String(localized: "Subtitle repeats the name · \(language)", comment: "kind:title · an App Review risk"),
            why: String(
                localized: "The subtitle adds nothing to search when it says the name again (Guideline 2.3.7).",
                comment: "kind:why · an App Review risk"
            ),
            evidence: [ReviewRiskEvidence(place: subtitle.label, excerpt: subtitle.text, locale: subtitle.locale)],
            howSure: .sure,
            fix: ReviewRiskFix(
                advice: String(localized: "Say what the app does in the subtitle, in a few words.", comment: "kind:fix · an App Review risk"),
                tool: "propose_listing_text",
                arguments: ["field": ListingField.subtitle.rawValue, "locale": subtitle.locale]
            )
        )
    }

    // MARK: - Keywords

    private func keywordRisks(_ keywords: ReviewRiskText, name: String, subtitle: String) -> [ReviewRisk] {
        var risks: [ReviewRisk] = []
        let fix = ReviewRiskFix(
            advice: String(localized: "Use the room for words people search that the name and subtitle don’t have.", comment: "kind:fix · an App Review risk"),
            tool: "propose_listing_text",
            arguments: ["field": ListingField.keywords.rawValue, "locale": keywords.locale]
        )
        let trademarks = StoreTextAppleTrademarks.keywordTerms(in: keywords.text)
        if !trademarks.isEmpty {
            let count = trademarks.count
            risks.append(ReviewRisk(
                check: id,
                subject: "\(keywords.key).trademark",
                guideline: "5.2.5",
                level: .check,
                title: String(localized: "Apple trademarks in \(keywords.label)", comment: "kind:title · an App Review risk"),
                why: String(
                    localized: "App Store search knows the platform already; \(count) keywords are Apple’s trademarks.",
                    comment: "kind:why · an App Review risk"
                ),
                evidence: [ReviewRiskEvidence(place: keywords.label, excerpt: trademarks.joined(separator: ", "), locale: keywords.locale)],
                howSure: .sure,
                fix: fix
            ))
        }
        let repeated = StoreTextNameStuffing.repeatedKeywords(keywords.text, name: name, subtitle: subtitle)
        if !repeated.isEmpty {
            let count = repeated.count
            risks.append(ReviewRisk(
                check: id,
                subject: "\(keywords.key).repeatsName",
                guideline: "2.3.7",
                level: .check,
                title: String(
                    localized: "Keywords repeat the name · \(ReviewRiskTextExcerpt.localeName(keywords.locale))",
                    comment: "kind:title · an App Review risk"
                ),
                why: String(localized: "Search reads the name and subtitle already; \(count) keywords repeat them.", comment: "kind:why · an App Review risk"),
                evidence: [ReviewRiskEvidence(place: keywords.label, excerpt: repeated.joined(separator: ", "), locale: keywords.locale)],
                howSure: .sure,
                fix: fix
            ))
        }
        return risks
    }
}
