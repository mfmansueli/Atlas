//
//  MCPSuggestionSession.swift
//  Atlas
//

import Foundation

/// One `suggest_fields` call at work: the app's Store Page and App
/// Information as the assistant sees them (loaded only when an item needs
/// them), and each item checked and put in the suggestion store, or with
/// `apply` queued as a change. `commit()` queues the Store Page's applied
/// values together, as the Store Page does. A language the app's project
/// has and the App Store page doesn't takes suggestions, never applied
/// values: its page is created only when the person adds it. `begin_suggestions` checks its
/// plan with the same session (`planned(_:)`).
@MainActor
struct MCPSuggestionSession {
    /// An item's result and its activity log line.
    struct Settled {
        var result: [String: JSONValue]
        var logLine: MCPToolOutcome.LogLine
    }

    let app: StoreApp
    let store: FieldSuggestionStore
    let context: MCPToolContext
    /// "Suggest and edit drafts" and `apply: true`.
    let applies: Bool
    /// The Suggest Everything run the items were sent with.
    let runID: SuggestionRun.ID?
    private(set) var listing: MCPListingDraft?
    private(set) var information: MCPAppInformationDraft?
    private var hasAppliedStoreText = false

    init(
        app: StoreApp,
        items: [MCPSuggestionItem],
        store: FieldSuggestionStore,
        context: MCPToolContext,
        applies: Bool,
        runID: SuggestionRun.ID? = nil,
        version: String? = nil
    ) async throws {
        self.app = app
        self.store = store
        self.context = context
        self.applies = applies
        self.runID = runID
        listing = items.contains { $0.area == .storePage }
            ? try await MCPListingDraft.load(app: app.id, version: version, in: context.workspace)
            : nil
        information = items.contains { $0.area == .appInformation }
            ? try await MCPAppInformationDraft.load(
                app: app.id,
                version: version,
                in: context.workspace,
                includesAccessibility: items.contains {
                    $0.page.flatMap(SuggestFieldsTool.page(named:)) == .accessibility || AppInformationSuggestionField.accessibilityURL.isNamed($0.field)
                },
                includesPrivacyURLs: items.contains { $0.page.flatMap(SuggestFieldsTool.page(named:)) == .appPrivacy }
            )
            : nil
    }

    /// A `version` argument must be the one being prepared.
    func check(version: String?) throws {
        if let listing { try SuggestFieldsTool.check(version: version, against: listing.listing.version.versionString, app: app.name) }
        if let shown = information?.content.version?.versionString { try SuggestFieldsTool.check(version: version, against: shown, app: app.name) }
    }

    mutating func suggest(_ item: MCPSuggestionItem) -> Settled {
        var result: [String: JSONValue] = ["field": .string(item.field)]
        switch item.area {
        case .storePage: result["locale"] = item.locale.map(JSONValue.string) ?? .null
        case .appInformation:
            result["page"] = item.page.map(JSONValue.string) ?? .null
            if let device = item.device { result["device"] = .string(device) }
            if let locale = item.locale { result["locale"] = .string(locale) }
        }
        let target = target(of: item)
        do {
            let settled = switch item.area {
            case .storePage: try suggestStoreText(item)
            case .appInformation: try suggestInformation(item)
            }
            result.merge(settled) { _, new in new }
            let outcome: MCPCallOutcome = result["status"] == "unchanged" ? .read : .proposed
            return Settled(result: result, logLine: MCPToolOutcome.LogLine(target: target, outcome: outcome))
        } catch {
            result.merge(error.json) { _, new in new }
            return Settled(result: result, logLine: MCPToolOutcome.LogLine(target: target, outcome: .refused, reason: error.reason))
        }
    }

    /// Queues the Store Page values `apply` wrote.
    func commit() {
        guard hasAppliedStoreText, let listing else { return }
        _ = listing.commit(to: context.workspace.changes)
    }

    // MARK: - A new version in Review & Push

    /// A change for a new version that waits in Review & Push (its version
    /// fields, or its app info's: categories, age rating): there's no page
    /// to show a suggestion on, so it's queued with the version.
    private static func waits(_ change: PendingChange?, in draft: MCPAppInformationDraft) -> Bool {
        guard let queued = draft.queuedVersion, let change else { return false }
        return queued.mentions(change)
    }

