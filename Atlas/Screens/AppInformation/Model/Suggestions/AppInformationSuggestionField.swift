//
//  AppInformationSuggestionField.swift
//  Atlas
//

import Foundation

/// The App Information fields that take suggestions, on General, App
/// Review and Accessibility (its URL; its features are slots of their
/// own). Raw values are the names MCP uses (`suggest_fields`), App Store
/// Connect's attribute names. A picked value is kept as App Store Connect's
/// id (`PRODUCTIVITY`, `AFTER_APPROVAL`, `USES_THIRD_PARTY_CONTENT`; Games
/// subcategories comma-separated; sign-in required as `yes` or `no`) and
/// shown by name. The demo account's password is never one: it stays out
/// of suggestions and MCP.
enum AppInformationSuggestionField: String, CaseIterable, Identifiable, Hashable, Sendable {
    case copyright
    case primaryCategory
    case secondaryCategory
    /// Up to two, only while the primary category is Games.
    case gamesSubcategories
    case contentRights
    case release
    case contactFirstName
    case contactLastName
    case contactPhone
    case contactEmail
    /// Sign-in required: whether App Review needs a demo account.
    case demoAccountRequired
    /// The demo account's user name.
    case demoAccountName
    case notes
    /// The app's accessibility URL, one for every device.
    case accessibilityURL = "accessibilityUrl"

    var id: String { rawValue }

    var page: AppInformationPage {
        switch self {
        case .copyright, .primaryCategory, .secondaryCategory, .gamesSubcategories, .contentRights, .release: .general
        case .contactFirstName, .contactLastName, .contactPhone, .contactEmail, .demoAccountRequired, .demoAccountName, .notes: .appReview
        case .accessibilityURL: .accessibility
        }
    }

    var title: String {
        switch self {
        case .copyright: String(localized: "Copyright")
        case .primaryCategory: String(localized: "Primary Category")
        case .secondaryCategory: String(localized: "Secondary Category")
        case .gamesSubcategories: String(localized: "Games Subcategories")
        case .contentRights: String(localized: "Third-Party Content")
        case .release: String(localized: "Version Release")
        case .accessibilityURL: String(localized: "Accessibility URL")
        case .contactFirstName, .contactLastName, .contactPhone, .contactEmail, .demoAccountRequired, .demoAccountName, .notes:
            reviewField?.title ?? rawValue
        }
    }

    /// The App Review field it is, on that page.
    var reviewField: AppReviewField? {
        switch self {
        case .contactFirstName: .firstName
        case .contactLastName: .lastName
        case .contactPhone: .phone
        case .contactEmail: .email
        case .demoAccountRequired: .signInRequired
        case .demoAccountName: .userName
        case .notes: .notes
        case .copyright, .primaryCategory, .secondaryCategory, .gamesSubcategories, .contentRights, .release, .accessibilityURL: nil
        }
    }

    /// Set per version (copyright, release, App Review), so a version in
    /// review or live is locked; the categories, content rights and the
    /// accessibility URL belong to the app.
    var isVersionLevel: Bool {
        ![.primaryCategory, .secondaryCategory, .gamesSubcategories, .contentRights, .accessibilityURL].contains(self)
    }

    /// Picked from a list rather than typed.
    var isPicked: Bool {
        [.primaryCategory, .secondaryCategory, .gamesSubcategories, .contentRights, .release, .demoAccountRequired].contains(self)
    }

    var isURL: Bool { self == .accessibilityURL }

    var limit: Int? {
        self == .notes ? AppReviewField.notesLimit : nil
    }

    var isMultiline: Bool { self == .notes }

    /// Other names an assistant may use for it: the App Review page's own.
    var aliases: [String] {
        switch self {
        case .demoAccountRequired: ["signInRequired"]
        case .demoAccountName: ["userName", "demoAccountUserName"]
        default: []
        }
    }

