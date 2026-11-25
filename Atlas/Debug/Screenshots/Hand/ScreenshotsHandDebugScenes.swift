//
//  ScreenshotsHandDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Screenshots by hand as DEBUG scenes (`-AtlasDebugScene <id>`), on
/// Lumen Journal's language page in German unless said:
///
/// - `hand-page`: the set, nothing selected: "iPhone 6.9″ · 1320 × 2868 ·
///   5 of 10…" and the Add Screenshots tile.
/// - `hand-select`: screenshot 2 selected, its bar above the set.
/// - `hand-changed`: screenshot 2 replaced by a file, screenshot 4 deleted,
///   one file added at the end; screenshot 2 selected.
/// - `hand-fallback`: a language with none of its own: "… uses the English
///   (U.S.) screenshots", Start from English (U.S.) and Add Its Own….
/// - `hand-replace`, `hand-replace-wrong`: Replace Screenshot 2 with a file
///   that fits, or one of the wrong size.
/// - `hand-delete`, `hand-delete-all`: Delete Screenshot 2?, Delete All
///   iPhone 6.9″ Screenshots in German?.
/// - `hand-add`: Add Screenshots with two files that fit and one that
///   doesn't.
/// - `hand-import`: Import a Folder before a folder is chosen.
/// - `hand-proposal`: Claude Code's file for screenshot 3, to accept.
/// - `hand-removal`, `hand-order`: Claude Code suggests deleting
///   screenshots 2 and 4, or the order 3, 1, 2, 4, 5, to accept.
/// - `hand-mac-first`: the app has a macOS version but no Mac captures or
///   set yet: Mac is chosen in the device picker, with Add Screenshots.
enum ScreenshotsHandDebugScenes {
    static let ids = [
        "hand-page", "hand-select", "hand-changed", "hand-fallback", "hand-replace", "hand-replace-wrong", "hand-delete",
        "hand-delete-all", "hand-add", "hand-import", "hand-proposal", "hand-removal", "hand-order",
        "hand-mac-first",
    ]

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        return scene { model in
            model.pageLocale = StoreLocaleCatalog.locale(code: "de-DE")
            model.displayType = .iPhone
            await open(id, model)
        }
    }

    @MainActor
    private static func open(_ id: String, _ model: ScreenshotsViewModel) async {
        switch id {
        case "hand-select":
            select(model, position: 1)
        case "hand-changed":
            await change(model)
        case "hand-fallback":
            if let fallback = model.pageLocales.first(where: { model.handFallbackBanner(locale: $0, displayType: .iPhone) != nil }) {
                model.pageLocale = fallback
            } else {
                // Every sample language has its own set: German's goes, as
                // Delete All would, so it falls back to the primary's.
                await model.deleteAllHand()
                model.captionToast = nil
            }
        case "hand-proposal":
            await propose(model)
        case "hand-mac-first":
            var context = model.context
            context.hasMacVersion = true
            await model.update(context: context)
            model.displayType = .mac
        case "hand-removal":
            await arrange(model, .removal, positions: [1, 3])
        case "hand-order":
            await arrange(model, .order, positions: [2, 0, 1, 3, 4])
        default:
            guard let (position, sheet) = sheet(for: id) else { return }
            if let position { select(model, position: position) }
            model.handSheet = sheet
        }
    }

    /// A scene's open sheet, and the screenshot selected under it.
    @MainActor
    private static func sheet(for id: String) -> (position: Int?, sheet: ScreenshotHandSheet)? {
        switch id {
        case "hand-replace":
            (1, .replace(slotID: "#1", file: ScreenshotsHandDebugFiles.fitting("Lumen-de-02.png")))
        case "hand-replace-wrong":
            (1, .replace(slotID: "#1", file: ScreenshotsHandDebugFiles.wrongSize()))
        case "hand-delete":
            (1, .delete(slotID: "#1"))
        case "hand-delete-all":
            (nil, .deleteAll)
        case "hand-add":
            (nil, .add([
                ScreenshotsHandDebugFiles.fitting("Lumen-de-06.png", hue: 1), ScreenshotsHandDebugFiles.fitting("Lumen-de-07.png", hue: 2),
                ScreenshotsHandDebugFiles.wrongSize("IMG_0412.PNG"),
            ]))
        case "hand-import":
            (nil, .importFolder)
        default:
            nil
        }
    }

    @MainActor
    private static func select(_ model: ScreenshotsViewModel, position: Int) {
        model.handSelection = ScreenshotHandSelection(locale: "de-DE", displayType: .iPhone, slotID: "#\(position)")
    }

    /// Replaces 2, deletes 4 and adds a file, as a person would.
    @MainActor
    private static func change(_ model: ScreenshotsViewModel) async {
        select(model, position: 1)
        await model.replaceHand(slotID: "#1", with: ScreenshotsHandDebugFiles.fitting("Lumen-de-02.png"), scope: .one)
        let items = model.handPageItems(locale: "de-DE", displayType: .iPhone)
        if items.indices.contains(3) { await model.deleteHand(slotID: items[3].id, scope: .one) }
        await model.addHand([ScreenshotsHandDebugFiles.fitting("Lumen-de-06.png", hue: 2)], scope: .one)
        if let replaced = model.handPageItems(locale: "de-DE", displayType: .iPhone).first(where: { $0.cell.image.handFile != nil }) {
            model.handSelection = ScreenshotHandSelection(locale: "de-DE", displayType: .iPhone, slotID: replaced.id)
        }
        model.captionToast = nil
    }

    @MainActor
    private static func propose(_ model: ScreenshotsViewModel) async {
        let chosen = ScreenshotsHandDebugFiles.fitting("Lumen-de-03-darker.png", hue: 3)
        guard var document = model.document, let size = chosen.pixelSize,
              var file = try? model.services.handFiles.save(chosen.data, fileName: chosen.fileName, pixelSize: size, appID: model.app.id)
        else { return }
        file.proposedBy = "Claude Code"
        let proposal = ScreenshotHandProposal(
            id: "hp1", client: "Claude Code", receivedAt: .now, locale: "de-DE", displayType: .iPhone, position: 2, file: file,
            reason: "The darker Week screen reads better behind the German caption, which is longer than the English one."
        )
        document.handProposals = [proposal]
        await model.commit(document)
    }

    /// Claude Code's removal or order of German's template-made set, by
    /// 0-based position.
    @MainActor
    private static func arrange(_ model: ScreenshotsViewModel, _ action: ScreenshotHandArrangement.Action, positions: [Int]) async {
        guard var document = model.document else { return }
        let set = document.handSetOrStart(locale: "de-DE", displayType: .iPhone, live: model.live)
        let places = ScreenshotHandPlace.kept(in: set)
        let reason = action == .removal
            ? "Screens 2 and 4 show the same week view; German reviewers mention neither."
            : "German reviews talk about search first, so the Search screen should lead."
        document.handArrangements = [ScreenshotHandArrangement(
            id: "ha1", client: "Claude Code", receivedAt: .now, locale: "de-DE", displayType: .iPhone, action: action,
            places: positions.filter(places.indices.contains).map { places[$0] }, reason: reason,
            evidence: [SuggestionEvidence(kind: "review", ref: "App Store reviews, de-DE, last 90 days")]
        )]
        await model.commit(document)
    }

    @MainActor
    private static func scene(opening: @escaping @MainActor (ScreenshotsViewModel) async -> Void) -> AnyView {
        let center = ScreenshotsDocumentCenter.shared
        center.diskStore = nil
        let screenshots = DebugScreenshotsServices(opening: ScreenshotsDebugOpening(opening), documentCenter: center)
        screenshots.opensLanguagePage = true
        var storePage = DebugStorePageServices()
        storePage.screenshots = screenshots
        var services = WorkspaceServices.debug
        services.storePage = storePage
        return AnyView(DebugMainScene(services: services, section: .screenshots, pendingChanges: DebugWorkspace.pendingChanges))
    }
}
#endif
