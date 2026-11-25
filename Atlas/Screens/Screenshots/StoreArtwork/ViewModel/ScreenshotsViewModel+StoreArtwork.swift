//
//  ScreenshotsViewModel+StoreArtwork.swift
//  Atlas
//

import AppKit
import Foundation
import UniformTypeIdentifiers

/// Board 78: each language's product page header and search results
/// artwork on the Screenshots page. What's live is read once and kept
/// (`LiveArtworkMemo`); Add…, Replace… and Delete… change the set's
/// extras, so each change waits in Review & Push with Undo in the toast;
/// Make… opens Autopilot on the artwork.
extension ScreenshotsViewModel {
    /// The memo's key for this app's version.
    var liveArtworkKey: LiveShotsMemo.Key {
        LiveShotsMemo.Key(appID: app.id, localizations: context.localizations)
    }

    /// Reads what's live, at once from the memo when it was read before.
    func loadLiveArtwork(memo: LiveArtworkMemo = .shared) async {
        let key = liveArtworkKey
        if let kept = memo.kept(key), kept != liveArtwork { liveArtwork = kept }
        guard memo.needsRead(key) else { return }
        let read = await memo.read(key) { [services, app, context] in
            try await services.liveArtwork(for: app, localizations: context.localizations)
        }
        guard !Task.isCancelled, let read, read != liveArtwork else { return }
        liveArtwork = read
    }

    /// The header or search artwork of `locale`.
    func storeArtworkSlot(_ place: StoreArtworkPlace, locale: String) -> StoreArtworkSlot {
        StoreArtworkSlot(place: place, locale: locale, live: liveArtwork.image(place, locale: locale), extras: document?.extras)
    }

    /// Where a waiting file is on this Mac, and its loop's movie.
    func storeArtworkFileURL(_ file: ExtrasArtworkFile) -> URL {
        services.extrasFileURL(file.fileID, pathExtension: "png", for: app)
    }

    func storeArtworkLoopURL(_ file: ExtrasArtworkFile) -> URL? {
        file.loop.map { services.extrasFileURL($0.fileID, pathExtension: ExtrasArtworkLoop.pathExtension, for: app) }
    }

    /// The screenshots search shows without artwork: the language's first
    /// three on iPhone (the primary language's when it has none).
    func searchFallbackItems(locale: String) -> [ScreenshotHandPageItem] {
        let own = handPageItems(locale: locale, displayType: .iPhone).filter { !$0.isDeleted }
        let items = own.isEmpty ? handPageItems(locale: context.primaryLocale.code, displayType: .iPhone).filter { !$0.isDeleted } : own
        return Array(items.prefix(StoreArtworkRules.searchShotCount))
    }

    // MARK: - Actions

    /// A row of the tile's menu.
    func perform(_ action: StoreArtworkAction, on slot: StoreArtworkSlot) {
        switch action {
        case .add, .replace:
            chooseStoreArtwork(slot.place, locale: slot.locale)
        case .makeWithAutopilot, .makeNew:
            makeStoreArtworkWithAutopilot()
        case .delete:
            Task { await deleteStoreArtwork(slot.place, locale: slot.locale) }
        case .undo:
            Task { await undoStoreArtwork(slot.place, locale: slot.locale) }
        }
    }