    static func waitsNote(_ version: QueuedAppVersion) -> String {
        String(localized: """
        Version \(version.versionString) is queued in Review & Push, so this waits there with it, as the assistant’s: when the person pushes, Atlas creates the version, then writes this into it. Discarding the version discards it.
        """)
    }

    /// An applied Yes to third-party content: only the person can say they
    /// have the rights.
    static var rightsNote: String {
        String(localized: "It waits in Review & Push until the person confirms in Atlas that they have the rights to the third-party content.")
    }

    /// An applied Sign-in required: the password is the person's to type.
    static var passwordNote: String {
        String(localized: "The person types the demo account’s password in Atlas: it’s never read or sent over MCP.")
    }

    // MARK: - Store Page

    private mutating func suggestStoreText(_ item: MCPSuggestionItem) throws(MCPSuggestionRefusal) -> [String: JSONValue] {
        let (field, locale) = try storeTarget(of: item)
        var result: [String: JSONValue] = ["field": .string(field.rawValue)]
        if listing?.listing.value(field, in: locale) == item.value {
            result["status"] = "unchanged"
            noteSettled(.storePage(locale, field))
        } else if applies || listing?.queuedVersion != nil, var draft = listing, draft.listing.contains(locale) {
            _ = draft.propose(item.value, for: field, locale: locale.code, by: context.clientName)
            listing = draft
            hasAppliedStoreText = true
            result["status"] = "applied"
            if let queued = draft.queuedVersion { result["note"] = .string(Self.waitsNote(queued)) }
            noteSettled(.storePage(locale, field))
        } else {
            result.merge(add(item.value, for: .storePage(locale, field), item: item)) { _, new in new }
        }
        // Even with apply: only the person creates a page.
        if listing?.isNewLanguage(locale) == true {
            result["note"] = .string(String(localized: """
            \(locale.name) isn’t on the App Store yet: this shows in its own tab of the Store Page, and its page is created only when the person adds it and pushes.
            """))
        }
        return result
    }

    /// The field and language an item is for, and its value checked like an
    /// edit and against App Review's metadata rules.
    private func storeTarget(of item: MCPSuggestionItem) throws(MCPSuggestionRefusal) -> (ListingField, StoreLocale) {
        let (field, locale) = try storeField(of: item)
        switch ListingFieldValidator.validate(item.value, for: field) {
        case let .overLimit(count, limit): throw .overLimit(count: count, limit: limit)
        case .invalidURL: throw .invalidValue(String(localized: "Not a full https:// URL."))
        case .empty: throw .invalidValue(String(localized: "The value is empty."))
        case .valid:
            let issues = StoreTextGuidelineCheck.issues(in: item.value, for: field)
            guard issues.isEmpty else { throw .guidelines(issues) }
            if let refusal = MCPNaturalCheck.refusal(item.layers, for: field) { throw .invalidValue(refusal) }
            return (field, locale)
        }
    }

    /// The field and language an item names, if the assistant may suggest
    /// it now.
    private func storeField(of item: MCPSuggestionItem) throws(MCPSuggestionRefusal) -> (ListingField, StoreLocale) {
        guard let listing = listing?.listing else { throw .invalidValue(String(localized: "The Store Page couldn’t be read.")) }
        guard let field = ListingField.matching(item.field) else { throw .unknownField(item.field, known: ListingField.mcpNames) }
        guard let code = item.locale else { throw .unknownLocale(String(localized: "Store Page suggestions need a locale, e.g. en-US.")) }
        guard let draft = self.listing, let locale = StoreLocaleCatalog.locale(code: code), listing.contains(locale) || draft.isNewLanguage(locale) else {
            throw .unknownLocale(self.listing?.unknownLocaleMessage(code) ?? code)
        }
        guard context.allows(.storeText) else { throw .notPermitted(.storeText) }
        guard listing.canEdit(field) else { throw .locked(version: listing.version.versionString) }
        return (field, locale)
    }

    // MARK: - App Information

