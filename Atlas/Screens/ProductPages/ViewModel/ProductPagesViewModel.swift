//
//  ProductPagesViewModel.swift
//  Atlas
//

import Foundation
import Observation

/// Product Pages for one app: the list (App Store Connect's pages and the
/// drafts made here, with their numbers), the page being edited in one
/// language with what's queued on top, and the assistant's suggestions.
@MainActor
@Observable
final class ProductPagesViewModel {
    /// Kept while other sections show, so the section hands it the icon
    /// that arrives after it was made (`takeIcon`).
    private(set) var app: StoreApp
    let services: any ProductPagesServices
    let store: ProductPagesStore
    let queue: ChangeQueue

    private(set) var state: LoadState<ProductPagesSnapshot> = .idle
    /// A read after the first failed: what's shown is from `readAt`.
    private(set) var readFailure: String?
    /// The page the editor shows; nil shows the list.
    var selectedPageID: ProductPage.ID?
    var localeCode: String
    var device: ProductPageDevice = .iPhone
    /// The suggested page whose details are open.
    var expandedSuggestionID: String?
    /// At the limit: only hidden and rejected pages, to pick one to delete.
    var showsOnlyHiddenAndRejected = false
    var isNewPagePresented = false
    /// What New Page… starts with; nil starts with the primary language.
    var newPageTemplate: NewProductPage?
    var isPushPresented = false
    var isSubmitPresented = false
    var confirmation: ProductPageConfirmation?
    /// Why Choose Files… didn't add the screenshots, while it's said.
    var filesProblem: ProductPageFilesProblem?
    var toast: ToastMessage?
    var undo: ProductPagesUndo?
    /// Approved pages the person pressed Edit… on: their fields open, and
    /// pushing makes a new version.
    var editingApprovedPageIDs: Set<ProductPage.ID> = []
    /// Languages whose keyword chips are shown although none is chosen.
    var revealedKeywordLocales: Set<String> = []
    /// The last 28 days by page name, from Analytics.
    var numbers: [String: ProductPageNumbers] = [:]
    var numbersThrough: Date?
    /// Screenshot sets by localization ID.
    var screenshotSets: [String: LoadState<[LiveScreenshotSet]>] = [:]
    var isSubmitting = false
    var submitError: AppleErrorCopy?
    /// Push and Submit… pressed: once that page's changes are pushed,
    /// Submit for Review opens on it. By name, since a draft's ID changes
    /// when it's made.
    var submitsAfterPushPageName: String?
    /// Cancel Submission is under way.
    var isCancellingSubmission = false
    /// For DEBUG scenes and tests: Suggest Pages and Ask for Another.
    var onAskAssistant: ((String) -> Void)?
    /// Make Screenshots for This Page… of the page last asked (board 52).
    var pageShots: PageShotsFlow?
    /// Where pages' screenshot runs are kept.
    @ObservationIgnored var pageShotsStudio = PageShotsStudio.shared
    /// Makes a page's flow with the launcher and the app's Screenshots;
    /// the section view gives it.
    @ObservationIgnored var makePageShotsFlow: ((ProductPage) -> PageShotsFlow)?
    @ObservationIgnored var now: () -> Date = { .now }

    init(app: StoreApp, services: any ProductPagesServices, store: ProductPagesStore, queue: ChangeQueue) {
        self.app = app
        self.services = services
        self.store = store
        self.queue = queue
        localeCode = app.primaryLocale ?? "en-US"
    }

    /// The app's icon once it's known: models made (or read ahead) before
    /// the icons arrived would otherwise draw its letter for good.
    func takeIcon(_ icon: AppIcon?) {
        guard let icon, app.icon != icon else { return }
        app.icon = icon
    }

    var builder: ProductPageChangeBuilder { ProductPageChangeBuilder(appID: app.id) }

    var primaryLocale: String { app.primaryLocale ?? defaultPage.locales.first ?? "en-US" }

    // MARK: - Loading

    func load(force: Bool = false) async {
        guard force || state.value == nil, !state.isLoading else { return }
        if state.value == nil { state = .loading }
        do {
            let snapshot = try await services.pages(for: app)
            // A draft that was pushed comes back under its new ID.
            let shownDraft = selectedPage.flatMap { $0.isDraft ? $0.name : nil }
            state = .loaded(snapshot)
            readFailure = nil
            adoptCreatedDrafts(in: snapshot.pages)
            pruneDrafts()
            refreshDraftChanges()
            store.prune(for: app.id, keeping: Set(snapshot.pages.map(\.id)).union(store.drafts(for: app.id).map(\.id)))
            if let id = selectedPageID, page(id) == nil {
                selectedPageID = shownDraft.flatMap { name in pages.first { !$0.isDraft && $0.name == name }?.id }
            }
            tellReviewMoves(in: snapshot)
            pruneChosenFiles()
            queueVisibleWhenApproved()
        } catch {
            let text = AppleErrorCopy(String(localized: "Product pages didn’t load.", comment: "kind:error"), error: error).text
            if state.value == nil { state = .failed(text) } else { readFailure = text }
        }
    }

