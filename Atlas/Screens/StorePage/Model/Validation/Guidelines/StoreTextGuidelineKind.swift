//
//  StoreTextGuidelineKind.swift
//  Atlas
//

import Foundation

/// What App Review rejects in store text and screenshot captions that can
/// be told from the words alone, with the guideline it breaks and the
/// fields it applies to. SimProps 1.0 was rejected under 2.3.7 for "free
/// to download" and "Try everything free for 7 days" in its description
/// and promotional text, both written by an assistant through Atlas.
nonisolated enum StoreTextGuidelineKind: String, CaseIterable, Hashable, Sendable {
    /// "free" in any language, prices, discounts and trial lengths (2.3.7:
    /// "don't try to pack any of your metadata with … pricing information").
    case pricing
    /// Android, Google Play and other stores (2.3.10).
    case otherPlatform
    /// "#1", "best", "award-winning" in the name or subtitle (2.3.7:
    /// subtitles "should not … make unverifiable product claims").
    case unverifiableClaim
    /// Popular app names in the name, subtitle or keywords (2.3.7, 4.1(c)).
    case otherApp
    /// "beta", "demo version", "early access" (2.2).
    case prerelease
    /// "lorem ipsum", "TODO:", "[insert …]" (2.1(a)).
    case placeholder
    /// "coming soon": metadata describes the app as it is (2.3).
    case comingSoon
    /// "For Kids", "For Children": reserved for the Kids Category (2.3.8,
    /// 5.1.4(b)).
    case kidsTerms
    /// All capitals ("DON'T MISS OUT") and repeated punctuation ("!!"):
    /// Apple asks In-App Event texts and retention messages to avoid them.
    /// Only checked there (`StoreTextGuidelinePlace`).
    case emphasis

    /// The rule's number, e.g. "2.3.7".
    var guideline: String {
        switch self {
        case .pricing, .unverifiableClaim: "2.3.7"
        case .emphasis: "2.3.13"
        case .otherPlatform: "2.3.10"
        case .otherApp: "2.3.7 and 4.1(c)"
        case .prerelease: "2.2"
        case .placeholder: "2.1(a)"
        case .comingSoon: "2.3"
        case .kidsTerms: "2.3.8 and 5.1.4(b)"
        }
    }

    /// "Guideline 2.3.7" or "Guidelines 2.3.8 and 5.1.4(b)".
    var guidelineLabel: String {
        guideline.contains(" and ") ? String(localized: "Guidelines \(guideline)") : String(localized: "Guideline \(guideline)")
    }

    /// What App Review rejects, as a sentence's start the phrases follow.
    var rule: String {
        switch self {
        case .pricing: String(localized: "App Review rejects pricing in store text and screenshots")
        case .otherPlatform: String(localized: "App Review rejects other mobile platforms and app stores in metadata")
        case .unverifiableClaim: String(localized: "App Review rejects claims it can’t verify in the name and subtitle")
        case .otherApp: String(localized: "App Review rejects other apps’ names in the name, subtitle and keywords")
        case .prerelease: String(localized: "App Review rejects betas, demos and trial versions")
        case .placeholder: String(localized: "App Review rejects placeholder text")
        case .comingSoon: String(localized: "App Review rejects metadata promising what the app doesn’t have yet")
        case .kidsTerms: String(localized: "“For Kids” and “For Children” are only for apps in the Kids Category")
        case .emphasis: String(localized: "Apple asks for standard capitalization and punctuation")
        }
    }

    /// How to write it instead, for the assistant.
    var advice: String {
        switch self {
        case .pricing:
            String(localized: """
            The App Store shows the price, trials and offers itself: say what the app or its paid features do instead. \
            Saying a feature needs Pro or an in-app purchase is fine; what it costs, “free”, discounts and trial lengths aren’t.
            """)
        case .otherPlatform:
            String(localized: "Keep it about the app on Apple platforms, without other platforms, their stores or other app marketplaces.")
        case .unverifiableClaim:
            String(localized: "Say what the app does instead of ranking it.")
        case .otherApp:
            String(localized: "Leave other apps’ and brands’ names out of the name, subtitle and keywords; the description can say what the app works with.")
        case .prerelease:
            String(localized: "Betas and demos belong on TestFlight: describe the finished app.")
        case .placeholder:
            String(localized: "Write the final text.")
        case .comingSoon:
            String(localized: "Describe only what this version does; new things go in What’s New when they ship.")
        case .kidsTerms:
            String(localized: "Leave it out unless the app is in the Kids Category.")
        case .emphasis:
            String(localized: "Use standard capitalization and one punctuation mark at a time.")
        }
    }

    /// Whether this kind is checked in a field. URLs never are; claims only
    /// in the name and subtitle, other apps only where they game search
    /// (name, subtitle, keywords), coming soon not in What's New ("more
    /// languages coming soon" is how updates are announced).
    func applies(to field: ListingField) -> Bool {
        guard !field.isURL else { return false }
        switch self {
        case .pricing, .otherPlatform, .prerelease, .placeholder: return true
        case .unverifiableClaim: return field == .name || field == .subtitle
        case .otherApp: return [.name, .subtitle, .keywords].contains(field)
        case .comingSoon: return field != .whatsNew && field != .keywords
        case .kidsTerms: return field != .whatsNew
        case .emphasis: return false
        }
    }

    /// Whether this kind is checked in an in-app purchase's, subscription's
    /// or subscription group's display name and description, shown on the
    /// product page, the purchase sheet and in Settings → Subscriptions.
    /// Claims, other apps and betas are left out there: 2.3.7 names them
    /// for the app's name and subtitle, and "Best Value" or "Early Access"
    /// are ordinary product names.
    func applies(to _: InAppTextField) -> Bool {
        switch self {
        case .pricing, .otherPlatform, .placeholder, .comingSoon, .kidsTerms: true
        case .unverifiableClaim, .otherApp, .prerelease, .emphasis: false
        }
    }

    /// Whether this kind is checked in screenshot captions (2.3.7 names
    /// screenshots for prices, 2.3.10 metadata, 5.1.4(b) screenshots).
    var checksCaptions: Bool {
        switch self {
        case .pricing, .otherPlatform, .prerelease, .placeholder, .comingSoon, .kidsTerms: true
        case .unverifiableClaim, .otherApp, .emphasis: false
        }
    }
}
