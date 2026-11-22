//
//  ScreenshotsViewModel+Hand.swift
//  Atlas
//

import CoreGraphics
import Foundation

// Screenshots by hand: on the language page every screenshot can be
// selected, moved, replaced or deleted, files added or a folder imported,
// in one language or every one with its own screenshots. Nothing reaches the
// App Store until the push; each change waits in Review & Push with Undo.
extension ScreenshotsViewModel {
    // MARK: - The set on the page

    /// The screenshots the page lists for a language and device: the set as
    /// changed by hand (deleted ones too), else its own screenshots. A
    /// language that uses the primary one's lists none.
    func handPageItems(locale: String, displayType: ScreenshotDisplayType) -> [ScreenshotHandPageItem] {
        let cells: [ScreenshotCell] = if matrix.isHandRow(locale: locale, displayType: displayType) {
            matrix.pageRow(locale: locale, displayType: displayType)
        } else {
            matrix.row(locale: locale, displayType: displayType).filter { cell in
                cell.state != .fallback && !(cell.state == .uploadedByHand && cell.image == .none)
            }
        }
        return cells.enumerated().map { index, cell in
            let item = ScreenshotHandPageItem(cell: cell, position: index, isSelected: false)
            let selected = handSelection == ScreenshotHandSelection(locale: locale, displayType: displayType, slotID: item.id)
            return ScreenshotHandPageItem(cell: cell, position: index, isSelected: selected)
        }
    }

    /// How many screenshots stay after the push.
    func ownCount(locale: String, displayType: ScreenshotDisplayType) -> Int {
        handPageItems(locale: locale, displayType: displayType).count { !$0.isDeleted }
    }

    /// The languages with screenshots of their own on the device, for
    /// "Every language with its own screenshots (n)".
    func ownLocales(on display: ScreenshotDisplayType) -> [StoreLocale] {
        pageLocales.filter { ownCount(locale: $0.code, displayType: display) > 0 }
    }

    var primaryLocaleName: String { context.primaryLocale.name }

    var isPrimaryPage: Bool { currentPageLocale.code == context.primaryLocale.code }

    /// "iPhone 6.9″ · 1320 × 2868 · 5 of 10. Select a screenshot to …".
    func handDeviceLine(locale: String, displayType: ScreenshotDisplayType) -> String {
        let count = ownCount(locale: locale, displayType: displayType)
        let size = ScreenshotHandSizes.main(on: displayType)
        return String(localized: """
        \(displayType.title) · \(size) · \(count) of \(ScreenshotHandSet.capacity). \
        Select a screenshot to replace, move or delete it, or drop files to add them.
        """)
    }

    /// "Polish uses the English (U.S.) screenshots." and why; nil when the
    /// language has its own.
    func handFallbackBanner(locale: StoreLocale, displayType: ScreenshotDisplayType) -> (title: String, detail: String)? {
        guard locale.code != context.primaryLocale.code, ownCount(locale: locale.code, displayType: displayType) == 0 else { return nil }
        let deletes = handPageItems(locale: locale.code, displayType: displayType).contains(where: \.isDeleted)
        let title = deletes
            ? String(localized: "\(locale.name) will use the \(primaryLocaleName) screenshots once you push.")
            : String(localized: "\(locale.name) uses the \(primaryLocaleName) screenshots.")
        let detail = String(localized: """
        It has no \(displayType.title) screenshots of its own, so the App Store shows the \(primaryLocaleName) ones in \(locale.name).
        """)
        return (title, detail)
    }

    // MARK: - Selection

    var selectedHandItem: ScreenshotHandPageItem? {
        guard let selection = handSelection else { return nil }
        return handPageItems(locale: selection.locale, displayType: selection.displayType).first { $0.id == selection.slotID }
    }

    func selectHand(_ item: ScreenshotHandPageItem) {
        let selection = ScreenshotHandSelection(locale: currentPageLocale.code, displayType: displayType, slotID: item.id)
        handSelection = handSelection == selection ? nil : selection
    }