    /// Drafts whose change left Review & Push without a push are gone; a
    /// pushed one is in App Store Connect now, under its name.
    private func pruneDrafts() {
        let queued = Set(queue.changes(for: app.id, section: .productPages).map(\.id))
        let gone = store.drafts(for: app.id).filter { !queued.contains(builder.newPageChangeID(draftID: $0.id)) }
        if !gone.isEmpty { store.removeDrafts(Set(gone.map(\.id)), for: app.id) }
    }

    /// A draft's queued change is made again from the draft, so one queued
    /// by an older Atlas sends what App Store Connect takes now.
    private func refreshDraftChanges() {
        for draft in store.drafts(for: app.id) {
            let id = builder.newPageChangeID(draftID: draft.id)
            guard let queued = queue.change(id: id), let made = builder.newPageChange(draft, defaultPage: defaultPage),
                  made.requests != queued.requests else { continue }
            queue.upsert(made)
        }
    }

    /// The numbers Analytics has for the last 28 days.
    func setNumbers(from facts: [EngagementFact], reports: ReportsArchive = ReportsArchive()) {
        guard let made = ProductPageNumbers.make(from: facts) else {
            numbers = [:]
            numbersThrough = nil
            return
        }
        var byPage = made.byPage
        ProductPageNumbers.addSubscribers(reports, to: &byPage, through: made.through)
        numbers = byPage
        numbersThrough = made.through.date
    }

    /// Apple's subscription rows name the pages: the list shows subscribers.
    var hasSubscriberNumbers: Bool { numbers.values.contains { $0.subscribers != nil } }

    /// A page's subscribers; nil for a draft or before Apple's report.
    func subscribers(of page: ProductPage) -> SubscriberCounts? {
        guard !page.isDraft else { return nil }
        return numbers[page.name]?.subscribers
    }

    /// Trial → paid of every page together: what a page is compared with.
    var averageTrialToPaid: Double? {
        let all = numbers.values.compactMap(\.subscribers)
        let ended = all.reduce(0) { $0 + $1.trialsEnded }
        return ended > 0 ? Double(all.reduce(0) { $0 + $1.trialConverted }) / Double(ended) : nil
    }

    var snapshot: ProductPagesSnapshot? { state.value }

    /// What App Store Connect has now, changed here without reading it
    /// again (a page just submitted, or taken back).
    func replaceSnapshot(_ snapshot: ProductPagesSnapshot) {
        state = .loaded(snapshot)
    }

    var defaultPage: ProductPageDefault { snapshot?.defaultPage ?? ProductPageDefault() }

    /// Edits are kept while offline and pushed later; making pages needs
    /// App Store Connect.
    var isOffline: Bool { readFailure != nil }

    /// The key can read pages and can't change them.
    var keyCannotChange: Bool { store.archive(for: app.id).keyCannotChange }

    var canChange: Bool { state.value != nil && !keyCannotChange }

    /// New Page… and Suggest Pages.
    var canMakePages: Bool { canChange && !isOffline && !isAtLimit }

    // MARK: - Pages

    /// App Store Connect's pages and the drafts, with names as queued:
    /// visible approved pages, then drafts and pages being prepared, then
    /// rejected, then hidden ones. A page queued for deletion leaves the
    /// list.
    var pages: [ProductPage] {
        let changes = queue.changes(for: app.id, section: .productPages)
        let live = (snapshot?.pages ?? []).compactMap { page -> ProductPage? in
            let edits = builder.edits(for: page.id, in: changes)
            guard !edits.isDeleted else { return nil }
            var shown = page
            if let name = edits.name { shown.name = name }
            return shown
        }
        let all = live + store.drafts(for: app.id).map(\.page)
        return all.enumerated().sorted { lhs, rhs in
            (Self.listGroup(lhs.element), lhs.offset) < (Self.listGroup(rhs.element), rhs.offset)
        }
        .map(\.element)
    }

    private static func listGroup(_ page: ProductPage) -> Int {
        if page.state.isApproved { return page.isVisible ? 0 : 3 }
        return page.state == .rejected ? 2 : 1
    }

