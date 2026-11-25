//
//  StoreArtworkDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Board 78 (header and search artwork) as DEBUG scenes
/// (`-AtlasDebugScene <id>`), named after the prototype, on Lumen Journal
/// with `DebugStoreArtwork.live`:
///
/// - `sh2`: Screenshots in English (U.S.): header and search artwork live,
///   the On the App Store preview beside the page with Now · Suggested.
/// - `sh2-de`: German: header live, no search artwork, so the search tile
///   shows screenshots 1–3, marked In search.
/// - `sh2-fr`: French: "No header" and screenshots 1–3.
/// - `sh2-add`: French after Add Header…: New · not pushed, blue outline,
///   the toast with Undo.
/// - `sh2-menu`: German, the page Edit ▾ opens from (a menu opens on a
///   click only).
/// - `sh2-new`: German with its header replaced and search artwork added:
///   Replaced · not pushed and New · not pushed.
/// - `sh2-rp`: Review & Push with German's new header and Japanese's header
///   to be deleted.
/// - `sh2-ipad`: German on iPad: no In search marks.
/// - `sh2-ar`: Arabic, right to left.
/// - `sh2-all`: All Languages, each with its small header and search.
/// - `sp-art`, `sp-art-de`: the Store Page editor's preview with the
///   header and "In search results", in English (U.S.) and German.
/// - `ov-art`: the Overview's preview with them.
enum StoreArtworkDebugScenes {
    static let ids = [
        "sh2", "sh2-de", "sh2-fr", "sh2-add", "sh2-menu", "sh2-new", "sh2-rp", "sh2-ipad", "sh2-ar", "sh2-all",
        "sp-art", "sp-art-de", "ov-art",
    ]

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        switch id {
        case "sp-art": return preview(section: .storePage, locale: .englishUS)
        case "sp-art-de": return preview(section: .storePage, locale: .german)
        case "ov-art": return preview(section: .overview, locale: .englishUS)
        default: break
        }
        return page(presentsReview: id == "sh2-rp") { model in
            model.displayType = .iPhone
            await open(id, model)
        }
    }

    @MainActor
    private static func open(_ id: String, _ model: ScreenshotsViewModel) async {
        let locale: StoreLocale = switch id {
        case "sh2": .englishUS
        case "sh2-fr", "sh2-add": .french
        case "sh2-ar": .arabic
        default: .german
        }
        model.pageLocale = locale
        model.pageShowsAll = id == "sh2-all"
        await model.loadLiveArtwork()
        switch id {
        case "sh2-add":
            await model.addStoreArtwork(DebugStoreArtwork.file(.header, locale: "fr-FR", name: "Lumen header FR.png"), place: .header, locale: "fr-FR")
        case "sh2-new", "sh2-rp":
            await model.addStoreArtwork(DebugStoreArtwork.file(.header, locale: "de-DE", name: "Lumen header DE v2.png"), place: .header, locale: "de-DE")
            if id == "sh2-new" {
                await model.addStoreArtwork(DebugStoreArtwork.file(.search, locale: "de-DE", name: "Lumen search DE.png"), place: .search, locale: "de-DE")
            } else {
                await model.deleteStoreArtwork(.header, locale: "ja")
            }
            model.captionToast = nil
        case "sh2-ipad":
            model.displayType = model.pageDisplays.first { $0 != .iPhone } ?? .iPhone
        default:
            break
        }
    }

    @MainActor
    private static func services() -> DebugScreenshotsServices {
        let screenshots = DebugScreenshotsServices(documentCenter: ScreenshotsDocumentCenter.shared)
        screenshots.storeArtwork = DebugStoreArtwork.live
        screenshots.drawsPushedLiveSets = true
        return screenshots
    }

    @MainActor
    private static func page(presentsReview: Bool, opening: @escaping @MainActor (ScreenshotsViewModel) async -> Void) -> AnyView {
        ScreenshotsDocumentCenter.shared.diskStore = nil
        LiveArtworkMemo.shared.forget(appID: DebugFixtures.AppID.lumen)
        let screenshots = services()
        screenshots.opening = ScreenshotsDebugOpening(opening)
        screenshots.opensLanguagePage = true
        var storePage = DebugStorePageServices()
        storePage.screenshots = screenshots
        var services = WorkspaceServices.debug
        services.storePage = storePage
        return AnyView(DebugMainScene(
            services: services, section: .screenshots, pendingChanges: DebugWorkspace.pendingChanges,
            presentedSheet: presentsReview ? .review : nil
        ))
    }

    @MainActor
    private static func preview(section: AppWorkspaceSection, locale: StoreLocale) -> AnyView {
        LiveArtworkMemo.shared.forget(appID: DebugFixtures.AppID.lumen)
        var storePage = DebugStorePageServices()
        storePage.screenshots = services()
        if section == .storePage {
            storePage.opening = DebugStorePageServices.Opening { $0.openEditor(locale) }
        }
        var services = WorkspaceServices.debug
        services.storePage = storePage
        return AnyView(DebugMainScene(services: services, section: section))
    }
}
#endif