    /// "Screenshot 2 of 5 · German · iPhone 6.9″".
    func handSelectionTitle(_ item: ScreenshotHandPageItem) -> String {
        let count = handPageItems(locale: item.cell.key.locale, displayType: item.cell.key.displayType).count
        let name = locale(code: item.cell.key.locale)?.name ?? item.cell.key.locale
        return String(localized: "Screenshot \(item.position + 1) of \(count) · \(name) · \(item.cell.key.displayType.title)")
    }

    /// Where it comes from and whether it's live: "Made by Atlas from the
    /// template and its caption · live", "Uploaded by you: a.png · not
    /// pushed".
    func handOrigin(of cell: ScreenshotCell) -> String {
        if cell.state == .willBeDeleted { return String(localized: "Will be deleted when you push") }
        let state = cell.state == .live || cell.state == .uploadedByHand || cell.state == .restored
            ? String(localized: "live") : String(localized: "not pushed")
        switch cell.image {
        case let .hand(file):
            if let client = file.proposedBy { return String(localized: "Suggested by \(client): \(file.fileName) · \(state)") }
            if let from = file.copiedFrom {
                let name = locale(code: from)?.name ?? from
                return String(localized: "Copied from \(name) · \(state)")
            }
            return cell.hand?.isAdded == true
                ? String(localized: "Uploaded by you: \(file.fileName) · \(state)")
                : String(localized: "Replaced by you with \(file.fileName) · \(state)")
        case .render:
            return String(localized: "Made by Atlas from the template and its caption · \(state)")
        case let .live(shot):
            return shot.fileName.isEmpty
                ? String(localized: "On the App Store · \(state)")
                : String(localized: "On the App Store: \(shot.fileName) · \(state)")
        case .none:
            return state
        }
    }

    // MARK: - Moving and undoing

    /// ◀ (−1) or ▶ (+1): swaps it with its neighbor on the page.
    func moveSelectedHand(by offset: Int) async {
        guard let selection = handSelection, let item = selectedHandItem else { return }
        let items = handPageItems(locale: selection.locale, displayType: selection.displayType)
        let target = item.position + offset
        guard items.indices.contains(target) else { return }
        let neighbor = items[target]
        var moved: String?
        await editHand([selection.locale], displayType: selection.displayType, toast: nil) { _, set in
            guard let first = Self.resolve(item.id, in: set), let second = Self.resolve(neighbor.id, in: set) else { return false }
            moved = first
            return set.swap(first, second)
        }
        if let moved { handSelection?.slotID = moved }
    }

    /// Undo Change: the template's render or what's live comes back; one
    /// added by hand goes.
    func undoSelectedHand() async {
        guard let selection = handSelection, let item = selectedHandItem else { return }
        let wasAdded = item.cell.hand?.isAdded == true
        await editHand([selection.locale], displayType: selection.displayType, toast: nil) { _, set in
            guard let id = Self.resolve(item.id, in: set) else { return false }
            return set.undo(id)
        }
        if wasAdded { handSelection = nil }
    }

    // MARK: - Replace, delete, add

    /// Replaces the selected screenshot with `file`, here or in every
    /// language with its own screenshots (the same place in each).
    func replaceHand(slotID: String, with chosen: ScreenshotHandChosenFile, scope: ScreenshotHandScope) async {
        guard let item = handPageItems(locale: currentPageLocale.code, displayType: displayType).first(where: { $0.id == slotID }),
              let file = saveHandFile(chosen) else { return }
        let here = currentPageLocale
        let position = keptPosition(of: item)
        let codes = scope == .every ? ownLocales(on: displayType).map(\.code) : [here.code]
        let count = await editHand(codes, displayType: displayType, toast: { count in
            count > 1
                ? String(localized: "Replaced screenshot \(position + 1) in \(count) languages. It’s waiting in Review & Push.")
                : String(localized: "Replaced screenshot \(position + 1) in \(here.name). It’s waiting in Review & Push.")
        }, edit: { code, set in
            if code == here.code, let id = Self.resolve(item.id, in: set) { return set.replace(id, with: file) }
            return set.replace(position: position, with: file)
        })
        if count > 0 { reselect(position: item.position, locale: here.code) }
    }

