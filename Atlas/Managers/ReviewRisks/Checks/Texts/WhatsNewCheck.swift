//
//  WhatsNewCheck.swift
//  Atlas
//

import Foundation

/// 2.3.12 for the version being prepared, in every language, with what
/// waits in Review & Push: What's New empty (App Store Connect won't take an
/// update without it), naming another version ("New in Alba 1.2.1" while
/// 1.2.2 is prepared), or only generic ("Bug fixes and improvements"),
/// which is fine only when that's all the update does. A first version has
/// no What's New; a live version can't change, so neither is checked.
struct WhatsNewCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.whatsNew

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let version = facts.version else {
            return .notChecked(facts.gap(for: id, fallback: String(localized: "Atlas couldn’t read the version’s What’s New.", comment: "kind:error")))
        }
        guard version.isEditable, !version.isFirstVersion else { return .clear }
        return .risks(version.locales.flatMap { locale in
            risks(in: version.whatsNew[locale] ?? "", locale: locale, version: version, appName: facts.appName)
        })
    }

    private func risks(in text: String, locale: String, version: ReviewRiskVersionFacts, appName: String) -> [ReviewRisk] {
        let language = ReviewRiskTextExcerpt.localeName(locale)
        let place = "\(ListingField.whatsNew.title) · \(language)"
        let fix = ReviewRiskFix(
            advice: String(localized: "Write what changed in version \(version.versionString), in this language.", comment: "kind:fix · What’s New"),
            tool: "propose_listing_text",
            arguments: ["field": ListingField.whatsNew.rawValue, "locale": locale]
        )
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return [ReviewRisk(
                check: id,
                subject: "whatsNew.\(locale).empty",
                level: .blocksReview,
                title: String(localized: "What’s New is empty · \(language)", comment: "kind:title · an App Review risk"),
                why: String(
                    localized: "App Store Connect won’t submit an update without What’s New in each language (2.3.12).",
                    comment: "kind:why · an App Review risk"
                ),
                evidence: [ReviewRiskEvidence(place: place, locale: locale)],
                howSure: .sure,
                fix: fix
            )]
        }
        var risks: [ReviewRisk] = []
        if let other = WhatsNewVersionMention.otherVersion(in: text, preparing: version.versionString, appName: appName) {
            risks.append(ReviewRisk(
                check: id,
                subject: "whatsNew.\(locale).otherVersion",
                level: .likely,
                title: String(localized: "What’s New names version \(other) · \(language)", comment: "kind:title · an App Review risk"),
                why: String(
                    localized: "This update is version \(version.versionString); App Review reads What’s New as its changes.",
                    comment: "kind:why · an App Review risk"
                ),
                evidence: [ReviewRiskEvidence(place: place, excerpt: ReviewRiskTextExcerpt.around(other, in: text), locale: locale)],
                howSure: .fairlySure,
                fix: ReviewRiskFix(
                    advice: String(localized: "Name version \(version.versionString), or leave the number out.", comment: "kind:fix · What’s New"),
                    tool: fix.tool,
                    arguments: fix.arguments
                )
            ))
        }
        if WhatsNewGenericText.isGeneric(text, appName: appName) {
            risks.append(ReviewRisk(
                check: id,
                subject: "whatsNew.\(locale).generic",
                level: .check,
                title: String(localized: "Generic What’s New · \(language)", comment: "kind:title · an App Review risk"),
                why: String(
                    localized: "Apple asks What’s New to name the changes; only bug fixes may stay generic (2.3.12).",
                    comment: "kind:why · an App Review risk"
                ),
                evidence: [ReviewRiskEvidence(place: place, excerpt: text, locale: locale)],
                howSure: .fairlySure,
                fix: ReviewRiskFix(
                    advice: String(
                        localized: "Name what’s new in version \(version.versionString), unless it only fixes bugs.",
                        comment: "kind:fix · What’s New"
                    ),
                    tool: fix.tool,
                    arguments: fix.arguments
                )
            ))
        }
        return risks
    }
}
