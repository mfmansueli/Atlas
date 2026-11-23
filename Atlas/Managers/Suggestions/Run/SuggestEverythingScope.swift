//
//  SuggestEverythingScope.swift
//  Atlas
//

import Foundation

/// What Suggest Everything covers for one app, as the waiting popover's
/// What It Covers lists it and the copied prompt asks for it: each page
/// with what the assistant may suggest there, or that it's locked while
/// the version is in review. Built from the Store Page and App Information
/// as an assistant sees them; a page that couldn't be read isn't listed.
struct SuggestEverythingScope: Hashable, Sendable {
    struct Row: Hashable, Sendable, Identifiable {
        var page: SuggestionPage
        /// "Every field in English (U.S.), German and Japanese", or
        /// "Locked while 1.4 is in review".
        var detail: String
        var isLocked = false
        var id: SuggestionPage { page }
    }

    var appName: String
    /// "1.4"; nil when the app has no version.
    var versionString: String?
    var rows: [Row] = []
    /// Languages the app supports that aren't on the App Store yet.
    private(set) var newLanguages: [StoreLocale] = []
    /// Part of it is locked: the prompt asks only for `openParts`.
    private var isRestricted = false
    /// "while it’s in review", for the prompt.
    private var lockedWhile = ""
    /// What the assistant may still suggest, e.g. "Promotional Text in
    /// every language".
    private var openParts: [String] = []
    /// What It Covers' In-App Texts line, e.g. "12 missing: group name,
    /// subscription and in-app purchase texts"; nil when the app sells
    /// nothing (or they couldn't be read). Not locked by the version.
    private(set) var inAppTextsDetail: String?
    /// What It Covers' App Compliance line, e.g. "Digital Services Act and
    /// ICP Filing Number"; nil when it wasn't read or asks nothing.
    private(set) var complianceDetail: String?
    /// The build's export compliance is part of it.
    private(set) var coversExportCompliance = false

    /// Before anything is read: the prompt asks for everything.
    init(appName: String, versionString: String?) {
        self.appName = appName
        self.versionString = versionString
    }

    /// `newLanguages` are the languages the app's project has and its App
    /// Store page doesn't: their new pages are part of the Store Page.
    init(
        appName: String,
        listing: StoreListing?,
        information: AppInformationSlotValues?,
        newLanguages: [StoreLocale] = [],
        inAppTextsMissing: Int? = nil,
        compliance: ComplianceReport? = nil
    ) {
        let version = listing?.version.versionString ?? information?.content.version?.versionString
        self.init(appName: appName, versionString: version)
        self.newLanguages = newLanguages
        let isLive = listing?.version.state.isLive ?? information?.content.version?.state.isLive ?? false
        let locked = isLive
            ? String(localized: "Locked while \(version ?? "") is on the App Store")
            : String(localized: "Locked while \(version ?? "") is in review")
        lockedWhile = isLive ? String(localized: "while it’s on the App Store") : String(localized: "while it’s in review")
        if let listing { addStorePage(listing, locked: locked, newLanguages: newLanguages) }
        if let information { addAppInformation(information, locked: locked) }
        if let inAppTextsMissing { addInAppTexts(missing: inAppTextsMissing) }
        if let compliance { addCompliance(compliance, export: information?.content.export) }
    }

    /// Reads the app as an assistant would.
    @MainActor
    static func load(app: StoreApp, in workspace: MCPWorkspace) async -> SuggestEverythingScope {
        let listing = try? await MCPListingDraft.load(app: app.id, in: workspace)
        let information = try? await MCPAppInformationDraft.load(app: app.id, in: workspace, includesPrivacyURLs: true)
        let inAppTexts = try? await MCPInAppTextsDraft.load(app: app.id, in: workspace)
        let compliance = try? await MCPComplianceState.load(app, workspace: workspace)
        return SuggestEverythingScope(
            appName: app.name,
            listing: listing?.listing,
            information: information?.slots,
            newLanguages: listing?.newLanguageLocales ?? [],
            inAppTextsMissing: inAppTexts.flatMap { $0.content.isEmpty ? nil : $0.missingCount },
            compliance: compliance?.report
        )
    }

