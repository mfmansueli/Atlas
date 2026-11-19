//
//  StoreTextGuidelinePlace.swift
//  Atlas
//

import Foundation

/// A text outside the store listing that follows its own page of Apple's
/// rules, so `StoreTextGuidelineCheck` looks for other things there and
/// names that page:
/// - In-App Event texts: Apple's In-App Events guidance and 2.3.13 reject
///   specific prices, ask to avoid unverifiable claims, all capitals and
///   repeated punctuation; "free" is allowed (a free weekend is an event).
/// - Retention messages: App Store Connect's content guidelines reject
///   offers, discounts and prices ("one month free") and discourage
///   unverifiable claims; announcing upcoming content is allowed.
/// - Review replies: 5.6.1 asks for no personal information, spam or
///   marketing; "feel free to contact us" and a support answer about a free
///   trial are fine.
nonisolated enum StoreTextGuidelinePlace: String, Hashable, Sendable, CaseIterable {
    case eventText
    case retentionMessage
    case reviewReply

    /// What's checked here, in `StoreTextGuidelineKind`'s order.
    var kinds: [StoreTextGuidelineKind] {
        switch self {
        case .eventText: [.pricing, .otherPlatform, .unverifiableClaim, .placeholder, .kidsTerms, .emphasis]
        case .retentionMessage: [.pricing, .otherPlatform, .unverifiableClaim, .placeholder, .kidsTerms, .emphasis]
        case .reviewReply: [.pricing, .placeholder]
        }
    }

    /// The rule's source, e.g. "2.3.13".
    func guideline(for kind: StoreTextGuidelineKind) -> String {
        switch (self, kind) {
        case (_, .otherPlatform): "2.3.10"
        case (_, .kidsTerms): "2.3.8"
        case (.eventText, .placeholder), (.retentionMessage, .placeholder): "2.1(a)"
        case (.eventText, _): "2.3.13"
        case (.retentionMessage, _): String(localized: "retention message guidelines")
        case (.reviewReply, _): "5.6.1"
        }
    }

    /// "Guideline 2.3.13", or "App Store Connect’s retention message
    /// guidelines", which have no number.
    func guidelineLabel(for kind: StoreTextGuidelineKind) -> String {
        if self == .retentionMessage, ![.otherPlatform, .kidsTerms, .placeholder].contains(kind) {
            return String(localized: "App Store Connect’s retention message guidelines")
        }
        return String(localized: "Guideline \(guideline(for: kind))")
    }

    /// What Apple rejects or asks, as a sentence's start the phrases follow.
    func rule(for kind: StoreTextGuidelineKind) -> String {
        switch (self, kind) {
        case (.eventText, .pricing): String(localized: "App Review rejects specific prices in In-App Event texts")
        case (.eventText, .unverifiableClaim): String(localized: "Apple asks In-App Event texts to avoid claims it can’t verify")
        case (.eventText, .emphasis): String(localized: "Apple asks In-App Event texts to avoid all capitals and repeated punctuation")
        case (.retentionMessage, .pricing): String(localized: "App Review rejects offers, discounts and prices in retention messages")
        case (.retentionMessage, .unverifiableClaim): String(localized: "Apple strongly discourages unverifiable claims in retention messages")
        case (.retentionMessage, .emphasis): String(localized: "Apple asks retention messages to avoid all capitals and repeated exclamation marks")
        case (.reviewReply, .pricing): String(localized: "Replies to reviews can’t include marketing")
        case (.reviewReply, .placeholder): String(localized: "A reply with placeholder text isn’t written to the reviewer")
        default: kind.rule
        }
    }

    /// How to write it instead, for the assistant.
    func advice(for kind: StoreTextGuidelineKind) -> String {
        switch (self, kind) {
        case (.eventText, .pricing):
            String(localized: """
            Prices and currencies vary by region and can change apart from the event: say what happens in the event \
            instead. Whether it needs an in-app purchase is the event's purchase requirement, not its text.
            """)
        case (.eventText, .unverifiableClaim):
            String(localized: "Say what happens in the event instead of ranking it.")
        case (.eventText, .emphasis):
            String(localized: "Write the name in title case and the descriptions in sentence case, with one punctuation mark at a time.")
        case (.retentionMessage, .pricing):
            String(localized: """
            Every subscriber sees it, also those an offer isn't for: say what they keep by staying. What they lose by \
            canceling is fine when it's factual; offers are set as retention offers, not in the text.
            """)
        case (.retentionMessage, .unverifiableClaim):
            String(localized: "Say what the subscription gives instead, without superlatives or statistics you can't support.")
        case (.retentionMessage, .emphasis):
            String(localized: "Use standard capitalization and one punctuation mark at a time.")
        case (.reviewReply, .pricing):
            String(localized: "Keep the reply to what the reviewer wrote, without prices, discounts or promo codes.")
        case (.reviewReply, .placeholder):
            String(localized: "Write the whole reply, with no brackets or fields left to fill in.")
        default:
            kind.advice
        }
    }

    /// One paragraph for the tools and prompts that write these texts.
    var summary: String {
        switch self {
        case .eventText:
            String(localized: """
            In-App Event texts follow Apple's In-App Events guidance (Guideline 2.3.13): no specific prices or \
            discounts (App Review rejects them; whether the event needs a purchase is its purchase requirement), \
            no claims that can't be verified such as “the best” or “#1”, no all capitals or repeated punctuation, no \
            other platforms (2.3.10), no placeholder text (2.1) and “For Kids” only in the Kids Category (2.3.8). The \
            name is the event's real name in title case, not a call to action or the event type; the descriptions \
            are in sentence case and about the event, not the app in general. A text that breaks a rule is refused \
            with the reason.
            """)
        case .retentionMessage:
            String(localized: """
            Retention messages follow App Store Connect's content guidelines: no offers, discounts or prices such as \
            “$9.99”, “50% off” or “one month free” (App Review rejects them: every subscriber sees the message), no \
            unverifiable claims or statistics such as “the best app” or “92% of parents”, nothing coercive, no all \
            capitals or repeated exclamation marks, no other platforms (2.3.10) and no placeholder text (2.1). What a \
            subscriber loses by canceling is fine when it's factual, and so is announcing upcoming content. A text \
            that breaks a rule is refused with the reason.
            """)
        case .reviewReply:
            String(localized: """
            Replies follow Guideline 5.6.1: respectful, about what the reviewer wrote, with no personal information, \
            spam or marketing (no prices, discounts or promo codes) and no placeholder text. A reply that breaks one is \
            skipped with the reason.
            """)
        }
    }

    /// The rules as tool results carry them (`textRules`).
    var rules: [String] {
        switch self {
        case .eventText:
            [
                """
                2.3.13 and Apple's In-App Events guidance: metadata is accurate and about the event itself, not the \
                app more generally; don't use the description to promote the app or its services.
                """,
                """
                No specific prices: “Including specific pricing will lead to rejection by App Review.” Whether the \
                event needs an in-app purchase is set as its purchase requirement.
                """,
                """
                Event name: the event's actual name, up to 30 characters, in title case; not a call to action or \
                tagline, not generic terms or the event type (the badge shows it). Short (≤50) and long (≤120) \
                descriptions in sentence case.
                """,
                "No claims that can't be verified (“the best”, “#1”) or extra words such as “game event”; no all capitals or repeated punctuation.",
                "2.3.10, 2.1(a) and 2.3.8: no other platforms, no placeholder text, “For Kids” only in the Kids Category.",
            ]
        case .retentionMessage:
            [
                """
                No promotional offers, discounts or specific prices (“$9.99”, “50% off”, “one month free”): every \
                subscriber sees the text, also those an offer isn't for, and App Review rejects it.
                """,
                """
                Factual losses are fine (“You'll lose access to downloaded content when your subscription ends”), and \
                so are key features and upcoming content.
                """,
                "No coercive claims or unverifiable outcomes, superlatives or statistics (“the best app”, “92% of parents…”).",
                "Standard capitalization and punctuation: no all capitals or repeated exclamation marks.",
            ]
        case .reviewReply:
            [
                "5.6.1: treat the reviewer with respect and keep the reply to what they wrote.",
                "No personal information, spam or marketing: no prices, discounts, promo codes or other apps to download.",
                """
                Billing and download problems go to Apple Support; never ask for a better rating, and never promise \
                what isn't there.
                """,
            ]
        }
    }

    var rulesJSON: JSONValue {
        .array(rules.map(JSONValue.string))
    }
}