    /// Deletes the screenshot when you push; the ones after it move up.
    func deleteHand(slotID: String, scope: ScreenshotHandScope) async {
        guard let item = handPageItems(locale: currentPageLocale.code, displayType: displayType).first(where: { $0.id == slotID }) else { return }
        let here = currentPageLocale
        let position = keptPosition(of: item)
        let codes = scope == .every ? ownLocales(on: displayType).map(\.code) : [here.code]
        await editHand(codes, displayType: displayType, toast: { count in
            count > 1
                ? String(localized: "Screenshot \(position + 1) will be deleted in \(count) languages when you push.")
                : String(localized: "Screenshot \(position + 1) will be deleted in \(here.name) when you push.")
        }, edit: { code, set in
            // Apple needs one screenshot in the primary language.
            if code == self.context.primaryLocale.code, set.keptCount <= 1 { return false }
            if code == here.code, let id = Self.resolve(item.id, in: set) { return set.delete(id) }
            return set.delete(position: position)
        })
        handSelection = nil
    }

    /// The primary language's last screenshot on a device can't go.
    func canDeleteHand(_ item: ScreenshotHandPageItem) -> Bool {
        !(item.cell.key.locale == context.primaryLocale.code && ownCount(locale: item.cell.key.locale, displayType: item.cell.key.displayType) <= 1)
    }

    /// Delete All iPhone 6.9″ Screenshots in German.
    func deleteAllHand() async {
        let here = currentPageLocale
        guard here.code != context.primaryLocale.code else { return }
        let display = displayType
        await editHand([here.code], displayType: display, toast: { _ in
            String(localized: "All \(display.title) screenshots in \(here.name) will be deleted when you push.")
        }, edit: { _, set in
            guard set.keptCount > 0 else { return false }
            set.deleteAll()
            return true
        })
        handSelection = nil
    }

    /// Adds the files that fit after the last screenshot, here or in every
    /// language with its own screenshots, up to 10 in each.
    func addHand(_ chosen: [ScreenshotHandChosenFile], scope: ScreenshotHandScope) async {
        let files = chosen.filter { ScreenshotHandFileCheck($0, on: displayType).fits }.compactMap(saveHandFile)
        guard !files.isEmpty else { return }
        let here = currentPageLocale
        var codes = scope == .every ? ownLocales(on: displayType).map(\.code) : [here.code]
        if !codes.contains(here.code) { codes.append(here.code) }
        var added = 0
        await editHand(codes, displayType: displayType, toast: { count in
            added == 1 && count == 1
                ? String(localized: "Added 1 screenshot to \(here.name). Select it to move it.")
                : count > 1
                ? String(localized: "Added \(added) screenshots in \(count) languages. Select one to move it.")
                : String(localized: "Added \(added) screenshots to \(here.name). Select one to move it.")
        }, edit: { code, set in
            let count = set.add(files)
            if code == here.code { added = count }
            return count > 0
        })
    }

    /// Start from English (U.S.): copies the primary language's screenshots
    /// into this one, as files, to replace one by one.
    func startHandFromPrimary() async {
        let here = currentPageLocale
        let primary = context.primaryLocale
        guard here.code != primary.code else { return }
        var files: [ScreenshotHandFile] = []
        for item in handPageItems(locale: primary.code, displayType: displayType) where !item.isDeleted {
            guard let file = await copyHandFile(item.cell, from: primary.code) else { continue }
            files.append(file)
        }
        guard !files.isEmpty else {
            notice = String(localized: "Atlas couldn’t read the \(primary.name) screenshots to copy them. Try again once they’ve loaded.")
            return
        }
        await editHand([here.code], displayType: displayType, toast: { _ in
            String(localized: "Copied the \(primary.name) screenshots into \(here.name), ready to replace one by one.")
        }, edit: { _, set in
            set.add(files) > 0
        })
    }

