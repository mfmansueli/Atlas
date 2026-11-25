//
//  ScreenshotsViewModel+AppPreviews.swift
//  Atlas
//

import Foundation

// App Previews by hand (README-Manual): on the language page, iPhone and
// iPad show the language's App Previews to add, replace, move or delete,
// videos the person already has. Checked like App Store Connect checks them
// before anything is queued (MOV, MP4 or M4V, 15 to 30 seconds, at most
// 500 MB, the device's exact size, up to 3), kept on this Mac and queued as
// one change per language and device with Undo. Nothing reaches the App
// Store until the push: uploads, then deletes, then the order.
extension ScreenshotsViewModel {
    /// Whether the device takes App Previews.
    func takesAppPreviews(_ display: ScreenshotDisplayType) -> Bool {
        AppPreviewSpec.displayTypes.contains(display)
    }

    func liveAppPreviews(locale: String, displayType: ScreenshotDisplayType) -> LiveAppPreviewSet? {
        live.previewSets.first { $0.locale == locale && $0.displayType == displayType }
    }

    /// The set as it ends after the push: the queued change's, else what's
    /// live. Nil when the language has no localization on the version.
    func appPreviewSet(locale: String, displayType: ScreenshotDisplayType, queue: ChangeQueue) -> AppPreviewSetPush.Content? {
        if let queued = AppPreviewHandChange.queued(in: queue, appID: app.id, locale: locale, displayType: displayType),
           let content = AppPreviewHandChange.content(of: queued)
        {
            return content
        }
        guard let localizationID = context.localizations.first(where: { $0.key.code == locale })?.value else { return nil }
        return .start(
            appID: app.id, localizationID: localizationID, locale: locale, displayType: displayType,
            live: liveAppPreviews(locale: locale, displayType: displayType)
        )
    }

    /// The App Previews the language page's row starts with, on every
    /// device that has them: the set waiting in Review & Push (iPhone and
    /// iPad, changed by hand), else what's live.
    func pageAppPreviews(locale: String, displayType: ScreenshotDisplayType, queue: ChangeQueue) -> [LanguagePageAppPreview] {
        let queued = takesAppPreviews(displayType)
            ? AppPreviewHandChange.queued(in: queue, appID: app.id, locale: locale, displayType: displayType).flatMap(AppPreviewHandChange.content)
            : nil
        return LanguagePageAppPreviewRow.items(
            queued: queued, live: liveAppPreviews(locale: locale, displayType: displayType), locale: locale, displayType: displayType
        )
    }

    /// "iPhone 6.9″ · 886 × 1920 · 15 to 30 s · 2 of 3".
    func appPreviewLine(_ content: AppPreviewSetPush.Content) -> String {
        let size = AppPreviewSpec.spec(for: content.displayType, landscape: false).map { "\($0.pixelSize.width) × \($0.pixelSize.height)" } ?? ""
        let count = content.slots.count
        let capacity = AppPreviewSetPush.Content.capacity
        return String(localized: "\(content.displayType.title) · \(size) · 15 to 30 s · \(count) of \(capacity)", comment: "kind:caption")
    }

    // MARK: - Choosing

    /// Reads the videos at `urls` (size, length), then adds them, or puts
    /// the first in place of the one at `index`.
    func chooseAppPreviews(
        _ urls: [URL], replacing index: Int? = nil, locale: String, displayType: ScreenshotDisplayType, queue: ChangeQueue,
        folder: ProductPageFilesFolder = .appPreviews
    ) async {
        var videos: [ProductPageChosenVideo] = []
        for url in urls {
            let data = (try? Data(contentsOf: url, options: .mappedIfSafe)) ?? Data()
            let facts = await ProductPagesViewModel.videoFacts(of: url)
            videos.append(ProductPageChosenVideo(fileName: url.lastPathComponent, data: data, pixelSize: facts.size, seconds: facts.seconds))
        }
        addChosenAppPreviews(videos, replacing: index, locale: locale, displayType: displayType, queue: queue, folder: folder)
    }