    private mutating func suggestInformation(_ item: MCPSuggestionItem) throws(MCPSuggestionRefusal) -> [String: JSONValue] {
        let (slot, value, draft) = try informationTarget(of: item)
        var result = Self.json(slot)
        let source = ChangeSource.assistant(client: context.clientName)
        if draft.slots.value(slot) == value {
            result["status"] = "unchanged"
            noteSettled(slot.target)
        } else if let written = draft.slots.change(slot, to: value, source: source, confirmed: false),
                  applies || Self.waits(written.change, in: draft)
        {
            let changes = context.workspace.changes
            if let change = written.change { changes.upsert(draft.queueable(change)) } else { changes.discard(id: written.id) }
            // A device's next feature builds on this one.
            information = draft.with(changes: draft.queuedChanges(in: changes))
            result["status"] = "applied"
            result["changeId"] = .string(written.id)
            if let queued = draft.queuedVersion, Self.waits(written.change, in: draft) { result["note"] = .string(Self.waitsNote(queued)) }
            if slot == .field(.contentRights), written.change?.blockedReason != nil { result["note"] = .string(Self.rightsNote) }
            if slot == .field(.demoAccountRequired), value == AppInformationSuggestionField.yesAnswer { result["note"] = .string(Self.passwordNote) }
            noteSettled(slot.target)
        } else {
            result.merge(add(value, for: slot.target, item: item)) { _, new in new }
        }
        return result
    }

    /// The field, question or feature an item is for and its value as
    /// stored, checked like an edit on the page.
    private func informationTarget(
        of item: MCPSuggestionItem
    ) throws(MCPSuggestionRefusal) -> (AppInformationSuggestionSlot, String, MCPAppInformationDraft) {
        let (slot, draft) = try informationSlot(of: item)
        if case .privacyChoicesURL = slot {
            // Optional: "" clears it.
            let value = slot.normalized(item.value) ?? ""
            guard value.isEmpty || ListingFieldValidator.isValidURL(value) else {
                throw .invalidValue(String(localized: "Not a full https:// URL."))
            }
            return (slot, value, draft)
        }
        guard case let .field(field) = slot else {
            guard let value = slot.normalized(item.value) else {
                throw .invalidAnswer(String(localized: "“\(item.value)” isn’t an answer to \(item.field). The answers are \(slot.choiceList)."))
            }
            return (slot, value, draft)
        }
        guard let value = field.normalized(item.value), !value.isEmpty || field.isPicked || field.isURL else {
            throw .invalidValue(field.isPicked
                ? String(localized: "“\(item.value)” isn’t one of the choices get_app_information lists for \(field.rawValue).")
                : String(localized: "The value is empty."))
        }
        if field.isURL, let problem = AccessibilityURLValidator.problem(in: value) { throw .invalidValue(problem) }
        if let limit = field.limit, value.count > limit { throw .overLimit(count: value.count, limit: ListingTextLimit(limit)) }
        if field == .release, value == ReleaseOption.scheduled.rawValue, draft.general.earliestReleaseDate == nil {
            throw .invalidValue(String(localized: "“On a date” needs a date, which the person picks in Atlas."))
        }
        return (slot, value, draft)
    }

    /// The field, question or feature an item names, if the assistant may
    /// suggest it now.
    private func informationSlot(of item: MCPSuggestionItem) throws(MCPSuggestionRefusal) -> (AppInformationSuggestionSlot, MCPAppInformationDraft) {
        guard let draft = information else { throw .invalidValue(String(localized: "App Information couldn’t be read.")) }
        let slot = try Self.slot(of: item, in: draft)
        guard context.allows(.appInformation) else { throw .notPermitted(.appInformation) }
        try check(slot, in: draft)
        return (slot, draft)
    }

