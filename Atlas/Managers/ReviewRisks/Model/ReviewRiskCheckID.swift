//
//  ReviewRiskCheckID.swift
//  Atlas
//

import Foundation

/// Every check Atlas runs for App Review risks, in the order the list
/// shows a tie: what blocks App Review, then money, then reach. Each one
/// names its guideline and where the person fixes it.
enum ReviewRiskCheckID: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    /// 3.1.2(c): an auto-renewable subscription needs Terms of Use (EULA)
    /// and Privacy Policy links in the metadata.
    case subscriptionTerms
    /// 2.1: a new subscription or in-app purchase that isn't submitted with
    /// the version, or misses its review screenshot or texts.
    case inAppProducts
    /// 5.1.1(i), 1.5: the Privacy Policy, Support and Terms URLs exist and
    /// open.
    case links
    /// Store texts already pushed or waiting in Review & Push, in every
    /// language and place, checked with `StoreTextGuidelineCheck`.
    case storeTexts
    /// 2.3.6: the age rating answers against what the store texts say.
    case ageRating
    /// 1.2: apps with user content or chat need filtering, reporting,
    /// blocking and contact details.
    case userContent
    /// 2.3.12: What's New that is empty, generic, or about another version.
    case whatsNew
    /// 5.1.1(v): an app with accounts must let people delete them in the app.
    case accountDeletion
    /// 4.8: third-party sign-in needs Sign in with Apple (or an equivalent).
    case signInWithApple
    /// 5.1.1(ii): permission texts (purpose strings) that are missing,
    /// generic or not translated.
    case purposeStrings
    /// 2.3.7, 2.3.10: text read in the screenshots (prices, other platforms).
    case screenshotText
    /// 5.2.5, 2.3.7: Apple's trademarks, and names stuffed with keywords.
    case trademarksAndNames
    /// 3.1.1, 3.1.3: texts that send people to pay outside the App Store
    /// (outside the United States).
    case payElsewhere
    /// 4.3: the person's own apps with nearly the same store texts.
    case similarApps
    /// China mainland's Security Assessment: features that need one
    /// (sharing with others, chat, live streams, news, AI content shared).
    case chinaSecurityAssessment
    /// China mainland's AI-generated or synthetic content declaration and
    /// its CAC filing.
    case chinaAIContent

    var id: String { rawValue }

    /// The guideline as App Review cites it.
    var guideline: String {
        switch self {
        case .subscriptionTerms: "3.1.2(c)"
        case .inAppProducts: "2.1(b)"
        case .links: "5.1.1(i)"
        case .storeTexts: "2.3"
        case .ageRating: "2.3.6"
        case .userContent: "1.2"
        case .whatsNew: "2.3.12"
        case .accountDeletion: "5.1.1(v)"
        case .signInWithApple: "4.8"
        case .purposeStrings: "5.1.1(ii)"
        case .screenshotText: "2.3.7"
        case .trademarksAndNames: "5.2.5"
        case .payElsewhere: "3.1.1"
        case .similarApps: "4.3"
        case .chinaSecurityAssessment: "China mainland: Security Assessment"
        case .chinaAIContent: "China mainland: AI-generated or synthetic content"
        }
    }

    /// The check's name in lists: "Subscription terms".
    var name: String {
        switch self {
        case .subscriptionTerms: String(localized: "Subscription terms", comment: "kind:label · an App Review check")
        case .inAppProducts: String(localized: "In-app purchases for review", comment: "kind:label · an App Review check")
        case .links: String(localized: "Privacy and support links", comment: "kind:label · an App Review check")
        case .storeTexts: String(localized: "Store texts", comment: "kind:label · an App Review check")
        case .ageRating: String(localized: "Age rating", comment: "kind:label · an App Review check")
        case .userContent: String(localized: "User content safety", comment: "kind:label · an App Review check")
        case .whatsNew: String(localized: "What’s New", comment: "kind:label · an App Review check")
        case .accountDeletion: String(localized: "Account deletion", comment: "kind:label · an App Review check")
        case .signInWithApple: String(localized: "Sign in with Apple", comment: "kind:label · an App Review check")
        case .purposeStrings: String(localized: "Permission texts", comment: "kind:label · an App Review check")
        case .screenshotText: String(localized: "Text in screenshots", comment: "kind:label · an App Review check")
        case .trademarksAndNames: String(localized: "Trademarks and app name", comment: "kind:label · an App Review check")
        case .payElsewhere: String(localized: "Paying outside the App Store", comment: "kind:label · an App Review check")
        case .similarApps: String(localized: "Similar apps", comment: "kind:label · an App Review check")
        case .chinaSecurityAssessment: String(localized: "Security Assessment · China mainland", comment: "kind:label · an App Review check")
        case .chinaAIContent: String(localized: "AI content · China mainland", comment: "kind:label · an App Review check")
        }
    }

    /// Where the person fixes what it finds.
    var section: AppWorkspaceSection {
        switch self {
        case .subscriptionTerms, .storeTexts, .whatsNew, .trademarksAndNames, .payElsewhere, .similarApps: .storePage
        case .inAppProducts: .subscriptionPricing
        case .links, .ageRating, .userContent, .accountDeletion, .signInWithApple, .purposeStrings: .appInformation
        case .chinaSecurityAssessment, .chinaAIContent: .appInformation
        case .screenshotText: .screenshots
        }
    }

    /// Needs the app's Xcode project folder (or an assistant reading it):
    /// without one it goes to `notChecked`.
    var needsProject: Bool {
        switch self {
        case .accountDeletion, .signInWithApple, .purposeStrings: true
        default: false
        }
    }

    /// The name sent over MCP.
    var mcpName: String { rawValue }
}