    /// The videos as read: checked, kept and queued; or every problem said.
    func addChosenAppPreviews(
        _ videos: [ProductPageChosenVideo], replacing index: Int? = nil, locale: String, displayType: ScreenshotDisplayType,
        queue: ChangeQueue, folder: ProductPageFilesFolder = .appPreviews
    ) {
        guard !videos.isEmpty, var content = appPreviewSet(locale: locale, displayType: displayType, queue: queue) else { return }
        let chosen = index == nil ? videos : Array(videos.prefix(1))
        let kept = index == nil ? content.slots.count : content.slots.count - 1
        let problems = ProductPageVideoCheck.problems(chosen, displayType: displayType, kept: kept)
        guard problems.isEmpty else {
            appPreviewProblems = problems
            return
        }
        let saved: [ProductPageScreenshotsPush.File]
        do {
            saved = try folder.save(chosen, appID: app.id)
        } catch {
            appPreviewProblems = [AppleErrorCopy(String(localized: "The App Previews couldn’t be copied.", comment: "kind:error"), error: error).text]
            return
        }
        let name = self.locale(code: locale)?.name ?? locale
        let text: String
        if let index, let file = saved.first {
            content.replace(at: index, with: file)
            text = String(localized: "Replaced App Preview \(index + 1) in \(name). In Review & Push.", comment: "kind:toast")
        } else {
            let added = content.add(saved)
            text = added == 1
                ? String(localized: "Added 1 App Preview to \(name). In Review & Push.", comment: "kind:toast")
                : String(localized: "Added \(added) App Previews to \(name). In Review & Push.", comment: "kind:toast")
        }
        store(content, queue: queue, toast: text, folder: folder)
    }

    // MARK: - Delete and move

    func deleteAppPreview(at index: Int, locale: String, displayType: ScreenshotDisplayType, queue: ChangeQueue) {
        guard var content = appPreviewSet(locale: locale, displayType: displayType, queue: queue), content.delete(at: index) else { return }
        let name = self.locale(code: locale)?.name ?? locale
        store(content, queue: queue, toast: String(
            localized: "App Preview \(index + 1) will be deleted in \(name) when you push.", comment: "kind:toast"
        ))
    }

    func moveAppPreview(at index: Int, by offset: Int, locale: String, displayType: ScreenshotDisplayType, queue: ChangeQueue) {
        guard var content = appPreviewSet(locale: locale, displayType: displayType, queue: queue), content.move(at: index, by: offset) else { return }
        store(content, queue: queue, toast: nil)
    }

    // MARK: - Queueing

    /// Queues the set in place of the one before (or takes it out when it's
    /// what's live again), with Undo.
    private func store(_ content: AppPreviewSetPush.Content, queue: ChangeQueue, toast text: String?, folder: ProductPageFilesFolder = .appPreviews) {
        let id = AppPreviewHandChange.id(appID: app.id, locale: content.locale, displayType: content.displayType)
        let before = queue.change(id: id)
        let live = liveAppPreviews(locale: content.locale, displayType: content.displayType)
        if content.isUnchanged(from: live) {
            queue.discard(id: id)
        } else {
            let name = locale(code: content.locale)?.name ?? content.locale
            queue.upsert(AppPreviewHandChange.change(content, localeName: name, liveCount: live?.previews?.count ?? live?.previewCount ?? 0))
        }
        appPreviewProblems = []
        captionUndo = { [weak self] in
            if let before { queue.upsert(before) } else { queue.discard(id: id) }
            self?.pruneAppPreviewFiles(queue: queue, folder: folder)
        }
        if let text {
            captionToast = ToastMessage(text: text, canUndo: true, actionTitle: String(localized: "Review & Push"))
        }
    }

    /// Deletes kept videos no queued change reads any more. The folder's
    /// files of a change Undo can bring back stay until the next change.
    func pruneAppPreviewFiles(queue: ChangeQueue, folder: ProductPageFilesFolder = .appPreviews) {
        let paths = queue.changes(for: app.id, section: .screenshots).compactMap(AppPreviewHandChange.content).reduce(into: Set<String>()) {
            $0.formUnion($1.filePaths)
        }
        folder.prune(appID: app.id, keeping: paths)
    }
}
