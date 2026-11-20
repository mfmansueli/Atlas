//
//  ProductPagesStore.swift
//  Atlas
//

import Foundation
import Observation

/// Product Pages' suggestions and drafts, per app, in
/// `Application Support/Atlas/ProductPages/pages-<appID>.json`: what an
/// assistant suggested over MCP until the person accepts or dismisses it,
/// and the pages made in Atlas until they're pushed. DEBUG scenes and unit
/// tests keep it in memory.
@MainActor
@Observable
final class ProductPagesStore {
    static let shared = ProductPagesStore(directory: sharedDirectory)

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Atlas/ProductPages")
    }

    private static var sharedDirectory: URL? {
        #if DEBUG
        if UnitTestHost.isRunning || DebugScene.requestedID != nil { return nil }
        #endif
        return defaultDirectory
    }

    private var archives: [StoreApp.ID: ProductPagesArchive] = [:]
    @ObservationIgnored private let directory: URL?

    init(directory: URL? = nil) {
        self.directory = directory
    }

    // MARK: - Reading

    func archive(for appID: StoreApp.ID) -> ProductPagesArchive {
        if let archive = archives[appID] { return archive }
        let archive = directory.flatMap { Self.read(at: Self.file(appID, in: $0)) } ?? ProductPagesArchive()
        archives[appID] = archive
        return archive
    }

    func pageSuggestions(for appID: StoreApp.ID) -> [ProductPageSuggestion] {
        archive(for: appID).openPageSuggestions
    }

    func textSuggestions(for appID: StoreApp.ID, pageID: ProductPage.ID? = nil) -> [ProductPageTextSuggestion] {
        archive(for: appID).openTextSuggestions.filter { pageID == nil || $0.pageID == pageID }
    }

    func textSuggestion(for appID: StoreApp.ID, pageID: ProductPage.ID, locale: String) -> ProductPageTextSuggestion? {
        textSuggestions(for: appID, pageID: pageID).first { $0.locale == locale }
    }

    func drafts(for appID: StoreApp.ID) -> [ProductPageDraft] {
        archive(for: appID).drafts
    }

    func draft(for appID: StoreApp.ID, id: ProductPageDraft.ID) -> ProductPageDraft? {
        drafts(for: appID).first { $0.id == id }
    }

    /// The purple count: suggested pages, plus languages with a suggested
    /// text that can be accepted.
    func count(for appID: StoreApp.ID) -> Int {
        let archive = archive(for: appID)
        return archive.openPageSuggestions.count + archive.openTextSuggestions.count { !$0.isRefused }
    }

    // MARK: - Suggestions

    func add(_ suggestion: ProductPageSuggestion, for appID: StoreApp.ID) {
        update(appID) { archive in
            archive.pageSuggestions.removeAll { $0.id == suggestion.id }
            archive.pageSuggestions.append(suggestion)
            archive.dismissed.remove(suggestion.id)
        }
    }

    func add(_ suggestions: [ProductPageTextSuggestion], for appID: StoreApp.ID) {
        update(appID) { archive in
            for suggestion in suggestions {
                archive.textSuggestions.removeAll { $0.id == suggestion.id }
                archive.textSuggestions.append(suggestion)
                archive.dismissed.remove(suggestion.id)
            }
        }
    }

    func dismiss(_ id: String, for appID: StoreApp.ID) {
        update(appID) { $0.dismissed.insert(id) }
    }

    func restore(_ id: String, for appID: StoreApp.ID) {
        update(appID) { $0.dismissed.remove(id) }
    }

    /// Takes suggestions away (accepted), returning them for an undo.
    @discardableResult
    func removeSuggestions(_ ids: Set<String>, for appID: StoreApp.ID) -> (pages: [ProductPageSuggestion], texts: [ProductPageTextSuggestion]) {
        var removed: (pages: [ProductPageSuggestion], texts: [ProductPageTextSuggestion]) = ([], [])
        update(appID) { archive in
            removed.pages = archive.pageSuggestions.filter { ids.contains($0.id) }
            removed.texts = archive.textSuggestions.filter { ids.contains($0.id) }
            archive.pageSuggestions.removeAll { ids.contains($0.id) }
            archive.textSuggestions.removeAll { ids.contains($0.id) }
            archive.dismissed.subtract(ids)
        }
        return removed
    }

    /// Keeps only the text suggestions of pages that are still there.
    func prune(for appID: StoreApp.ID, keeping pageIDs: Set<ProductPage.ID>) {
        update(appID) { archive in
            archive.textSuggestions.removeAll { !pageIDs.contains($0.pageID) }
            let ids = Set(archive.pageSuggestions.map(\.id)).union(archive.textSuggestions.map(\.id))
            archive.dismissed.formIntersection(ids)
        }
    }

    // MARK: - Drafts

    /// Keeps a draft. A new one made from a suggestion takes the texts Atlas
    /// stopped there, so its languages show them as "Not offered".
    func save(_ draft: ProductPageDraft, for appID: StoreApp.ID) {
        update(appID) { archive in
            if let index = archive.drafts.firstIndex(where: { $0.id == draft.id }) {
                archive.drafts[index] = draft
                return
            }
            archive.drafts.append(draft)
            guard let suggestionID = draft.suggestionID,
                  let refused = archive.pageSuggestions.first(where: { $0.id == suggestionID })?.notOfferedTexts
            else { return }
            for var text in refused {
                text.pageID = draft.id
                archive.textSuggestions.removeAll { $0.id == text.id }
                archive.textSuggestions.append(text)
            }
        }
    }

    /// Keeps an accepted suggestion's brief under the page's name.
    func saveBrief(_ brief: ProductPageBrief, pageName: String, for appID: StoreApp.ID) {
        update(appID) { archive in
            var briefs = archive.briefs ?? [:]
            briefs[ProductPageBrief.key(pageName)] = brief
            archive.briefs = briefs
        }
    }

    /// Drops a page's brief: the person deleted the draft it was made for.
    /// A pushed draft keeps it, under the same name.
    func removeBrief(pageName: String, for appID: StoreApp.ID) {
        update(appID) { archive in
            archive.briefs?[ProductPageBrief.key(pageName)] = nil
        }
    }

    func removeDrafts(_ ids: Set<ProductPageDraft.ID>, for appID: StoreApp.ID) {
        update(appID) { archive in
            archive.drafts.removeAll { ids.contains($0.id) }
            archive.textSuggestions.removeAll { ids.contains($0.pageID) }
        }
    }

    /// Puts an app's archive back as it was, for an undo.
    func replace(_ archive: ProductPagesArchive, for appID: StoreApp.ID) {
        update(appID) { $0 = archive }
    }

    // MARK: - Decisions

    func setVisibleWhenApproved(_ isOn: Bool, pageID: String, for appID: StoreApp.ID) {
        update(appID) { archive in
            if isOn { archive.visibleWhenApproved.insert(pageID) } else { archive.visibleWhenApproved.remove(pageID) }
        }
    }

    func setKeyCannotChange(_ value: Bool, for appID: StoreApp.ID) {
        update(appID) { $0.keyCannotChange = value }
    }

    #if DEBUG
    func load(_ archive: ProductPagesArchive, for appID: StoreApp.ID) {
        archives[appID] = archive
    }
    #endif

    // MARK: - Files

    private func update(_ appID: StoreApp.ID, _ change: (inout ProductPagesArchive) -> Void) {
        var archive = archive(for: appID)
        change(&archive)
        guard archive != archives[appID] else { return }
        archives[appID] = archive
        guard let directory else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? encoder.encode(archive).write(to: Self.file(appID, in: directory), options: .atomic)
    }

    private static func file(_ appID: StoreApp.ID, in directory: URL) -> URL {
        directory.appending(path: "pages-\(appID).json")
    }

    private static func read(at url: URL) -> ProductPagesArchive? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ProductPagesArchive.self, from: data)
    }
}
