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
    let app: StoreApp
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
    var isPushPresented = false
    var isSubmitPresented = false
    var confirmation: ProductPageConfirmation?
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
    var submitError: String?
    /// For DEBUG scenes and tests: Suggest Pages and Ask for Another.
    var onAskAssistant: ((String) -> Void)?
    @ObservationIgnored var now: () -> Date = { .now }

    init(app: StoreApp, services: any ProductPagesServices, store: ProductPagesStore, queue: ChangeQueue) {
        self.app = app
        self.services = services
        self.store = store
        self.queue = queue
        localeCode = app.primaryLocale ?? "en-US"
    }

    var builder: ProductPageChangeBuilder { ProductPageChangeBuilder(appID: app.id) }

    var primaryLocale: String { app.primaryLocale ?? defaultPage.locales.first ?? "en-US" }

    // MARK: - Loading

    func load(force: Bool = false) async {
        guard force || state.value == nil, !state.isLoading else { return }
        if state.value == nil { state = .loading }
        do {
            let snapshot = try await services.pages(for: app)
            state = .loaded(snapshot)
            readFailure = nil
            pruneDrafts()
            store.prune(for: app.id, keeping: Set(snapshot.pages.map(\.id)).union(store.drafts(for: app.id).map(\.id)))
            if let id = selectedPageID, page(id) == nil { selectedPageID = nil }
        } catch {
            if state.value == nil { state = .failed(error.localizedDescription) } else { readFailure = error.localizedDescription }
        }
    }

    /// Drafts whose change left Review & Push without a push are gone; a
    /// pushed one is in App Store Connect now, under its name.
    private func pruneDrafts() {
        let queued = Set(queue.changes(for: app.id, section: .productPages).map(\.id))
        let gone = store.drafts(for: app.id).filter { !queued.contains(builder.newPageChangeID(draftID: $0.id)) }
        if !gone.isEmpty { store.removeDrafts(Set(gone.map(\.id)), for: app.id) }
    }

    /// The numbers Analytics has for the last 28 days.
    func setNumbers(from facts: [EngagementFact]) {
        guard let made = ProductPageNumbers.make(from: facts) else {
            numbers = [:]
            numbersThrough = nil
            return
        }
        numbers = made.byPage
        numbersThrough = made.through.date
    }

    var snapshot: ProductPagesSnapshot? { state.value }

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
            isVisible(page) ? String(localized: "Visible") : String(localized: "Hidden")
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
