//
//  SimilarAppsCheck.swift
//  Atlas
//

import Foundation

/// 4.3 (spam): this app's subtitle and description in its primary
/// language against each of the person's other apps' (in the same
/// language when it has one), word for word (`TextShingleSimilarity`).
/// From 60% alike it's worth a look; from 80% App Review often reads the
/// apps as copies. Short texts aren't compared: they say too little.
struct SimilarAppsCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.similarApps

    static let checkFrom = 0.6
    static let likelyFrom = 0.8

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let texts = facts.texts else {
            return .notChecked(facts.gap(for: id, fallback: String(localized: "Atlas couldn’t read the store texts.", comment: "kind:error")))
        }
        guard let siblings = facts.siblings else {
            return .notChecked(String(localized: "Atlas couldn’t read your other apps.", comment: "kind:error"))
        }
        let locale = texts.primaryLocale
        guard let description = texts.listing(.description, locale: locale)?.text else { return .clear }
        let subtitle = texts.listing(.subtitle, locale: locale)?.text ?? ""
        let mine = subtitle.isEmpty ? description : "\(subtitle)\n\(description)"
        return .risks(siblings.filter { $0.appID != facts.appID }.compactMap { sibling -> ReviewRisk? in
            guard let other = sibling.text(in: locale), let score = TextShingleSimilarity.similarity(mine, other.text), score >= Self.checkFrom else {
                return nil
            }
            return risk(sibling, score: score, mine: mine, other: other, locale: locale)
        })
    }

    private func risk(_ sibling: ReviewRiskSiblingApp, score: Double, mine: String, other: (text: String, locale: String), locale: String) -> ReviewRisk {
        let percent = Int((score * 100).rounded())
        let passage = TextShingleSimilarity.sharedPassage(mine, other.text) ?? other.text
        let language = ReviewRiskTextExcerpt.localeName(other.locale)
        let isLikely = score >= Self.likelyFrom
        return ReviewRisk(
            check: id,
            subject: "similar.\(sibling.appID)",
            level: isLikely ? .likely : .check,
            title: String(localized: "Nearly the same texts as \(sibling.name)", comment: "kind:title · an App Review risk"),
            why: String(localized: "\(percent)% of the subtitle and description match \(sibling.name)’s.", comment: "kind:why · an App Review risk"),
            evidence: [ReviewRiskEvidence(
                place: "\(ListingField.description.title) · \(sibling.name) · \(language)",
                excerpt: passage,
                locale: other.locale
            )],
            howSure: isLikely ? .fairlySure : .notVerySure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Say what sets this app apart, or offer both as one app with in-app purchases.",
                    comment: "kind:fix · an App Review risk"
                ),
                tool: "propose_listing_text",
                arguments: ["field": ListingField.description.rawValue, "locale": locale]
            )
        )
    }
}
