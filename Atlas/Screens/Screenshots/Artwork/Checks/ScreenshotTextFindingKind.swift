//
//  ScreenshotTextFindingKind.swift
//  Atlas
//

import Foundation

/// What App Review rejects in the text a screenshot shows, read with
/// Vision: the Store Page's rules for captions (`StoreTextGuidelineCheck`)
/// and Apple's recognitions (`ArtworkForbiddenText`), with “free” and
/// offers kept apart from amounts, which are often the app's own content
/// (a budgeting app showing “$4.99”).
enum ScreenshotTextFindingKind: String, CaseIterable, Codable, Hashable, Sendable {
    /// “free” in any language and trial lengths (2.3.7).
    case free
    /// Discounts and offers: “50% off”, “special offer” (2.3.7).
    case offer
    /// A currency amount: “$4.99”, “4,99 €”. A price (2.3.7), unless it's
    /// what the app shows as its content.
    case amount
    /// Android, Google Play and other stores (2.3.10).
    case otherPlatform
    /// “Editors’ Choice”, “App of the Day” and the like (5.2.5, 2.3.7).
    case appleRecognition
    /// “lorem ipsum”, “TODO:” (2.1(a)).
    case placeholder
    /// “beta”, “demo version” (2.2).
    case prerelease
    /// “coming soon” (2.3).
    case comingSoon
    /// “For Kids” outside the Kids Category (2.3.8).
    case kidsTerms

    /// The guideline App Review cites.
    var guideline: String {
        switch self {
        case .free, .offer, .amount: "2.3.7"
        case .otherPlatform: "2.3.10"
        case .appleRecognition: "5.2.5"
        case .placeholder: "2.1(a)"
        case .prerelease: "2.2"
        case .comingSoon: "2.3"
        case .kidsTerms: "2.3.8"
        }
    }

    /// The Store Page's rule it is, for its wording; nil for Apple's
    /// recognitions, which store texts don't check.
    var storeTextKind: StoreTextGuidelineKind? {
        switch self {
        case .free, .offer, .amount: .pricing
        case .otherPlatform: .otherPlatform
        case .placeholder: .placeholder
        case .prerelease: .prerelease
        case .comingSoon: .comingSoon
        case .kidsTerms: .kidsTerms
        case .appleRecognition: nil
        }
    }

    /// A screenshot an assistant sends with it is refused. Amounts aren't:
    /// they're often the app's own content. Betas, “coming soon” and “For
    /// Kids” can be too (a “Beta features” switch, a “Books for kids” shelf).
    var refusesFile: Bool {
        switch self {
        case .free, .offer, .otherPlatform, .appleRecognition, .placeholder: true
        case .amount, .prerelease, .comingSoon, .kidsTerms: false
        }
    }

    /// What App Review rejects, as a sentence's start: "App Review rejects
    /// pricing in store text and screenshots".
    var rule: String {
        storeTextKind?.rule
            ?? String(localized: "Apple’s awards and recognitions can’t appear in screenshots", comment: "kind:error · App Review rule")
    }

    /// "Guideline 2.3.7".
    var guidelineLabel: String {
        String(localized: "Guideline \(guideline)", comment: "kind:error · names an App Review guideline")
    }
}
