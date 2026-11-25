//
//  SuggestionRun.swift
//  Atlas
//

import Foundation

/// Suggest Everything: one assistant suggesting every field of an app it
/// can. Suggest Everything… copies the prompt and waits; the assistant's
/// `begin_suggestions` announces the plan, which gives the total and the
/// fields still to come; `suggest_fields` with the run's id fills it in.
/// Items outside the plan are added to the total. The run finishes at the
/// plan's last item or `end_suggestions`; Stop Receiving keeps what arrived
/// and refuses the rest.
struct SuggestionRun: Identifiable, Hashable, Sendable {
    enum Phase: Hashable, Sendable {
        /// The prompt is copied; the assistant hasn't announced a plan.
        case waiting
        case running
        case finished
        /// Stop Receiving.
        case stopped
    }

    /// What the run is for: Suggest Everything, counted by field, or texts
    /// in several languages (`begin_translation`), counted by language.
    enum Kind: Hashable, Sendable {
        case everything
        case translation
    }

    /// With nothing arriving for this long, the card says the assistant
    /// stopped sending.
    static let quietInterval: TimeInterval = 120

    /// "run_1": what the assistant passes back with each call.
    var id: String
    var appID: StoreApp.ID
    /// e.g. "Claude Code".
    var client: String
    /// What Suggest Everything… copied; empty when the assistant started
    /// on its own (`/mcp__atlas__suggest_all`).
    var prompt: String
    var phase: Phase
    /// The fields the assistant said it will suggest, in its order.
    var plan: [SuggestionTarget] = []
    /// Fields it sent with the run that weren't in the plan.
    var extras: [SuggestionTarget] = []
    var arrived: Set<SuggestionTarget> = []
    /// What arrived, for Accept All.
    var suggestionIDs: [FieldSuggestion.ID] = []
    var startedAt: Date
    var lastActivityAt: Date
    var kind: Kind = .everything
    /// A translation's languages, by locale code, in the order asked.
    var languages: [String] = []
    /// The languages whose agents said they're done
    /// (`end_suggestions` with a locale).
    var endedLanguages: Set<String> = []

    var total: Int { plan.count + extras.count }
    /// "4" of "4 of 12 languages".
    var languagesDone: Int { languages.count(where: endedLanguages.contains) }
    var received: Int { arrived.count }

    var isRunning: Bool { phase == .running }
    var isOver: Bool { phase == .finished || phase == .stopped }

    var fraction: Double {
        if kind == .translation {
            return languages.isEmpty ? 0 : Double(languagesDone) / Double(languages.count)
        }
        return total > 0 ? min(1, Double(received) / Double(total)) : 0
    }

    /// Every planned field arrived; for a translation, every language
    /// ended, since its reviewer comes after its texts.
    var isComplete: Bool {
        switch kind {
        case .everything: plan.allSatisfy(arrived.contains)
        case .translation: !languages.isEmpty && languages.allSatisfy(endedLanguages.contains)
        }
    }

    /// Nothing arrived for two minutes while it still runs.
    func isQuiet(at date: Date) -> Bool {
        isRunning && date.timeIntervalSince(lastActivityAt) >= Self.quietInterval
    }

    /// A planned field whose suggestion hasn't arrived, while the run goes on.
    func isComing(_ target: SuggestionTarget) -> Bool {
        isRunning && !arrived.contains(target) && plan.contains(target) && !isEnded(target)
    }

    /// How many are still to come in `scopes`.
    func comingCount(in scopes: some Collection<SuggestionScope>) -> Int {
        guard isRunning else { return 0 }
        return plan.count { scopes.contains($0.scope) && !arrived.contains($0) && !isEnded($0) }
    }

    func comingCount(on page: SuggestionPage) -> Int {
        guard isRunning else { return 0 }
        return plan.count { SuggestionPage($0.scope) == page && !arrived.contains($0) && !isEnded($0) }
    }

    /// Its language ended: what didn't come won't.
    private func isEnded(_ target: SuggestionTarget) -> Bool {
        guard case let .storePage(code) = target.scope else { return false }
        return endedLanguages.contains(code)
    }

    // MARK: - Arriving

    /// A field the assistant settled: planned, or sent with the run's id.
    /// `suggestionID` is nil when the field already held the value.
    mutating func noteArrival(of target: SuggestionTarget, suggestionID: FieldSuggestion.ID?, at date: Date) {
        if !plan.contains(target), !extras.contains(target) {
            extras.append(target)
        }
        arrived.insert(target)
        if let suggestionID, !suggestionIDs.contains(suggestionID) { suggestionIDs.append(suggestionID) }
        lastActivityAt = date
    }

    /// A translation's language is done: its writer and reviewer sent
    /// everything. False when the run has no such language.
    @discardableResult
    mutating func endLanguage(_ code: String, at date: Date) -> Bool {
        guard languages.contains(code) else { return false }
        endedLanguages.insert(code)
        lastActivityAt = date
        return true
    }

    // MARK: - Text

    /// "Suggesting everything · 9 of 18"; above 20, "Suggesting everything
    /// · 38% · 97 of 255" (`AIProgress`).
    var progressText: String {
        if kind == .translation { return translatingText }
        let progress = AIProgress(done: received, total: total)
        guard progress.total > AIProgress.countLimit else { return String(localized: "Suggesting everything · \(received) of \(total)") }
        return String(localized: "Suggesting everything · \(progress.label)", comment: "kind:progress-step")
    }