    /// What Suggest Everything… copies.
    var prompt: String {
        let app = versionString.map { "\(appName) \($0)" } ?? appName
        guard isRestricted, !openParts.isEmpty else {
            let everything = String(localized: """
            Suggest everything for \(app) in Atlas. Read the project first, then suggest every Store Page field in every \
            language, including languages the app supports that aren’t on the App Store yet, and App Information: General, Age \
            Rating, Accessibility for each device and its URL, App Privacy’s User Privacy Choices URL in each language, and \
            App Review’s contact, sign-in and notes. Skip fields I’ve already changed.
            """)
            let withInAppTexts = inAppTextsDetail == nil ? everything : everything + " " + Self.inAppTextsRequest
            return complianceDetail == nil && !coversExportCompliance ? withInAppTexts : withInAppTexts + " " + Self.complianceRequest
        }
        let parts = openParts.formatted(.list(type: .and))
        return String(localized: """
        Suggest everything Atlas can still change for \(app) \(lockedWhile): \(parts). Read the project first. Skip fields \
        I’ve already changed.
        """)
    }

    /// The In-App Texts part of the prompt: they're proposed, not suggested.
    static var inAppTextsRequest: String {
        String(localized: """
        Also propose the In-App Texts that are missing, in every language: the subscription group's display name and each \
        subscription's and in-app purchase's display name and description (get_in_app_texts, then propose_in_app_texts). \
        \(StoreTextRules.inAppSummary)
        """)
    }

    /// The App Compliance and Export Compliance part of the prompt: answers
    /// that wait on their pages, part of the run's plan.
    static var complianceRequest: String {
        String(localized: """
        Also answer App Compliance (get_compliance, then propose_compliance_answers) and Export Compliance from the \
        code's use of encryption (get_export_compliance, then propose_export_compliance), as part of the run.
        """)
    }

    // MARK: - Pages

    /// App Compliance's regulations an assistant may answer, and Export
    /// Compliance when the build could be read. Neither is locked by the
    /// version.
    private mutating func addCompliance(_ report: ComplianceReport, export: ExportComplianceValues?) {
        let open = ComplianceRule.allCases.filter { !ComplianceSuggestedAnswer.names(for: $0).isEmpty && report.refusal(for: $0) == nil }
        if !open.isEmpty {
            let detail = open.map(\.name).formatted(.list(type: .and))
            complianceDetail = detail
            rows.append(Row(page: .appCompliance, detail: String(localized: "\(detail). You accept each answer.")))
        }
        if let export {
            let detail = export.buildNumber.map { String(localized: "Encryption, for build \($0)") }
                ?? String(localized: "Encryption, for the build you attach")
            rows.append(Row(page: .exportCompliance, detail: detail))
            coversExportCompliance = true
        }
        guard complianceDetail != nil || coversExportCompliance else { return }
        openParts.append(String(localized: "App Compliance and Export Compliance"))
    }

    private mutating func addInAppTexts(missing: Int) {
        inAppTextsDetail = missing == 0
            ? String(localized: "Nothing missing: group name, subscription and in-app purchase texts")
            : String(localized: "\(missing) missing: group name, subscription and in-app purchase texts")
        openParts.append(String(localized: "the missing In-App Texts (get_in_app_texts, then propose_in_app_texts)"))
    }

    /// Every field in every language, and the new languages' pages.
    private mutating func addStorePage(_ listing: StoreListing, locked: String, newLanguages: [StoreLocale]) {
        let names = listing.displayLocales.map(\.name)
        let editable = listing.fields.filter(listing.canEdit)
        if editable.count == listing.fields.count {
            let languages = names.count <= 3 ? names.formatted(.list(type: .and)) : String(localized: "\(names.count) languages")
            guard !newLanguages.isEmpty else {
                rows.append(Row(page: .storePage, detail: String(localized: "Every field in \(languages)")))
                return
            }
            let new = newLanguages.count <= 3
                ? newLanguages.map(\.name).formatted(.list(type: .and))
                : String(localized: "\(newLanguages.count) languages")
            rows.append(Row(page: .storePage, detail: String(localized: """
            Every field in \(languages), and new pages for \(new): the app supports them, the App Store doesn’t have them yet
            """)))
        } else if editable.isEmpty {
            rows.append(Row(page: .storePage, detail: locked, isLocked: true))
            isRestricted = true
        } else {
            let fields = editable.map(\.title).formatted(.list(type: .and))
            let languages = names.count == 1 ? names[0] : String(localized: "\(names.count) languages")
            rows.append(Row(page: .storePage, detail: String(localized: "\(fields) only, in \(languages). The rest is \(Self.lowercasedFirst(locked)).")))
            openParts.append(String(localized: "\(fields) in every language"))
            isRestricted = true
        }
    }

