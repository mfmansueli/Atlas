//
//  ReviewsStore.swift
//  Atlas
//

import Foundation
import Observation

/// Reviews on this Mac: each app's reviews as last read, the replies and
/// groups an assistant suggested, and the translations made. Kept as JSON
/// in Application Support when given a directory; in memory otherwise
/// (tests, DEBUG scenes). The section, the Overview's card, the section
/// picker's count and the MCP tools all read it.
@MainActor
@Observable
final class ReviewsStore {
    static let shared = ReviewsStore(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/Reviews")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    /// How long reviews show before they're read again when opened.
    static let maximumAge: TimeInterval = 15 * 60

    private(set) var settings = ReviewsSettings()
    private var archives: [StoreApp.ID: ReviewsArchive] = [:]
    @ObservationIgnored private let directory: URL?
    @ObservationIgnored var now: () -> Date = { .now }

    init(directory: URL? = nil) {
        self.directory = directory
        guard let directory else { return }
        settings = Self.read(ReviewsSettings.self, at: directory.appending(path: "settings.json")) ?? ReviewsSettings()
    }

    // MARK: - Reading

    func archive(for appID: StoreApp.ID) -> ReviewsArchive {
        if let archive = archives[appID] { return archive }
        let archive = directory.flatMap { Self.read(ReviewsArchive.self, at: Self.file(appID, in: $0)) } ?? ReviewsArchive()
        archives[appID] = archive
        return archive
    }

    /// Never read, or read longer ago than `maximumAge`.
    func isStale(_ appID: StoreApp.ID) -> Bool {
        guard let fetched = archive(for: appID).fetchedAt else { return true }
        return now().timeIntervalSince(fetched) > Self.maximumAge
    }

    /// Suggested replies waiting: the purple count on the section.
    func suggestionCount(for appID: StoreApp.ID) -> Int {
        archive(for: appID).openSuggestionCount
    }

    // MARK: - Settings

    func setTranslates(_ translates: Bool) {
        guard settings.translates != translates else { return }
        settings.translates = translates
        guard let directory else { return }
        Self.write(settings, to: directory.appending(path: "settings.json"))
    }

    /// A reply the person sent reached the App Store: Reply Automatically
    /// may send by itself from now on. Kept once.
    func markReplySentByHand() {
        guard settings.sentReplyByHandAt == nil else { return }
        settings.sentReplyByHandAt = now()
        guard let directory else { return }
        Self.write(settings, to: directory.appending(path: "settings.json"))
    }

    // MARK: - Reviews

    /// The newest reviews, read again: they replace what was kept, and
    /// reviews read earlier that Apple didn't list this time stay after
    /// them (older pages).
    func setFirstPage(_ page: ReviewsPage, currentVersion: String?, for appID: StoreApp.ID) {
        update(appID) { archive in
            let fresh = Set(page.reviews.map(\.id))
            let older = archive.reviews.filter { !fresh.contains($0.id) && ($0.date < (page.reviews.last?.date ?? .distantPast)) }
            let keepsOlder = !older.isEmpty && archive.next != nil || page.next == nil
            archive.reviews = page.reviews + (keepsOlder && page.next != nil ? older : [])
            if !(keepsOlder && page.next != nil) { archive.next = page.next }
            archive.currentVersion = currentVersion ?? archive.currentVersion
            archive.writtenTotal = page.total ?? archive.writtenTotal
            archive.fetchedAt = now()
            archive.prune()
        }
    }

    /// The next, older page.
    func append(_ page: ReviewsPage, for appID: StoreApp.ID) {
        update(appID) { archive in
            let known = Set(archive.reviews.map(\.id))
            archive.reviews += page.reviews.filter { !known.contains($0.id) }
            archive.next = page.next
            archive.writtenTotal = page.total ?? archive.writtenTotal
        }
    }

    /// A reply was sent (or taken back, with nil).
    func setReply(_ reply: ReviewReply?, reviewID: AppReview.ID, for appID: StoreApp.ID) {
        update(appID) { archive in
            guard let index = archive.reviews.firstIndex(where: { $0.id == reviewID }) else { return }
            archive.reviews[index].reply = reply
        }
    }

    // MARK: - Suggestions

    /// An assistant's replies; one for a review that has one replaces it
    /// and comes back if it was dismissed. Replies for reviews not on this
    /// Mac are left out; returns the ones kept.
    @discardableResult
    func add(_ suggestions: [ReviewReplySuggestion], for appID: StoreApp.ID) -> [ReviewReplySuggestion] {
        var kept: [ReviewReplySuggestion] = []
        update(appID) { archive in
            let ids = Set(archive.reviews.map(\.id))
            for suggestion in suggestions where ids.contains(suggestion.reviewID) {
                archive.suggestions[suggestion.reviewID] = suggestion
                archive.dismissed.remove(suggestion.reviewID)
                kept.append(suggestion)
            }
        }
        return kept
    }

    func dismissSuggestion(reviewID: AppReview.ID, for appID: StoreApp.ID) {
        update(appID) { $0.dismissed.insert(reviewID) }
    }

    func restoreSuggestion(reviewID: AppReview.ID, for appID: StoreApp.ID) {
        update(appID) { $0.dismissed.remove(reviewID) }
    }

    /// An assistant's groups; one with an id that's there replaces it.
    func add(_ themes: [ReviewTheme], for appID: StoreApp.ID) {
        update(appID) { archive in
            for theme in themes {
                if let index = archive.themes.firstIndex(where: { $0.id == theme.id }) {
                    archive.themes[index] = theme
                } else {
                    archive.themes.append(theme)
                }
            }
        }
    }

    /// The groups an assistant sent, in place of the ones before.
    func setThemes(_ themes: [ReviewTheme], for appID: StoreApp.ID) {
        update(appID) { $0.themes = themes }
    }

    func keep(_ translations: [AppReview.ID: ReviewTranslation], for appID: StoreApp.ID) {
        guard !translations.isEmpty else { return }
        update(appID) { $0.translations.merge(translations) { _, new in new } }
    }

    #if DEBUG
    /// DEBUG scenes and tests: an app's whole state at once.
    func load(_ archive: ReviewsArchive, for appID: StoreApp.ID) {
        archives[appID] = archive
    }
    #endif

    // MARK: - Files

    private func update(_ appID: StoreApp.ID, _ change: (inout ReviewsArchive) -> Void) {
        var archive = archive(for: appID)
        change(&archive)
        guard archive != archives[appID] else { return }
        archives[appID] = archive
        guard let directory else { return }
        Self.write(archive, to: Self.file(appID, in: directory))
    }

    private static func file(_ appID: StoreApp.ID, in directory: URL) -> URL {
        directory.appending(path: "reviews-\(appID).json")
    }

    private static func read<Value: Decodable>(_ type: Value.Type, at url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private static func write(_ value: some Encodable, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(value).write(to: url, options: .atomic)
    }
}
