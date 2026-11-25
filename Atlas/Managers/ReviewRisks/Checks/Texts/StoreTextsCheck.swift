//
//  StoreTextsCheck.swift
//  Atlas
//

import Foundation

/// Store texts pushed or waiting in Review & Push, in every language and
/// place, checked with `StoreTextGuidelineCheck` the way a proposal is:
/// one risk per text and rule broken, so the same rule in twelve languages
/// is twelve risks (the list groups them). Pricing, other platforms,
/// placeholders and betas in the name, subtitle, keywords, description or
/// promotional text are a common rejection (Likely); the rest is worth a
/// look (Check). App Review's notes are left out: they may name a trial or
/// a guideline.
struct StoreTextsCheck: ReviewRiskCheck {
    let id = ReviewRiskCheckID.storeTexts

    func run(_ facts: ReviewRiskFacts) -> ReviewRiskOutcome {
        guard let texts = facts.texts else {
            return .notChecked(facts.gap(for: id, fallback: String(localized: "Atlas couldn’t read the store texts.", comment: "kind:error")))
        }
        return .risks(texts.texts.flatMap { text in
            Self.issues(in: text, allowance: texts.allowance).map { risk(for: $0, in: text) }
        })
    }

    /// What App Review would reject in `text`, by the rules of its place,
    /// without what the app may say.
    static func issues(in text: ReviewRiskText, allowance: StoreTextGuidelineAllowance) -> [StoreTextGuidelineIssue] {
        let found: [StoreTextGuidelineIssue] = switch text.place {
        case .storeListing: text.field.map { StoreTextGuidelineCheck.issues(in: text.text, for: $0) } ?? []
        case .inAppText: text.inAppField.map { StoreTextGuidelineCheck.issues(in: text.text, for: $0) } ?? []
        case .caption: StoreTextGuidelineCheck.issues(inCaption: text.text)
        case .eventText: StoreTextGuidelineCheck.issues(in: text.text, for: StoreTextGuidelinePlace.eventText)
        case .productPage: StoreTextGuidelineCheck.issues(in: text.text, for: ListingField.promotionalText)
        case .reviewNotes: []
        }
        return allowance.allowed(found, in: text.place == .storeListing ? text.field : nil)
    }

    private func risk(for issue: StoreTextGuidelineIssue, in text: ReviewRiskText) -> ReviewRisk {
        ReviewRisk(
            check: id,
            subject: "\(text.key).\(issue.kind.rawValue)",
            guideline: issue.place?.guideline(for: issue.kind) ?? issue.kind.guideline,
            level: Self.level(of: issue.kind, in: text),
            title: Self.title(issue.kind, place: text.label),
            why: Self.why(issue),
            evidence: issue.phrases.prefix(3).map { phrase in
                ReviewRiskEvidence(place: text.label, excerpt: ReviewRiskTextExcerpt.around(phrase, in: text.text), locale: text.locale)
            },
            howSure: Self.howSure(issue.kind),
            fix: Self.fix(issue, text: text)
        )
    }

    /// The fields App Review reads first, where these rules reject most.
    private static let mainFields: Set<ListingField> = [.name, .subtitle, .keywords, .description, .promotionalText]

    static func level(of kind: StoreTextGuidelineKind, in text: ReviewRiskText) -> ReviewRiskLevel {
        let common: Set<StoreTextGuidelineKind> = [.pricing, .otherPlatform, .placeholder, .prerelease]
        guard text.place == .storeListing, let field = text.field, mainFields.contains(field), common.contains(kind) else { return .check }
        return .likely
    }

    /// Words that can only mean one thing are sure; "free" or "best" can
    /// still be something else now and then.
    static func howSure(_ kind: StoreTextGuidelineKind) -> HowSure {
        switch kind {
        case .otherPlatform, .placeholder: .sure
        case .pricing, .unverifiableClaim, .otherApp, .prerelease, .comingSoon, .kidsTerms: .fairlySure
        case .emphasis: .notVerySure
        }
    }

    /// "Pricing in Description · German": what, then where.
    static func title(_ kind: StoreTextGuidelineKind, place: String) -> String {
        switch kind {
        case .pricing: String(localized: "Pricing in \(place)", comment: "kind:title · an App Review risk; the place is e.g. Description · German")
        case .otherPlatform: String(localized: "Another platform in \(place)", comment: "kind:title · an App Review risk")
        case .unverifiableClaim: String(localized: "Unverifiable claim in \(place)", comment: "kind:title · an App Review risk")
        case .otherApp: String(localized: "Another app’s name in \(place)", comment: "kind:title · an App Review risk")
        case .prerelease: String(localized: "Beta or demo wording in \(place)", comment: "kind:title · an App Review risk")
        case .placeholder: String(localized: "Placeholder text in \(place)", comment: "kind:title · an App Review risk")
        case .comingSoon: String(localized: "“Coming soon” in \(place)", comment: "kind:title · an App Review risk")
        case .kidsTerms: String(localized: "“For Kids” in \(place)", comment: "kind:title · an App Review risk")
        case .emphasis: String(localized: "All capitals or “!!” in \(place)", comment: "kind:title · an App Review risk")
        }
    }

    /// "App Review rejects pricing in store text and screenshots (Guideline 2.3.7)."
    static func why(_ issue: StoreTextGuidelineIssue) -> String {
        let rule = issue.place?.rule(for: issue.kind) ?? issue.kind.rule
        let label = issue.place?.guidelineLabel(for: issue.kind) ?? issue.kind.guidelineLabel
        return String(localized: "\(rule) (\(label)).", comment: "kind:why · an App Review risk: the rule and its guideline")
    }

    /// The rule's advice, and the tool that rewrites the text in its place.
    static func fix(_ issue: StoreTextGuidelineIssue, text: ReviewRiskText) -> ReviewRiskFix {
        let advice = issue.place?.advice(for: issue.kind) ?? issue.kind.advice
        return switch text.place {
        case .storeListing:
            ReviewRiskFix(advice: advice, tool: "propose_listing_text", arguments: ["field": text.field?.rawValue ?? "", "locale": text.locale])
        case .inAppText:
            ReviewRiskFix(advice: advice, tool: "propose_in_app_texts", arguments: ["column": text.owner ?? "", "locale": text.locale])
        case .caption:
            ReviewRiskFix(advice: advice, tool: "propose_captions", arguments: ["slot": text.owner ?? "", "locale": text.locale])
        case .eventText:
            ReviewRiskFix(advice: advice, tool: "propose_event_texts", arguments: ["eventId": text.owner ?? "", "locale": text.locale])
        case .productPage:
            ReviewRiskFix(advice: advice, tool: "propose_product_page_texts", arguments: ["pageId": text.owner ?? "", "locale": text.locale])
        case .reviewNotes:
            ReviewRiskFix(advice: advice, tool: "suggest_fields", arguments: ["page": "appReview", "field": "notes"])
        }
    }
}
