//
//  PayElsewhereCheck.swift
//  Atlas
//

import Foundation

/// 3.1.1 and 3.1.3: texts that send people to pay outside the App Store
/// (`StoreTextPayElsewherePatterns`) in the description, promotional
/// text, What's New, captions and product pages' promotional texts. Since
/// May 2025 the United States storefront allows it, so English (U.S.) is a
/// Check (other storefronts show it too); every other language is Likely
/// when the words can only mean paying elsewhere.
struct PayElsewhereCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.payElsewhere

    /// The locale the United States storefront shows.
    static let usLocale = "en-US"

    private static let listingFields: Set<ListingField> = [.description, .promotionalText, .whatsNew]

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let texts = facts.texts else {
            return .notChecked(facts.gap(for: id, fallback: String(localized: "Atlas couldn’t read the store texts.", comment: "kind:error")))
        }
        return .risks(texts.texts.filter(Self.isRead).compactMap { risk(for: $0) })
    }

    /// The places people read before buying.
    static func isRead(_ text: ReviewRiskText) -> Bool {
        switch text.place {
        case .storeListing: text.field.map { listingFields.contains($0) } ?? false
        case .caption, .productPage: true
        case .inAppText, .eventText, .reviewNotes: false
        }
    }

    private func risk(for text: ReviewRiskText) -> ReviewRisk? {
        let matches = StoreTextPayElsewherePatterns.matches(in: text.text)
        guard !matches.isEmpty else { return nil }
        let isUS = text.locale == Self.usLocale
        let isClear = matches.contains(where: \.isClear)
        return ReviewRisk(
            check: id,
            subject: "\(text.key).payElsewhere",
            guideline: "3.1.1",
            level: isClear && !isUS ? .likely : .check,
            title: String(localized: "Pay outside the App Store · \(text.label)", comment: "kind:title · an App Review risk"),
            why: isUS
                ? String(
                    localized: "Only the US storefront allows pointing to paying on the web; English (U.S.) shows elsewhere too.",
                    comment: "kind:why · an App Review risk"
                )
                : String(
                    localized: "Outside the US, App Review rejects texts that point to paying elsewhere (Guideline 3.1.1).",
                    comment: "kind:why · an App Review risk"
                ),
            evidence: matches.prefix(3).map { ReviewRiskEvidence(place: text.label, excerpt: $0.phrase, locale: text.locale) },
            howSure: isClear ? .fairlySure : .notVerySure,
            fix: fix(for: text)
        )
    }

    private func fix(for text: ReviewRiskText) -> ReviewRiskFix {
        let advice = String(
            localized: "Leave out where else to pay; outside the US, features unlock with in-app purchases.",
            comment: "kind:fix · an App Review risk"
        )
        return switch text.place {
        case .caption: ReviewRiskFix(advice: advice, tool: "propose_captions", arguments: ["slot": text.owner ?? "", "locale": text.locale])
        case .productPage: ReviewRiskFix(advice: advice, tool: "propose_product_page_texts", arguments: ["pageId": text.owner ?? "", "locale": text.locale])
        default: ReviewRiskFix(advice: advice, tool: "propose_listing_text", arguments: ["field": text.field?.rawValue ?? "", "locale": text.locale])
        }
    }
}