    /// Add Header… or Replace…: one PNG or JPEG.
    func chooseStoreArtwork(_ place: StoreArtworkPlace, locale: String) {
        let panel = NSOpenPanel()
        panel.title = place == .header
            ? String(localized: "Choose a Header", comment: "kind:title")
            : String(localized: "Choose Search Artwork", comment: "kind:title")
        panel.message = String(localized: "\(place.title) for \(localeName(locale)): \(place.fileRule).", comment: "kind:label")
        panel.prompt = String(localized: "Choose File", comment: "kind:button")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg]
        guard panel.runModal() == .OK, let file = ScreenshotHandDrop.files(from: panel.urls).first else { return }
        Task { await addStoreArtwork(file, place: place, locale: locale) }
    }

    /// Keeps the file in the app's Extras folder as a PNG and puts it in
    /// its place. A file that doesn't fit says why instead.
    func addStoreArtwork(_ chosen: ScreenshotHandChosenFile, place: StoreArtworkPlace, locale: String, date: Date = .now) async {
        let check = StoreArtworkFileCheck(chosen, place: place)
        guard check.fits, let size = chosen.pixelSize, var document else {
            notice = check.problem(fileName: chosen.fileName, place: place)
            return
        }
        guard let data = Self.pngData(chosen.data) else {
            notice = StoreArtworkFileCheck.unreadable.problem(fileName: chosen.fileName, place: place)
            return
        }
        let before = document
        let wasLive = liveArtwork.image(place, locale: locale) != nil
        let fileID = ScreenshotPNG.checksum(data)
        do {
            let url = services.extrasFileURL(fileID, pathExtension: "png", for: app)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: url.path) { try data.write(to: url, options: .atomic) }
        } catch {
            notice = AppleErrorCopy(String(localized: "The file wasn’t added.", comment: "kind:error"), error: error).text
            return
        }
        var extras = document.extras ?? .byHand(at: date)
        extras.setHandArtwork(ExtrasArtworkFile(
            kind: place.kind, locale: locale, fileID: fileID, headline: "", fits: true, byteCount: data.count, checks: [],
            byHand: ExtrasArtworkHandFile(fileName: chosen.fileName, pixelSize: size, addedAt: date)
        ))
        document.extras = extras
        let name = localeName(locale)
        let text = wasLive
            ? String(localized: "\(place.title) replaced in \(name). It’s in Review & Push.", comment: "kind:toast")
            : String(localized: "\(place.title) added in \(name). It’s in Review & Push.", comment: "kind:toast")
        await commitStoreArtwork(document, before: before, toast: text)
    }

    /// Delete…: what's live comes off with the next push; a file that isn't
    /// live yet just leaves.
    func deleteStoreArtwork(_ place: StoreArtworkPlace, locale: String, date: Date = .now) async {
        guard var document, var extras = document.extras ?? (liveArtwork.image(place, locale: locale) == nil ? nil : .byHand(at: date)) else { return }
        let before = document
        if liveArtwork.image(place, locale: locale) != nil {
            extras.markRemoval(place, locale: locale, at: date)
        } else {
            extras.undoArtworkChange(place, locale: locale)
        }
        document.extras = extras
        let text = String(localized: "\(place.title) will be deleted in \(localeName(locale)) when you push.", comment: "kind:toast")
        await commitStoreArtwork(document, before: before, toast: text)
    }

    /// Undo Change: back to what's on the App Store.
    func undoStoreArtwork(_ place: StoreArtworkPlace, locale: String) async {
        guard var document, var extras = document.extras else { return }
        let before = document
        extras.undoArtworkChange(place, locale: locale)
        document.extras = extras
        await commitStoreArtwork(document, before: before, toast: nil)
    }

    /// Make with Autopilot… and Make a New One…: Autopilot's guided run on
    /// the artwork, with Claude Design, as the toolbar's Make Artwork….
    func makeStoreArtworkWithAutopilot() {
        tab = .preview
        studio.openGuidedAutopilot(making: .artwork)
    }

    private func commitStoreArtwork(_ document: ScreenshotsDocument, before: ScreenshotsDocument, toast text: String?) async {
        guard document != before else { return }
        await commit(document)
        handRevision += 1
        captionUndo = { [weak self] in
            await self?.commit(before)
            self?.handRevision += 1
        }
        if let text {
            captionToast = ToastMessage(text: text, canUndo: true, actionTitle: String(localized: "Review & Push"))
        }
    }

    private func localeName(_ code: String) -> String {
        StoreLocaleCatalog.locale(code: code)?.name ?? code
    }

    /// A PNG as it is; a JPEG drawn into one, as the push names it .png.
    nonisolated static func pngData(_ data: Data) -> Data? {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return data }
        return ScreenshotPNG.image(data).flatMap(ScreenshotPNG.data)
    }
}
