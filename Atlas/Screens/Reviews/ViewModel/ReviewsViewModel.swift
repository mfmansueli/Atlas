//
//  ReviewsViewModel.swift
//  Atlas
//

import Foundation
import Observation

/// The Reviews section's state for one app: what the list shows, the
/// replies being written and sent, Reply to All, and the translations.
/// The reviews, suggested replies and groups themselves live in
/// `ReviewsStore`, which the Overview's card, the section's count and the
/// assistants' tools read too.
@MainActor
@Observable
final class ReviewsViewModel {
    let app: StoreApp
    let store: ReviewsStore
    let services: any ReviewsServices
    /// Reply Automatically's rule and queue (board 58).
    var autoReply: AutoReplyCenter = .shared
    /// Reply Automatically… (board 58 · 2).
    var isAutoReplySettingsPresented = false
    /// Its History (board 58 · 5).
    var isAutoReplyHistoryPresented = false

    // MARK: - Loading

    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var errorMessage: String?
    private(set) var ratings = StoreRatings.unchecked
    /// The storefronts `ratings` was read for.
    private(set) var ratingCountries: Set<String> = []

    // MARK: - What the list shows

    var filter: ReviewFilter = .needsReply {
        didSet { if filter != oldValue { filterDidChange() } }
    }

    /// A group's reviews only ("Show Reviews"); nil shows every group.
    var themeFilter: ReviewTheme.ID? {
        didSet { if themeFilter != oldValue { filterDidChange() } }
    }

    /// One storefront only (alpha-2); nil is All Countries.
    var territoryFilter: String? {
        didSet { if territoryFilter != oldValue { filterDidChange() } }
    }

    var sort: ReviewSort = .newest
    /// How many of the matching reviews the list shows; Show More adds a page.
    var shownLimit = ReviewsViewModel.pageSize
    static let pageSize = 20
    /// Suggested replies, Reply to All and the groups are Pro; the view
    /// sets it from the gate.
    var isPro = true
    /// Reviews answered or dismissed since the filter was chosen: they
    /// stay in the list, so the reply and its Edit don't vanish on Send.
    var keptVisible: Set<AppReview.ID> = []
    /// Per-review Show Original / Show Translation, against the switch.
    var translationOverrides: [AppReview.ID: Bool] = [:]

    // MARK: - Replying

    /// The review whose reply is being written.
    var editingID: AppReview.ID?
    var drafts: [AppReview.ID: String] = [:]
    var sending: Set<AppReview.ID> = []
    var replyErrors: [AppReview.ID: String] = [:]
    /// Replies sent since the section opened: "You replied Nov 16…".
    var sentNow: Set<AppReview.ID> = []
    var toast: ToastMessage?
    var undo: ReviewReplyUndo?

    // MARK: - Reply to All

    var bulkPlan: ReviewBulkPlan?
    /// The ticked languages of `bulkPlan`.
    var bulkSelection: Set<String> = []
    var bulkProgress: ReviewBulkProgress?

    // MARK: - Translation

    /// Languages Apple Translation has to download before their reviews
    /// can be translated.
    var languagesToDownload: [String] = []
    var isTranslating = false

    @ObservationIgnored var now: () -> Date = { .now }

    init(app: StoreApp, store: ReviewsStore, services: any ReviewsServices) {
        self.app = app
        self.store = store
        self.services = services
    }

    // MARK: - Reading

    var archive: ReviewsArchive { store.archive(for: app.id) }

    var reviews: [AppReview] { archive.reviews }

    var hasLoaded: Bool { archive.fetchedAt != nil }

    var translates: Bool { store.settings.translates }

    /// The list: the filter, the group and the storefront, in the chosen
    /// order.
    var shownReviews: [AppReview] {
        let themeIDs = themeFilter.flatMap { id in archive.themes.first { $0.id == id } }.map { Set($0.reviewIDs) }
        let matching = reviews.filter { review in
            if let territoryFilter, review.territory != territoryFilter { return false }
            if let themeIDs { return themeIDs.contains(review.id) }
            return filter.includes(review) || keptVisible.contains(review.id)
        }
        return sort.sorted(matching)
    }

    /// The chip's count; only Needs a Reply has one.
    func count(for filter: ReviewFilter) -> Int? {
        guard filter == .needsReply else { return nil }
        let count = archive.needsReplyCount
        return count > 0 ? count : nil
    }