    /// Whether `slot` can take a value now: a version field while the
    /// version is editable, Games subcategories while that category is
    /// Games, and what's read on its own once it's been read.
    private func check(_ slot: AppInformationSuggestionSlot, in draft: MCPAppInformationDraft) throws(MCPSuggestionRefusal) {
        switch slot {
        case .field(.gamesSubcategories), .field(.secondaryGamesSubcategories):
            guard draft.slots.canSuggest(slot) else { throw .invalidValue(notAGame(secondary: slot == .field(.secondaryGamesSubcategories), in: draft)) }
        case .field(.accessibilityURL):
            guard draft.slots.canSuggest(slot) else { throw .invalidValue(String(localized: "\(app.name)’s accessibility couldn’t be read.")) }
        case let .field(field):
            guard !draft.isLocked(field) else { throw .locked(version: draft.content.version?.versionString ?? "") }
        case .ageRating, .accessibility:
            guard draft.slots.canSuggest(slot) else {
                throw .invalidValue(String(localized: "App Store Connect has no age rating questionnaire for \(app.name) yet."))
            }
        case .privacyChoicesURL:
            // `slot(of:)` checked the language.
            break
        }
    }

    /// Why Games subcategories can't be suggested: the primary (or, for
    /// the secondary pair, the secondary) category isn't Games.
    private func notAGame(secondary: Bool, in draft: MCPAppInformationDraft) -> String {
        guard secondary else {
            let category = AppCategory.name(for: draft.general.primaryCategory)
            return String(localized: "Games subcategories need Games as the primary category, and \(app.name)’s is \(category).")
        }
        let category = draft.general.secondaryCategory.map { AppCategory.name(for: $0) } ?? String(localized: "none")
        return String(localized: "Secondary Games subcategories need Games as the secondary category, and \(app.name)’s is \(category).")
    }

    /// What an item names: a General or App Review field (on any page when
    /// it names none), an Age Rating question, a feature on the device it
    /// names (the only one, when the app has one) or the accessibility URL,
    /// or a language's User Privacy Choices URL.
    private static func slot(of item: MCPSuggestionItem, in draft: MCPAppInformationDraft) throws(MCPSuggestionRefusal) -> AppInformationSuggestionSlot {
        let page = item.page.flatMap(SuggestFieldsTool.page(named:))
        switch page {
        case .ageRating:
            guard let question = AgeRatingQuestion.allCases.first(where: { $0.rawValue.caseInsensitiveCompare(item.field) == .orderedSame }) else {
                throw .unknownField(item.field, known: AgeRatingQuestion.allCases.map(\.rawValue))
            }
            return .ageRating(question)
        case .accessibility:
            return try accessibilitySlot(of: item, in: draft)
        case .appPrivacy:
            return try privacySlot(of: item, in: draft)
        default:
            let field = AppInformationSuggestionField.allCases.first { $0.isNamed(item.field) }
            guard let field, page == nil || page == field.page else {
                throw .unknownField(item.field, known: AppInformationSuggestionField.allCases.filter { page == nil || $0.page == page }.map(\.rawValue))
            }
            return .field(field)
        }
    }

    /// The accessibility URL, the app's for every device, or a feature on
    /// the device the item names.
    private static func accessibilitySlot(
        of item: MCPSuggestionItem,
        in draft: MCPAppInformationDraft
    ) throws(MCPSuggestionRefusal) -> AppInformationSuggestionSlot {
        let unread = String(localized: "\(draft.app.name)’s accessibility couldn’t be read.")
        if AppInformationSuggestionField.accessibilityURL.isNamed(item.field) {
            guard draft.slots.accessibility != nil else { throw .invalidValue(unread) }
            return .field(.accessibilityURL)
        }
        let families = draft.slots.accessibilityFamilies
        guard !families.isEmpty else { throw .invalidValue(unread) }
        let devices = families.map(\.mcpName).joined(separator: ", ")
        guard let family = item.device.flatMap(DeviceFamily.init(mcpName:)) ?? (families.count == 1 ? families.first : nil) else {
            throw .invalidValue(String(localized: "Accessibility suggestions need a device: \(devices)."))
        }
        guard families.contains(family) else {
            throw .invalidValue(String(localized: "\(draft.app.name) doesn’t run on \(family.name). Its devices are \(devices)."))
        }
        guard let feature = family.features.first(where: { $0.rawValue.caseInsensitiveCompare(item.field) == .orderedSame }) else {
            throw .unknownField(item.field, known: family.features.map(\.rawValue))
        }
        return .accessibility(family, feature)
    }