    /// "4 of 12 languages".
    private var languagesCountText: String {
        if languages.count == 1 { return String(localized: "\(languagesDone) of 1 language", comment: "kind:progress-step") }
        return String(localized: "\(languagesDone) of \(languages.count) languages", comment: "kind:progress-step")
    }

    /// "Translating · 4 of 12 languages": languages whose reviewer is done.
    private var translatingText: String {
        languages.count == 1
            ? String(localized: "Translating · \(languagesDone) of 1 language", comment: "kind:progress-step")
            : String(localized: "Translating · \(languagesDone) of \(languages.count) languages", comment: "kind:progress-step")
    }

    /// The card's title.
    var title: String {
        switch (phase, kind) {
        case (.waiting, .everything), (.running, .everything): String(localized: "Suggesting everything")
        case (.waiting, .translation), (.running, .translation): String(localized: "Translating", comment: "kind:title")
        case (.finished, .everything): String(localized: "Finished suggesting")
        case (.finished, .translation): String(localized: "Finished translating", comment: "kind:title")
        case (.stopped, _): String(localized: "Stopped receiving")
        }
    }

    /// Beside the title: "9 of 18", "18 suggestions", "12 suggestions of 18".
    var countText: String {
        switch phase {
        case .waiting where kind == .translation, .running where kind == .translation: languagesCountText
        case .waiting, .running: String(localized: "\(received) of \(total)")
        case .finished where received == 1: String(localized: "1 suggestion")
        case .finished: String(localized: "\(received) suggestions")
        case .stopped: String(localized: "\(received) suggestions of \(total)")
        }
    }

    /// "Claude Code stopped sending · 12 of 18".
    var quietText: String {
        String(localized: "\(client) stopped sending · \(received) of \(total)")
    }

    /// The banner on a page: "Here: 2 of 3 arrived."
    func hereText(in scopes: some Collection<SuggestionScope>) -> String? {
        let here = (plan + extras).filter { scopes.contains($0.scope) }
        guard !here.isEmpty else { return nil }
        return String(localized: "Here: \(here.count(where: arrived.contains)) of \(here.count) arrived.")
    }

    /// The toast once it's over: "Claude Code sent 18 suggestions: Store
    /// Page 5 · General 1 · Age Rating 6 · Accessibility 5 · App Review 1."
    var finishedText: String {
        guard received > 0 else { return String(localized: "\(client) found nothing new to suggest.") }
        if kind == .translation { return translatedText }
        let areas = rows.filter { $0.arrived > 0 }.map { "\($0.page.title) \($0.arrived.formatted())" }.joined(separator: " · ")
        return received == 1
            ? String(localized: "\(client) sent 1 suggestion: \(areas).")
            : String(localized: "\(client) sent \(received) suggestions: \(areas).")
    }

    /// "Claude Code sent 24 suggestions in 6 languages."
    private var translatedText: String {
        switch (received, languages.count) {
        case (1, _): String(localized: "\(client) sent 1 suggestion.", comment: "kind:toast")
        case (_, 1): String(localized: "\(client) sent \(received) suggestions in 1 language.", comment: "kind:toast")
        default: String(localized: "\(client) sent \(received) suggestions in \(languages.count) languages.", comment: "kind:toast")
        }
    }

    // MARK: - Rows

    /// One per page the run covers, in the pages' order.
    var rows: [SuggestionRunRow] {
        let targets = plan + extras
        return SuggestionPage.allCases.compactMap { page in
            let here = targets.filter { SuggestionPage($0.scope) == page }
            guard !here.isEmpty else { return nil }
            return SuggestionRunRow(page: page, detail: detail(of: here, on: page), arrived: here.count(where: arrived.contains), total: here.count)
        }
    }

    /// Per language or device ("German 0/1", or "German 1" once it's over),
    /// or the fields' names.
    private func detail(of targets: [SuggestionTarget], on page: SuggestionPage) -> String {
        guard [.storePage, .accessibility, .appPrivacy].contains(page) else {
            return targets.map(SuggestionPage.fieldTitle).joined(separator: ", ")
        }
        var scopes: [SuggestionScope] = []
        for target in targets where !scopes.contains(target.scope) {
            scopes.append(target.scope)
        }
        return scopes.map { scope in
            let inScope = targets.filter { $0.scope == scope }
            let count = inScope.count(where: arrived.contains)
            let name = Self.name(of: scope)
            return isOver ? "\(name) \(count.formatted())" : "\(name) \(count.formatted())/\(inScope.count.formatted())"
        }
        .joined(separator: " · ")
    }

    /// "German", "Apple Watch", or "URL" for Accessibility's.
    private static func name(of scope: SuggestionScope) -> String {
        switch scope {
        case let .storePage(code): StoreLocaleCatalog.locale(code: code)?.name ?? code
        case let .accessibility(family): DeviceFamily(rawValue: family)?.name ?? family
        case let .appPrivacy(code): StoreLocaleCatalog.locale(code: code)?.name ?? code
        case .appInformation: scope.page == .accessibility ? String(localized: "URL") : scope.title
        }
    }
}
