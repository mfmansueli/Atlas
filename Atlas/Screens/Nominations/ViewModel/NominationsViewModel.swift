//
//  NominationsViewModel.swift
//  Atlas
//

import Foundation
import Observation

/// Nominations for one app (board 70): the gallery (Drafts → Submitted →
/// Archived) or one nomination's page, App Store Connect's nominations with
/// this Mac's drafts and edits on top (`NominationsStore`), what waits in
/// Review & Push, and what assistants and Atlas suggest.
@MainActor
@Observable
final class NominationsViewModel {
    let app: StoreApp
    let services: any NominationsServices
    let store: NominationsStore
    let queue: ChangeQueue

    private(set) var state: LoadState<[Nomination]> = .idle
    /// The read's problem, shown as the section's one banner; the drafts on
    /// this Mac still show.
    var problem: NominationsLoadProblem?
    var context = NominationContext()
    /// The open nomination, or a new assistant nomination under review.
    var selection: Selection?
    var sheet: NominationSheet?
    var toast: ToastMessage?
    /// The refusal's Details are open.
    var showsRefusalDetails = false
    @ObservationIgnored var undoAction: (() -> Void)?
    @ObservationIgnored var now: () -> Date = { .now }
    /// What was pushed: a refused row's reason comes from here. Set by the
    /// section.
    @ObservationIgnored var pushHistory: PushHistory?

    enum Selection: Hashable, Sendable {
        case nomination(String)
        case proposal(String)
    }

    init(app: StoreApp, services: any NominationsServices, store: NominationsStore, queue: ChangeQueue) {
        self.app = app
        self.services = services
        self.store = store
        self.queue = queue
    }

    var builder: NominationChangeBuilder { NominationChangeBuilder(appID: app.id) }

    // MARK: - Loading

    /// Reads the nominations (the first time, or again with `force`) and
    /// what Atlas can suggest from; returns whether a read finished.
    @discardableResult
    func load(force: Bool = false) async -> Bool {
        guard force || state.value == nil, !state.isLoading else { return false }
        if state.value == nil { state = .loading }
        do {
            let remote = try await services.nominations(for: app)
            state = .loaded(remote)
            problem = nil
            store.reconcile(remote: remote, changes: queue.changes(for: app.id, section: .nominations), for: app.id)
        } catch {
            problem = NominationsLoadProblem(error)
            if state.value == nil { state = .loaded([]) }
            if case .failed = problem, (state.value ?? []).isEmpty, store.drafts(for: app.id).isEmpty {
                state = .failed(problem.map(Self.text) ?? "")
            }
        }
        context = await services.context(for: app)
        return state.value != nil
    }

    private static func text(_ problem: NominationsLoadProblem) -> String {
        if case let .failed(copy) = problem { return copy.text }
        return ""
    }

    /// Nothing can be created or changed with this key.
    var keyCannotWrite: Bool { problem == .keyRole }

    // MARK: - Nominations

    /// App Store Connect's nominations that include the app, with this
    /// Mac's edits on its drafts, and the drafts only on this Mac.
    var nominations: [Nomination] {
        let remote = (state.value ?? []).map { nomination -> Nomination in
            var nomination = nomination
            if nomination.state == .draft, let edit = store.edit(for: app.id, nominationID: nomination.id) { nomination.content = edit }
            return nomination
        }
        let ids = Set(remote.map(\.id))
        return store.drafts(for: app.id).filter { !ids.contains($0.id) } + remote
    }

    /// A gallery group, the soonest start first (no start date last).
    func nominations(in state: NominationState) -> [Nomination] {
        nominations.filter { $0.state == state }.sorted { lhs, rhs in
            (lhs.content.publishStart ?? .distantFuture) < (rhs.content.publishStart ?? .distantFuture)
        }
    }

    func nomination(_ id: String) -> Nomination? {
        nominations.first { $0.id == id }
    }

    /// What App Store Connect has of a draft, before this Mac's edits.
    func remote(_ id: String) -> Nomination? {
        state.value?.first { $0.id == id }
    }

    /// New nominations assistants suggested, waiting for the person.
    var newProposals: [NominationProposal] {
        store.proposals(for: app.id).filter(\.isNew)
    }

    var selectedNomination: Nomination? {
        guard case let .nomination(id) = selection else { return nil }
        return nomination(id)
    }

    var selectedProposal: NominationProposal? {
        guard case let .proposal(id) = selection else { return nil }
        return store.proposals(for: app.id).first { $0.id == id }
    }

    /// Nothing at all yet: the empty state.
    var isEmpty: Bool { nominations.isEmpty && newProposals.isEmpty }

    /// The account's name for an app, e.g. "Quiet Timer".
    func appName(_ id: StoreApp.ID, in nomination: Nomination? = nil) -> String {
        if id == app.id { return app.name }
        return context.apps.first { $0.id == id }?.name ?? nomination?.appNames[id] ?? id
    }

    /// "Lumen Journal + Quiet Timer".
    func appsText(_ nomination: Nomination) -> String {
        let ids = [app.id] + nomination.content.appIDs.filter { $0 != app.id }
        return ids.map { appName($0, in: nomination) }.joined(separator: " + ")
    }

