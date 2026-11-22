//
//  ReviewsDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// The Reviews section's DEBUG scenes (`-AtlasDebugScene <id>`), one
/// per state on the design's board 38. "Today" is Nov 16, 2026.
///
/// - `rv`: Needs a Reply, each review translated with its suggested reply;
///   `rv-all`: every review; `rv-orig`: the Japanese review as written;
///   `rv-edit`: its suggested reply being edited; `rv-sent`: the German
///   reply just sent; `rv-bulk`: Reply to All about iCloud sync.
/// - `rv-free`: the Free plan (replies by hand, the groups locked).
/// - `rv-s`: the sidebar hidden, for the minimum window.
/// - `rv-none`: an assistant hasn't suggested anything yet; `rv-empty`: no
///   reviews; `rv-error`, `rv-loading`, `rv-refused` (Apple refuses a
///   reply), `rv-download` (Japanese has to be downloaded to translate),
///   and `rv-overview`: the Overview's card.
enum ReviewsDebugScenes {
    typealias AppIDs = DebugFixtures.AppID
    typealias Data = DebugReviewsData

    static let ids = [
        "rv", "rv-all", "rv-orig", "rv-edit", "rv-sent", "rv-bulk", "rv-free", "rv-s", "rv-none", "rv-empty", "rv-error", "rv-loading",
        "rv-refused", "rv-download", "rv-overview",
    ]

    /// The Japanese reply as the person changed it, with the monthly price.
    static let editedDraft = "あたたかいレビューをありがとうございます。月額プラン（¥600）もご用意しています。「設定」→「Lumen Pro」からお選びいただけます。"

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "rv": return scene()
        case "rv-all": return scene(launch: ReviewsDebugLaunch(filter: .all))
        case "rv-orig": return scene(launch: ReviewsDebugLaunch(originals: ["r-jp1"]))
        case "rv-edit": return scene(launch: ReviewsDebugLaunch(editing: "r-jp1", draft: editedDraft))
        case "rv-sent": return scene(launch: ReviewsDebugLaunch(sent: ["r-de1"]))
        case "rv-bulk": return scene(launch: ReviewsDebugLaunch(bulkTheme: "sync"))
        case "rv-free": return scene(isFree: true)
        case "rv-s":
            NavigationDebugLaunch.hidesSidebar = true
            return scene()
        case "rv-overview": return scene(section: .overview)
        default: return stateScene(id)
        }
    }

    @MainActor
    private static func stateScene(_ id: String) -> AnyView? {
        switch id {
        case "rv-none":
            var archive = Data.archive
            archive.suggestions = [:]
            archive.themes = []
            return scene(store: Data.store(archive: archive))
        case "rv-empty":
            return scene(store: Data.store(archive: ReviewsArchive(fetchedAt: Data.today)))
        case "rv-error":
            return scene(store: emptyStore, services: DebugReviewsServices(error: .server(statusCode: 500, detail: "The reviews couldn’t be read.")))
        case "rv-loading":
            return scene(store: emptyStore, services: DebugReviewsServices(neverFinishes: true))
        case "rv-refused":
            return scene(services: DebugReviewsServices(refusesReplies: true))
        case "rv-download":
            var archive = Data.archive
            archive.translations = archive.translations.filter { id, _ in archive.review(id: id)?.languageCode != "ja" }
            return scene(store: Data.store(archive: archive), services: DebugReviewsServices(translator: DebugReviewTranslator(needsDownload: ["ja"])))
        default:
            return nil
        }
    }

    /// Nothing read yet, so the section asks its services.
    @MainActor
    private static var emptyStore: ReviewsStore {
        let store = ReviewsStore()
        store.now = { Data.today }
        return store
    }

    @MainActor
    static func scene(
        store: ReviewsStore? = nil,
        services reviews: DebugReviewsServices = DebugReviewsServices(),
        launch: ReviewsDebugLaunch = ReviewsDebugLaunch(),
        section: AppWorkspaceSection = .reviews,
        isFree: Bool = false
    ) -> AnyView {
        var services = WorkspaceServices.debug
        services.reviews = reviews
        ReviewsDebugLaunch.pending = launch
        return AnyView(DebugMainScene(services: services, selectedAppID: AppIDs.lumen, section: section, reviews: store ?? Data.store(), isFree: isFree))
    }
}
#endif