    /// The storefronts with reviews, most reviews first, for All Countries.
    var territories: [(code: String, count: Int)] {
        Dictionary(grouping: reviews.filter { !$0.territory.isEmpty }, by: \.territory)
            .map { (code: $0.key, count: $0.value.count) }
            .sorted { $0.count == $1.count ? $0.code < $1.code : $0.count > $1.count }
    }

    var selectedTheme: ReviewTheme? {
        themeFilter.flatMap { id in archive.themes.first { $0.id == id } }
    }

    var emptyText: String {
        if themeFilter == nil, territoryFilter == nil, filter == .needsReply, !reviews.isEmpty {
            return String(localized: "Every review that needs a reply has one.")
        }
        return String(localized: "No reviews here.")
    }

    /// The suggested reply a review shows: Pro, no reply yet, not
    /// dismissed, not being edited.
    func suggestion(for review: AppReview) -> ReviewReplySuggestion? {
        guard isPro, editingID != review.id else { return nil }
        return archive.openSuggestion(for: review)
    }

    func isDismissed(_ review: AppReview) -> Bool {
        isPro && !review.hasReply && archive.dismissed.contains(review.id) && archive.suggestions[review.id] != nil
    }

    /// Suggested replies waiting, for the section's count: none in Free.
    var suggestionCount: Int {
        isPro ? archive.openSuggestionCount : 0
    }

    var ratingsSummary: RatingsSummary {
        RatingsSummary.make(ratings: ratings, countries: ratingCountries, reviews: reviews, version: archive.currentVersion, now: now())
    }

    var themeSummaries: [ReviewThemeSummary] {
        archive.themes.map { ReviewThemeSummary.make($0, reviews: reviews) }.filter { $0.count > 0 }
    }

    /// Who suggested the replies and groups, for the source chip.
    var suggestionSource: String? {
        archive.themes.first?.source ?? archive.suggestions.values.first?.source
    }

    // MARK: - Loading

    /// Reads the newest reviews when they're old (or `force`), then the
    /// ratings and the translations.
    func load(force: Bool = false) async {
        if force || store.isStale(app.id) {
            isLoading = true
            do {
                let page = try await services.reviews(for: app, after: nil)
                let version = try? await services.currentVersion(for: app)
                store.setFirstPage(page, currentVersion: version ?? nil, for: app.id)
                errorMessage = nil
            } catch {
                errorMessage = AppleErrorCopy(String(localized: "Reviews didn’t load.", comment: "kind:error"), error: error).text
            }
            isLoading = false
        }
        await loadRatings()
        await translate()
    }

    /// The next, older reviews.
    func loadMore() async {
        guard let next = archive.next, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            try await store.append(services.reviews(for: app, after: next), for: app.id)
            errorMessage = nil
        } catch {
            errorMessage = AppleErrorCopy(String(localized: "Older reviews didn’t load.", comment: "kind:error"), error: error).text
        }
        await translate()
    }

    var canLoadMore: Bool { archive.next != nil }

    /// Storefronts asked for their rating: the ones with reviews, most
    /// reviews first, and the United States.
    static let ratingCountryLimit = 40

    private func loadRatings() async {
        var countries = Set(territories.prefix(Self.ratingCountryLimit).map(\.code))
        countries.insert("US")
        ratings = await services.ratings(for: app, countries: countries)
        ratingCountries = countries
    }

    private func filterDidChange() {
        keptVisible = []
        editingID = nil
        shownLimit = Self.pageSize
    }

    /// The matching reviews the list has room for right now.
    var listedReviews: [AppReview] {
        Array(shownReviews.prefix(shownLimit))
    }

    /// Matching reviews on this Mac that the list doesn't show yet.
    var hiddenCount: Int {
        max(0, shownReviews.count - shownLimit)
    }

    /// "18 more need a reply", "18 more".
    var showMoreTitle: String {
        themeFilter == nil && filter == .needsReply
            ? String(localized: "\(hiddenCount) more need a reply")
            : String(localized: "\(hiddenCount) more")
    }

    func showMore() {
        shownLimit += Self.pageSize
    }

    /// The group a review's card names: the first that isn't praise.
    func theme(of review: AppReview) -> ReviewTheme? {
        archive.themes.first { $0.action != .suggestStorePage && $0.reviewIDs.contains(review.id) }
    }

    /// "Show Reviews" on a group, and × on its pill.
    func show(_ theme: ReviewTheme?) {
        themeFilter = theme?.id
    }
}