    func eventName(_ id: String, in nomination: Nomination) -> String {
        context.events.first { $0.id == id }?.name ?? nomination.eventNames[id] ?? id
    }

    func need(_ nomination: Nomination) -> NominationNeed {
        NominationNeed(NominationNeed.Facts(
            nomination: nomination,
            queued: Set(queued(nomination.id).keys),
            isRefused: refusal(for: nomination.id) != nil,
            actionRequest: store.actionRequests(for: app.id, nominationID: nomination.id).first,
            now: now()
        ))
    }

    // MARK: - Navigation

    func open(_ id: String) {
        selection = .nomination(id)
        showsRefusalDetails = false
    }

    func openProposal(_ id: String) {
        selection = .proposal(id)
    }

    /// Back to the gallery. A new draft nothing was written in goes away.
    func back() {
        if let nomination = selectedNomination, !nomination.isInAppStoreConnect, nomination.content == NominationContent(appIDs: [app.id]),
           queued(nomination.id).isEmpty
        {
            store.removeDraft(nomination.id, for: app.id)
        }
        selection = nil
        sheet = nil
    }

    /// New Nomination…: a draft on this Mac, open with nothing in it.
    func newNomination() {
        let draft = Nomination.newDraft(appID: app.id, now: now())
        store.save(draft, for: app.id)
        open(draft.id)
    }

    // MARK: - Editing

    /// Changes a draft: on this Mac it's saved as is; one in App Store
    /// Connect keeps the change as an edit until it's pushed. A row already
    /// in Review & Push follows the change.
    func update(_ id: String, _ change: (inout NominationContent) -> Void) {
        guard var nomination = nomination(id), nomination.isEditable else { return }
        change(&nomination.content)
        if !nomination.content.appIDs.contains(app.id) { nomination.content.appIDs.insert(app.id, at: 0) }
        if nomination.isInAppStoreConnect {
            let original = remote(id)?.content
            store.setEdit(nomination.content == original ? nil : nomination.content, nominationID: id, for: app.id)
        } else {
            nomination.lastModifiedDate = now()
            store.save(nomination, for: app.id)
        }
        followQueued(nomination)
    }

    /// The assistant's new nomination under review, changed before it's
    /// accepted.
    func updateProposal(_ id: String, _ change: (inout NominationContent) -> Void) {
        guard var proposal = store.proposals(for: app.id).first(where: { $0.id == id }) else { return }
        change(&proposal.content)
        store.add(proposal, for: app.id)
    }

    /// Whether a draft in App Store Connect has changes on this Mac.
    func isEdited(_ nomination: Nomination) -> Bool {
        nomination.isInAppStoreConnect && store.edit(for: app.id, nominationID: nomination.id) != nil
    }

    /// "Draft on this Mac · not in App Store Connect yet", or "Draft in App
    /// Store Connect · changed on this Mac".
    func whereText(_ nomination: Nomination) -> String {
        if !nomination.isInAppStoreConnect {
            return String(localized: "Draft on this Mac · not in App Store Connect yet", comment: "kind:description")
        }
        return isEdited(nomination)
            ? String(localized: "Draft in App Store Connect · changed on this Mac", comment: "kind:description")
            : String(localized: "Draft in App Store Connect", comment: "kind:description")
    }

    /// Apple refused a push of this nomination and it hasn't been put in
    /// Review & Push since: Apple's words for Details.
    func refusal(for id: String) -> NominationRefusal? {
        if let refusal = store.refusal(for: app.id, nominationID: id) { return refusal }
        guard let history = pushHistory, queued(id).isEmpty else { return nil }
        let queuedAt = store.archive(for: app.id).queuedAt[id] ?? .distantPast
        for record in history.records(for: app.id).sorted(by: { $0.date > $1.date }) where record.date > queuedAt {
            for (changeID, text) in record.failures {
                guard let parsed = NominationChangeBuilder.parse(changeID), parsed.nominationID == id else { continue }
                return NominationRefusal(kind: parsed.kind.rawValue, details: text, date: record.date)
            }
            if record.pushed.contains(where: { NominationChangeBuilder.parse($0.id)?.nominationID == id }) { return nil }
        }
        return nil
    }

    /// Takes the links out of a description Apple refused for one, into
    /// Materials.
    func moveLinksToMaterials(_ id: String) {
        guard let nomination = nomination(id) else { return }
        let links = NominationLink.links(in: nomination.content.description)
        guard !links.isEmpty else { return }
        update(id) { content in
            var text = content.description
            for link in links { text = text.replacingOccurrences(of: link, with: "") }
            content.description = text.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            let full = links.map { $0.lowercased().hasPrefix("http") ? $0 : "https://\($0)" }
            content.materials += full.filter { !content.materials.contains($0) }
        }
        show(String(localized: "Moved the link to Materials. Add the draft to Review & Push again.", comment: "kind:toast"))
    }

    // MARK: - Toast

    func show(_ text: String, undo: (() -> Void)? = nil, reviewPush: Bool = false) {
        undoAction = undo
        toast = ToastMessage(
            text: text, canUndo: undo != nil, actionTitle: reviewPush && undo == nil ? String(localized: "Open Review & Push", comment: "kind:button") : nil
        )
    }

    func undo() {
        undoAction?()
        undoAction = nil
        toast = nil
    }
}