    /// The User Privacy Choices URL in the language the item names, one
    /// App Privacy has.
    private static func privacySlot(of item: MCPSuggestionItem, in draft: MCPAppInformationDraft) throws(MCPSuggestionRefusal) -> AppInformationSuggestionSlot {
        let field = AppInformationSuggestionSlot.privacyChoicesField
        guard field.caseInsensitiveCompare(item.field) == .orderedSame else { throw .unknownField(item.field, known: [field]) }
        guard let urls = draft.slots.privacyURLs else {
            throw .invalidValue(String(localized: "\(draft.app.name)’s privacy URLs couldn’t be read."))
        }
        let codes = urls.locales.map(\.locale.code).joined(separator: ", ")
        guard let code = item.locale else {
            throw .unknownLocale(String(localized: "The User Privacy Choices URL is set per language: pass a locale (\(codes))."))
        }
        guard let locale = StoreLocaleCatalog.locale(code: code), urls.remote(locale) != nil else {
            throw .unknownLocale(String(localized: "\(draft.app.name)’s App Privacy has no \(code). Its languages are \(codes)."))
        }
        return .privacyChoicesURL(locale)
    }

    /// The result's field, page and device, as MCP names them.
    private static func json(_ slot: AppInformationSuggestionSlot) -> [String: JSONValue] {
        var json: [String: JSONValue] = [
            "field": .string(slot.target.field),
            "page": .string(SuggestFieldsTool.mcpPageName(slot.scope.page?.rawValue ?? "")),
        ]
        if case let .accessibility(family, _) = slot { json["device"] = .string(family.mcpName) }
        if case let .privacyChoicesURL(locale) = slot { json["locale"] = .string(locale.code) }
        return json
    }

    // MARK: - Plans

    /// A `begin_suggestions` entry: the field it names, or why the run
    /// leaves it out. A field the person changed and hasn't pushed is left
    /// alone.
    func planned(_ item: MCPSuggestionItem) -> Result<SuggestionTarget, MCPPlanSkip> {
        do throws(MCPSuggestionRefusal) {
            switch item.area {
            case .storePage:
                let (field, locale) = try storeField(of: item)
                if listing?.listing.draft(field, in: locale).isPending == true { return .failure(.changedByYou) }
                return .success(.storePage(locale, field))
            case .appInformation:
                let (slot, draft) = try informationSlot(of: item)
                if draft.slots.isPending(slot) { return .failure(.changedByYou) }
                return .success(slot.target)
            }
        } catch {
            return .failure(.refused(error))
        }
    }

    // MARK: - Helpers

    /// Into the suggestion store: queued, replaced or unchanged, and its id.
    private func add(_ value: String, for target: SuggestionTarget, item: MCPSuggestionItem) -> [String: JSONValue] {
        let added = store.add(
            appID: app.id,
            target: target,
            value: value,
            reason: item.reason,
            source: .assistant(client: context.clientName),
            evidence: item.evidence,
            layers: item.layers,
            runID: runID,
            origin: context.origin
        )
        return ["status": .string(added.outcome.rawValue), "id": .string(added.suggestion.id)]
    }

    /// A field that needed no suggestion counts toward the run.
    private func noteSettled(_ target: SuggestionTarget) {
        store.noteSettled(target, appID: app.id, source: .assistant(client: context.clientName), runID: runID)
    }

    /// "Lumen Journal · de-DE · Subtitle", "Lumen Journal · App Review ·
    /// Notes", "Lumen Journal · Accessibility · Apple Watch · VoiceOver".
    private func target(of item: MCPSuggestionItem) -> String {
        switch item.area {
        case .storePage:
            return [app.name, item.locale, ListingField.matching(item.field)?.title ?? item.field].compactMap(\.self).joined(separator: " · ")
        case .appInformation:
            guard let slot = information.flatMap({ try? Self.slot(of: item, in: $0) }) else { return [app.name, item.field].joined(separator: " · ") }
            return [app.name, slot.scope.title, slot.title].joined(separator: " · ")
        }
    }
}