    /// The pages the list shows: all, or only the hidden and rejected ones.
    var listedPages: [ProductPage] {
        showsOnlyHiddenAndRejected ? pages.filter { $0.state == .rejected || ($0.state.isApproved && !$0.isVisible) } : pages
    }

    func page(_ id: ProductPage.ID) -> ProductPage? {
        pages.first { $0.id == id }
    }

    var selectedPage: ProductPage? { selectedPageID.flatMap(page) }

    /// "6 of 70": every page counts, drafts too.
    var pageCount: Int { pages.count }

    var isAtLimit: Bool { pageCount >= ProductPagesSnapshot.limit }

    var countText: String { String(localized: "\(pageCount) of \(ProductPagesSnapshot.limit)") }

    /// A page's numbers, when Analytics has them.
    func numbers(of page: ProductPage) -> ProductPageNumbers? {
        guard !page.isDraft, let numbers = numbers[page.name], numbers.impressions > 0 else { return nil }
        return numbers
    }

    var defaultNumbers: ProductPageNumbers? { numbers[ProductPageNumbers.defaultPageName] }

    func comparison(of page: ProductPage) -> ProductPageComparison? {
        guard let numbers = numbers(of: page), let reference = defaultNumbers else { return nil }
        return ProductPageComparison(page: numbers, reference: reference)
    }

    /// "12 languages · 5 keywords".
    func subtitle(of page: ProductPage) -> String {
        let keywords = ProductPageChangeBuilder.keywordCountText(keywordCount(of: page))
        return "\(ReviewText.languages(max(page.locales.count, 1))) · \(keywords)"
    }

    /// The keywords chosen across its languages, queued ones included.
    func keywordCount(of page: ProductPage) -> Int {
        let codes = Set(page.locales).union(edits(of: page).keywords.keys)
        return codes.reduce(0) { $0 + keywords(of: page, locale: $1).count }
    }

    /// "Visible", "Hidden", "Not on the App Store yet", "Not on the App Store".
    func visibilityText(of page: ProductPage) -> String? {
        switch page.state {
        case .approved, .accepted, .replacedWithNewVersion:
            if isVisible(page) { String(localized: "Visible") } else { String(localized: "Hidden") }
        case .prepareForSubmission, .readyForReview: String(localized: "Not on the App Store yet")
        case .rejected: String(localized: "Not on the App Store")
        case .waitingForReview, .inReview: nil
        }
    }

    /// "New version in review".
    func nextVersionText(of page: ProductPage) -> String? {
        guard let next = page.nextVersion else { return nil }
        return String(localized: "New version \(next.state.title.lowercased())")
    }

    // MARK: - Opening

    func open(_ id: ProductPage.ID) {
        selectedPageID = id
        guard let page = page(id) else { return }
        let codes = languages(of: page).map(\.code)
        if !codes.contains(localeCode) { localeCode = codes.first ?? primaryLocale }
    }

    /// Analytics' Open Page: the page Apple's reports call `name`. Returns
    /// whether there is one.
    @discardableResult
    func openPage(named name: String) -> Bool {
        guard let page = pages.first(where: { !$0.isDraft && $0.name == name }) else { return false }
        open(page.id)
        return true
    }

    func back() {
        selectedPageID = nil
        isPushPresented = false
        isSubmitPresented = false
    }

    // MARK: - Undo

    func snapshotForUndo() -> ProductPagesUndo {
        ProductPagesUndo(
            changes: queue.changes(for: app.id, section: .productPages), archive: store.archive(for: app.id), selectedPageID: selectedPageID
        )
    }

    func show(_ text: String, undo: ProductPagesUndo?) {
        self.undo = undo
        toast = ToastMessage(text: text, canUndo: undo != nil)
    }

    func undoLast() {
        guard let undo else { return }
        self.undo = nil
        toast = nil
        let builder = builder
        queue.discardAll { builder.owns($0) }
        queue.upsert(contentsOf: undo.changes)
        store.replace(undo.archive, for: app.id)
        if let id = undo.selectedPageID, page(id) != nil { selectedPageID = id } else if undo.selectedPageID == nil { selectedPageID = nil }
    }

    #if DEBUG
    /// DEBUG scenes and tests: the pages as if just read.
    func load(snapshot: ProductPagesSnapshot) {
        state = .loaded(snapshot)
    }

    /// DEBUG scenes: still reading, or offline after a first read.
    func setDebugState(loading: Bool = false, failure: String? = nil) {
        if loading { state = .loading }
        readFailure = failure
    }
    #endif
}