    /// Import a Folder: each row replaces its language's screenshots on its
    /// device, or goes after them.
    func importHandFolder(_ rows: [ScreenshotFolderImportRow], mode: ScreenshotFolderImportMode) async {
        guard var document else { return }
        let before = document
        var total = 0
        var languages: Set<String> = []
        for row in rows where row.isReady {
            guard let code = row.localeCode, let display = row.displayType else { continue }
            let files = row.files.compactMap(saveHandFile)
            var set = document.handSetOrStart(locale: code, displayType: display, live: live)
            if mode == .replace {
                set.deleteAll()
            }
            let added = set.add(files)
            guard added > 0 else { continue }
            total += added
            languages.insert(code)
            document.storeHandSet(set, live: live)
        }
        guard total > 0 else { return }
        let text = languages.count == 1
            ? String(localized: "Imported \(total) screenshots into 1 language. They’re waiting in Review & Push.")
            : String(localized: "Imported \(total) screenshots into \(languages.count) languages. They’re waiting in Review & Push.")
        await commitHand(document, before: before, toast: text)
    }

    /// Whether `locale` is on the store page, for Import a Folder.
    func isPageLocale(_ code: String) -> Bool {
        pageLocales.contains { $0.code == code }
    }

    // MARK: - Applying

    /// Edits each language's set on the device and saves them together, with
    /// Undo; `toast` gets how many changed.
    @discardableResult
    func editHand(
        _ codes: [String],
        displayType display: ScreenshotDisplayType,
        toast: ((Int) -> String)?,
        edit: (String, inout ScreenshotHandSet) -> Bool
    ) async -> Int {
        guard var document else { return 0 }
        let before = document
        var count = 0
        for code in codes {
            var set = document.handSetOrStart(locale: code, displayType: display, live: live)
            guard edit(code, &set) else { continue }
            document.storeHandSet(set, live: live)
            count += 1
        }
        guard count > 0 else { return 0 }
        await commitHand(document, before: before, toast: toast?(count))
        return count
    }

    private func commitHand(_ document: ScreenshotsDocument, before: ScreenshotsDocument, toast text: String?) async {
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

    /// A page item's ID in the set: its own, or for a set as it starts the
    /// place at that position.
    static func resolve(_ id: String, in set: ScreenshotHandSet) -> String? {
        guard id.hasPrefix("#") else { return set.index(of: id) == nil ? nil : id }
        guard let position = Int(id.dropFirst()), set.slots.indices.contains(position) else { return nil }
        return set.slots[position].id
    }

    /// Its place among the screenshots that stay.
    private func keptPosition(of item: ScreenshotHandPageItem) -> Int {
        handPageItems(locale: item.cell.key.locale, displayType: item.cell.key.displayType)
            .prefix(item.position).count { !$0.isDeleted }
    }

    private func reselect(position: Int, locale: String) {
        let items = handPageItems(locale: locale, displayType: displayType)
        guard items.indices.contains(position) else { return }
        handSelection = ScreenshotHandSelection(locale: locale, displayType: displayType, slotID: items[position].id)
    }

    private func saveHandFile(_ chosen: ScreenshotHandChosenFile) -> ScreenshotHandFile? {
        guard let size = chosen.pixelSize else { return nil }
        do {
            return try services.handFiles.save(chosen.data, fileName: chosen.fileName, pixelSize: size, appID: app.id)
        } catch {
            notice = String(localized: "Couldn’t keep “\(chosen.fileName)”: \(error.localizedDescription)")
            return nil
        }
    }

    /// A copy of what a primary screenshot shows, as a file: its file, the
    /// render at full size, or the live image.
    private func copyHandFile(_ cell: ScreenshotCell, from code: String) async -> ScreenshotHandFile? {
        let index = cell.key.slot + 1
        let name = "\(locale(code: code)?.name ?? code) \(index).png"
        let image: CGImage?
        switch cell.image {
        case let .hand(file):
            var copy = file
            copy.copiedFrom = code
            return copy
        case let .render(job):
            image = await renderQueue.largeImage(for: job, pixelWidth: job.layout.canvas.pixelSize.width)
        case let .live(shot):
            image = await services.liveImage(shot, pixelWidth: shot.pixelSize?.width ?? pixelSize(for: cell.key.displayType).width)
        case .none:
            image = nil
        }
        guard let image, let data = ScreenshotPNG.data(image) else { return nil }
        let size = PixelSize(width: image.width, height: image.height)
        return try? services.handFiles.save(data, fileName: name, pixelSize: size, appID: app.id, copiedFrom: code)
    }
}
