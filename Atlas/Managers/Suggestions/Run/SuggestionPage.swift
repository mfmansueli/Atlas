//
//  SuggestionPage.swift
//  Atlas
//

import Foundation

/// The places suggestions show, as Overview counts them and Suggest
/// Everything lists them: the Store Page, then App Information's General,
/// Age Rating, Accessibility, App Privacy (its User Privacy Choices URLs)
/// and App Review (`fieldPages`), then App Compliance and Export
/// Compliance, whose answers a run plans and counts but which wait on their
/// own pages rather than as field suggestions.
enum SuggestionPage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case storePage
    case general
    case ageRating
    case accessibility
    case appPrivacy
    case appReview
    case appCompliance
    case exportCompliance

    /// The pages field suggestions show on, as Overview's Suggestions card
    /// counts them.
    static let fieldPages: [SuggestionPage] = [.storePage, .general, .ageRating, .accessibility, .appPrivacy, .appReview]

    var id: String { rawValue }

    /// The page a scope is on: Accessibility's devices and its URL are
    /// Accessibility, App Privacy's languages App Privacy.
    init?(_ scope: SuggestionScope) {
        guard let page = scope.page else {
            self = .storePage
            return
        }
        guard let match = Self.allCases.first(where: { $0.appInformationPage == page }) else { return nil }
        self = match
    }

    var title: String {
        switch self {
        case .storePage: String(localized: "Store Page")
        case .general, .ageRating, .accessibility, .appPrivacy, .appReview, .appCompliance, .exportCompliance: appInformationPage?.title ?? rawValue
        }
    }

    /// The App Information page it is; nil for the Store Page.
    var appInformationPage: AppInformationPage? {
        switch self {
        case .storePage: nil
        case .general: .general
        case .ageRating: .ageRating
        case .accessibility: .accessibility
        case .appPrivacy: .appPrivacy
        case .appReview: .appReview
        case .appCompliance: .appCompliance
        case .exportCompliance: .exportCompliance
        }
    }

    var area: SuggestionArea {
        self == .storePage ? .storePage : .appInformation
    }

    /// A target's name in a run's rows: "Subtitle", "Secondary Category",
    /// "Health or Wellness Topics", "VoiceOver", "ICP Filing Number".
    static func fieldTitle(of target: SuggestionTarget) -> String {
        switch target.scope.page {
        case .appCompliance?: return ComplianceRule(rawValue: target.field)?.name ?? target.field
        case .exportCompliance?: return String(localized: "Encryption")
        default: break
        }
        return switch target.scope {
        case .storePage: ListingField(rawValue: target.field)?.title ?? target.field
        case .appInformation, .accessibility, .appPrivacy: AppInformationSuggestionSlot(target: target)?.title ?? target.field
        }
    }
}
