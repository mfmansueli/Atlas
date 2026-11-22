//
//  SuggestionPage.swift
//  Atlas
//

import Foundation

/// The places suggestions show, as Overview counts them and Suggest
/// Everything lists them: the Store Page, then App Information's General,
/// Age Rating, Accessibility and App Review (`fieldPages`), then App
/// Compliance and Export Compliance, whose answers a run plans and counts
/// but which wait on their own pages rather than as field suggestions.
enum SuggestionPage: String, CaseIterable, Identifiable, Hashable, Sendable {
    case storePage
    case general
    case ageRating
    case accessibility
    case appReview
    case appCompliance
    case exportCompliance

    /// The pages field suggestions show on, as Overview's Suggestions card
    /// counts them.
    static let fieldPages: [SuggestionPage] = [.storePage, .general, .ageRating, .accessibility, .appReview]

    var id: String { rawValue }

    init?(_ scope: SuggestionScope) {
        switch scope {
        case .storePage: self = .storePage
        case .accessibility: self = .accessibility
        case .appInformation:
            switch scope.page {
            case .general: self = .general
            case .ageRating: self = .ageRating
            case .appReview: self = .appReview
            case .appCompliance: self = .appCompliance
            case .exportCompliance: self = .exportCompliance
            default: return nil
            }
        }
    }

    var title: String {
        switch self {
        case .storePage: String(localized: "Store Page")
        case .general, .ageRating, .accessibility, .appReview, .appCompliance, .exportCompliance: appInformationPage?.title ?? rawValue
        }
    }

    /// The App Information page it is; nil for the Store Page.
    var appInformationPage: AppInformationPage? {
        switch self {
        case .storePage: nil
        case .general: .general
        case .ageRating: .ageRating
        case .accessibility: .accessibility
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
        case .appInformation, .accessibility: AppInformationSuggestionSlot(target: target)?.title ?? target.field
        }
    }
}
