//
//  SubscriptionTermsCheck.swift
//  Atlas
//

import Foundation

/// 3.1.2(c): an app with auto-renewable subscriptions needs a Privacy
/// Policy URL and a Terms of Use (EULA) link in its metadata: a custom
/// license agreement in App Store Connect, or a link in the description
/// of each language (Apple's standard EULA counts). The description read
/// is the one waiting in Review & Push when there is one.
struct SubscriptionTermsCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.subscriptionTerms

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let products = facts.products else {
            return .notChecked(facts.gap(for: id, fallback: String(localized: "Atlas couldn’t read the app’s subscriptions.", comment: "kind:error")))
        }
        let count = products.subscriptions.count
        guard count > 0 else { return .clear }
        var risks: [ReviewRisk] = []
        if let links = facts.links, !Self.hasPrivacyPolicy(links, texts: facts.texts) {
            risks.append(privacyRisk(count: count, primaryLocale: links.primaryLocale))
        }
        guard products.hasCustomEULA != true else { return .risks(risks) }
        let descriptions = Self.descriptions(facts)
        guard !descriptions.locales.isEmpty else {
            if !risks.isEmpty { return .risks(risks) }
            return .notChecked(String(localized: "Atlas couldn’t read the app’s descriptions.", comment: "kind:error"))
        }
        let missing = descriptions.locales.filter { !ReviewRiskTermsLink.has(in: descriptions.texts[$0] ?? "") }
        if !missing.isEmpty {
            risks.append(termsRisk(missing: missing, of: descriptions.locales.count, primary: descriptions.primary, eulaKnown: products.hasCustomEULA != nil))
        }
        return .risks(risks)
    }

    // MARK: - Descriptions

    /// Each language's description as App Review will read it: from the
    /// store texts (with what waits in Review & Push) when they were read,
    /// else as pushed.
    static func descriptions(_ facts: ReviewRiskFacts) -> (texts: [String: String], locales: [String], primary: String) {
        let products = facts.products ?? ReviewRiskProductFacts()
        var texts = products.descriptions
        var locales = products.locales
        var primary = products.primaryLocale
        if let read = facts.texts, !read.listing(.description).isEmpty {
            primary = read.primaryLocale
            for text in read.listing(.description) {
                texts[text.locale] = text.text
                if !locales.contains(text.locale) { locales.append(text.locale) }
            }
        }
        for locale in texts.keys.sorted() where !locales.contains(locale) {
            locales.append(locale)
        }
        // The primary language first, as the list reads it.
        if let index = locales.firstIndex(of: primary), index > 0 { locales.insert(locales.remove(at: index), at: 0) }
        return (texts, locales, primary)
    }

    /// A Privacy Policy URL in any language, pushed or waiting in Review &
    /// Push.
    static func hasPrivacyPolicy(_ links: ReviewRiskLinkFacts, texts: ReviewRiskTextFacts?) -> Bool {
        let pushed = links.privacyPolicyURLs.values
        let queued = texts?.listing(.privacyPolicyURL).map(\.text) ?? []
        return (Array(pushed) + queued).contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// "German", for a locale code.
    static func name(of locale: String) -> String {
        StoreLocaleCatalog.locale(code: locale)?.name ?? locale
    }

    // MARK: - Risks

    private func privacyRisk(count: Int, primaryLocale: String) -> ReviewRisk {
        ReviewRisk(
            check: id, subject: "privacyPolicy", level: .blocksReview,
            title: String(localized: "No Privacy Policy URL for subscriptions", comment: "kind:title · an App Review risk"),
            why: count == 1
                ? String(
                    localized: "App Review rejects a subscription without a Privacy Policy URL in App Store Connect.",
                    comment: "kind:description · why an App Review risk matters"
                )
                : String(
                    localized: "App Review rejects your \(count) subscriptions without a Privacy Policy URL in App Store Connect.",
                    comment: "kind:description · why an App Review risk matters"
                ),
            evidence: [ReviewRiskEvidence(
                place: String(localized: "Privacy Policy URL · App Information", comment: "kind:label · where an App Review risk shows")
            )],
            howSure: .sure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Add your Privacy Policy URL in App Information, in every language.",
                    comment: "kind:description · how to fix an App Review risk"
                ),
                tool: "propose_listing_text",
                arguments: ["field": ListingField.privacyPolicyURL.rawValue, "locales": primaryLocale]
            )
        )
    }

    private func termsRisk(missing: [String], of total: Int, primary: String, eulaKnown: Bool) -> ReviewRisk {
        let primaryLacks = missing.contains(primary)
        let level: ReviewRiskLevel = primaryLacks && eulaKnown ? .blocksReview : .likely
        let howSure: HowSure = eulaKnown && primaryLacks ? .sure : .fairlySure
        let title = if missing.count == total {
            String(localized: "No Terms of Use link in the description", comment: "kind:title · an App Review risk")
        } else if missing.count == 1 {
            String(localized: "Terms of Use link missing in \(Self.name(of: missing[0]))", comment: "kind:title · an App Review risk")
        } else {
            String(localized: "Terms of Use link missing in \(missing.count) languages", comment: "kind:title · an App Review risk")
        }
        let why = if !eulaKnown {
            String(
                localized: "Atlas couldn’t read your license agreement, and \(missing.count) languages lack a Terms of Use link.",
                comment: "kind:description · why an App Review risk matters"
            )
        } else if missing.count == 1 {
            String(
                localized: "App Review rejects subscriptions without a Terms of Use link; 1 language lacks one.",
                comment: "kind:description · why an App Review risk matters"
            )
        } else {
            String(
                localized: "App Review rejects subscriptions without a Terms of Use link; \(missing.count) languages lack one.",
                comment: "kind:description · why an App Review risk matters"
            )
        }
        let evidence = missing.map { locale in
            ReviewRiskEvidence(
                place: String(localized: "Description · \(Self.name(of: locale))", comment: "kind:label · where an App Review risk shows"),
                locale: locale
            )
        }
        return ReviewRisk(
            check: id, subject: "termsOfUse", level: level, title: title, why: why, evidence: evidence, howSure: howSure,
            fix: ReviewRiskFix(
                advice: String(
                    localized: "Add a Terms of Use link to each description, yours or Apple’s standard EULA: \(ReviewRiskTermsLink.standardEULA)",
                    comment: "kind:description · how to fix an App Review risk"
                ),
                tool: "propose_listing_text",
                arguments: ["field": ListingField.description.rawValue, "locales": missing.joined(separator: ",")]
            )
        )
    }
}