    /// Whether an assistant's `name` means this field: its raw value or an
    /// alias, ignoring case.
    func isNamed(_ name: String) -> Bool {
        ([rawValue] + aliases).contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// The suggestion field an App Review field is, if it takes them.
    init?(reviewField: AppReviewField) {
        guard let field = Self.allCases.first(where: { $0.reviewField == reviewField }) else { return nil }
        self = field
    }

    static func fields(on page: AppInformationPage) -> [AppInformationSuggestionField] {
        allCases.filter { $0.page == page }
    }

    /// The pages whose fields `get_app_information` lists together
    /// (Accessibility's URL is listed with its devices).
    static let pages: [AppInformationPage] = [.general, .appReview]

    /// Sign-in required's stored answers.
    static let yesAnswer = "yes"
    static let noAnswer = "no"

    /// What the person reads for a stored value: a category's, release
    /// option's or content rights answer's name, the text otherwise.
    func displayValue(_ value: String) -> String {
        switch self {
        case .primaryCategory, .secondaryCategory: AppCategory.name(for: value.isEmpty ? nil : value)
        case .gamesSubcategories: Self.subcategoryNames(value)
        case .contentRights: ContentRights(rawValue: value)?.title ?? value
        case .release: ReleaseOption(rawValue: value)?.title ?? value
        case .demoAccountRequired: Self.answerName(value)
        default: value
        }
    }

    /// "Puzzle, Word", or "None".
    private static func subcategoryNames(_ value: String) -> String {
        let ids = subcategoryIDs(value)
        guard !ids.isEmpty else { return String(localized: "None") }
        return ids.map { AppCategory.name(for: $0) }.joined(separator: ", ")
    }

    /// Sign-in required's answer as the person reads it.
    private static func answerName(_ value: String) -> String {
        if value == yesAnswer { return String(localized: "Yes") }
        return String(localized: "No")
    }

    /// The Games subcategory IDs a stored value holds, in order.
    static func subcategoryIDs(_ value: String) -> [String] {
        value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// An assistant's value as it's stored: a category, release option or
    /// content rights answer by id or name (Yes or No, or true or false, for
    /// content rights and sign-in required), ignoring case; nil when it's
    /// none of them.
    func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .primaryCategory, .secondaryCategory:
            let match = AppCategory.all.first { [$0.id, $0.name].contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame } }
            return match?.id
        case .gamesSubcategories:
            return Self.normalizedSubcategories(trimmed)
        case .release:
            let match = ReleaseOption.allCases.first { [$0.rawValue, $0.title].contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame } }
            return match?.rawValue
        case .contentRights:
            return ContentRights.matching(trimmed)?.rawValue
        case .demoAccountRequired:
            let answers = ["yes": Self.yesAnswer, "true": Self.yesAnswer, "no": Self.noAnswer, "false": Self.noAnswer]
            return answers[trimmed.lowercased()]
        case .notes:
            return value
        default:
            return trimmed
        }
    }

    /// Games subcategories by id (`GAMES_PUZZLE`), by name (`Puzzle`) or by
    /// the id without `GAMES_`, comma-separated, as stored: at most two,
    /// once each. "" clears them; nil when one isn't a Games subcategory or
    /// there are more than two.
    private static func normalizedSubcategories(_ value: String) -> String? {
        var ids: [String] = []
        for name in subcategoryIDs(value.replacingOccurrences(of: ";", with: ",")) {
            let match = AppCategory.gamesSubcategories.first { category in
                [category.id, category.name, String(category.id.dropFirst("GAMES_".count))].contains {
                    $0.caseInsensitiveCompare(name) == .orderedSame
                }
            }
            guard let match else { return nil }
            if !ids.contains(match.id) { ids.append(match.id) }
        }
        return ids.count <= 2 ? ids.joined(separator: ",") : nil
    }

    /// The field's value in the page's values, as stored. The
    /// accessibility URL isn't in them: `AppInformationSlotValues` reads it.
    func value(general: GeneralValues?, review: AppReviewValues?) -> String {
        switch self {
        case .copyright: general?.copyright ?? ""
        case .primaryCategory: general?.primaryCategory ?? ""
        case .secondaryCategory: general?.secondaryCategory ?? ""
        case .gamesSubcategories: general?.gamesSubcategories.joined(separator: ",") ?? ""
        case .contentRights: general?.contentRights?.rawValue ?? ""
        case .release: general?.release?.rawValue ?? ""
        case .demoAccountRequired: review.map { $0.signInRequired ? Self.yesAnswer : Self.noAnswer } ?? ""
        case .contactFirstName, .contactLastName, .contactPhone, .contactEmail, .demoAccountName, .notes:
            reviewField.map { review?.text($0) ?? "" } ?? ""
        case .accessibilityURL: ""
        }
    }
}
