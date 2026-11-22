//
//  AppInformationSuggestionField.swift
//  Atlas
//

import Foundation

/// The App Information fields that take suggestions, on General and App
/// Review. Raw values are the names MCP uses (`suggest_fields`). A picked
/// value is kept as App Store Connect's id (`PRODUCTIVITY`,
/// `AFTER_APPROVAL`, `USES_THIRD_PARTY_CONTENT`) and shown by name.
enum AppInformationSuggestionField: String, CaseIterable, Identifiable, Hashable, Sendable {
    case copyright
    case primaryCategory
    case secondaryCategory
    case contentRights
    case release
    case contactFirstName
    case contactLastName
    case contactPhone
    case contactEmail
    case notes

    var id: String { rawValue }

    var page: AppInformationPage {
        switch self {
        case .copyright, .primaryCategory, .secondaryCategory, .contentRights, .release: .general
        case .contactFirstName, .contactLastName, .contactPhone, .contactEmail, .notes: .appReview
        }
    }

    var title: String {
        switch self {
        case .copyright: String(localized: "Copyright")
        case .primaryCategory: String(localized: "Primary Category")
        case .secondaryCategory: String(localized: "Secondary Category")
        case .contentRights: String(localized: "Third-Party Content")
        case .release: String(localized: "Version Release")
        case .contactFirstName, .contactLastName, .contactPhone, .contactEmail, .notes: reviewField?.title ?? rawValue
        }
    }

    /// The App Review field it is, on that page.
    var reviewField: AppReviewField? {
        switch self {
        case .contactFirstName: .firstName
        case .contactLastName: .lastName
        case .contactPhone: .phone
        case .contactEmail: .email
        case .notes: .notes
        case .copyright, .primaryCategory, .secondaryCategory, .contentRights, .release: nil
        }
    }

    /// Set per version (copyright, release, App Review), so a version in
    /// review or live is locked; the categories and content rights belong
    /// to the app.
    var isVersionLevel: Bool {
        ![.primaryCategory, .secondaryCategory, .contentRights].contains(self)
    }

    /// Picked from a list rather than typed.
    var isPicked: Bool {
        [.primaryCategory, .secondaryCategory, .contentRights, .release].contains(self)
    }

    var limit: Int? {
        self == .notes ? AppReviewField.notesLimit : nil
    }

    var isMultiline: Bool { self == .notes }

    /// The suggestion field an App Review field is, if it takes them.
    init?(reviewField: AppReviewField) {
        guard let field = Self.allCases.first(where: { $0.reviewField == reviewField }) else { return nil }
        self = field
    }

    static func fields(on page: AppInformationPage) -> [AppInformationSuggestionField] {
        allCases.filter { $0.page == page }
    }

    /// The pages that take suggestions.
    static let pages: [AppInformationPage] = [.general, .appReview]

    /// What the person reads for a stored value: a category's, release
    /// option's or content rights answer's name, the text otherwise.
    func displayValue(_ value: String) -> String {
        switch self {
        case .primaryCategory, .secondaryCategory: AppCategory.name(for: value.isEmpty ? nil : value)
        case .contentRights: ContentRights(rawValue: value)?.title ?? value
        case .release: ReleaseOption(rawValue: value)?.title ?? value
        default: value
        }
    }

    /// An assistant's value as it's stored: a category, release option or
    /// content rights answer by id or name (Yes or No, or true or false, for
    /// content rights), ignoring case; nil when it's none of them.
    func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .primaryCategory, .secondaryCategory:
            let match = AppCategory.all.first { [$0.id, $0.name].contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame } }
            return match?.id
        case .release:
            let match = ReleaseOption.allCases.first { [$0.rawValue, $0.title].contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame } }
            return match?.rawValue
        case .contentRights:
            return ContentRights.matching(trimmed)?.rawValue
        case .notes:
            return value
        default:
            return trimmed
        }
    }

    /// The field's value in the page's values, as stored.
    func value(general: GeneralValues?, review: AppReviewValues?) -> String {
        switch self {
        case .copyright: general?.copyright ?? ""
        case .primaryCategory: general?.primaryCategory ?? ""
        case .secondaryCategory: general?.secondaryCategory ?? ""
        case .contentRights: general?.contentRights?.rawValue ?? ""
        case .release: general?.release?.rawValue ?? ""
        case .contactFirstName, .contactLastName, .contactPhone, .contactEmail, .notes: reviewField.map { review?.text($0) ?? "" } ?? ""
        }
    }
}