    private mutating func addAppInformation(_ slots: AppInformationSlotValues, locked: String) {
        addGeneral(slots, locked: locked)
        if slots.canSuggest(.ageRating(.wellness)) {
            let unanswered = AgeRatingQuestion.allCases.count { slots.value(.ageRating($0)).isEmpty }
            let all = AgeRatingQuestion.allCases.count
            let detail = switch unanswered {
            case all: String(localized: "Not answered yet: all \(all) questions")
            case 0: String(localized: "A check of every answer")
            case 1: String(localized: "1 question not answered, and a check of the rest")
            default: String(localized: "\(unanswered) questions not answered, and a check of the rest")
            }
            rows.append(Row(page: .ageRating, detail: detail))
            openParts.append(String(localized: "Age Rating"))
        }
        let families = slots.accessibilityFamilies
        if !families.isEmpty {
            let devices = families.map(\.name).formatted(.list(type: .and))
            rows.append(Row(page: .accessibility, detail: String(localized: "\(devices), every feature, and the accessibility URL")))
            openParts.append(String(localized: "Accessibility for each device"))
        }
        addAppPrivacy(slots)
        let review = AppInformationSuggestionField.fields(on: .appReview)
        if review.contains(where: { slots.canSuggest(.field($0)) }) {
            rows.append(Row(page: .appReview, detail: String(localized: "Contact, sign-in and notes")))
            openParts.append(String(localized: "App Review"))
        } else {
            rows.append(Row(page: .appReview, detail: locked, isLocked: true))
            isRestricted = true
        }
    }

    /// The User Privacy Choices URL in each language, the app info's: open
    /// while the version is in review, as the categories are.
    private mutating func addAppPrivacy(_ slots: AppInformationSlotValues) {
        let locales = slots.privacyLocales
        guard !locales.isEmpty else { return }
        let languages = locales.count <= 3
            ? locales.map(\.name).formatted(.list(type: .and))
            : String(localized: "\(locales.count) languages")
        rows.append(Row(page: .appPrivacy, detail: String(localized: "User Privacy Choices URL in \(languages)")))
        openParts.append(String(localized: "the User Privacy Choices URLs"))
    }

    /// Copyright, the categories (and Games subcategories for a game),
    /// content rights and the release; the categories and content rights,
    /// the app's, stay open while the version is in review.
    private mutating func addGeneral(_ slots: AppInformationSlotValues, locked: String) {
        let fields: [AppInformationSuggestionField] = [.copyright, .primaryCategory, .secondaryCategory, .contentRights, .release]
        let open = fields.filter { slots.canSuggest(.field($0)) }
        if open.count == fields.count {
            let detail = slots.canSuggest(.field(.gamesSubcategories))
                ? String(localized: "Copyright, categories, Games subcategories, content rights, release")
                : String(localized: "Copyright, categories, content rights, release")
            rows.append(Row(page: .general, detail: detail))
            openParts.append(String(localized: "General"))
            return
        }
        isRestricted = true
        guard !open.isEmpty else {
            rows.append(Row(page: .general, detail: locked, isLocked: true))
            return
        }
        var names: [String] = []
        for field in open {
            let name = switch field {
            case .primaryCategory, .secondaryCategory: String(localized: "categories")
            case .contentRights: String(localized: "content rights")
            case .release: String(localized: "release")
            default: String(localized: "copyright")
            }
            if !names.contains(name) { names.append(name) }
        }
        let list = names.formatted(.list(type: .and))
        rows.append(Row(page: .general, detail: String(localized: "\(Self.uppercasedFirst(list)) only. The rest is \(Self.lowercasedFirst(locked)).")))
        openParts.append(list)
    }

    private static func uppercasedFirst(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }
    private static func lowercasedFirst(_ text: String) -> String { text.prefix(1).lowercased() + text.dropFirst() }
}
