//
//  ScreenshotMatrixBuilder+Hand.swift
//  Atlas
//

import Foundation

// Rows that aren't the template's slots: live sets in languages and on
// devices Atlas doesn't render (all of their screenshots, however many),
// and sets changed by hand, drawn in the order the person left them.
extension ScreenshotMatrixBuilder {
    func addLiveAndHandRows(to matrix: inout ScreenshotMatrix, snapshot: ScreenshotsSnapshot, engine: ScreenshotLayoutEngine) {
        let document = snapshot.document
        let locales = matrix.localizedLocales + matrix.restoredLocales + matrix.fallbackLocales
        let rendered = Set(document.displays)
        matrix.handDisplays = ScreenshotDisplayType.studio.filter { display in
            guard !rendered.contains(display) else { return false }
            let hasLive = snapshot.live.screenshotSets.contains { $0.displayType == display && !$0.screenshots.isEmpty }
            return hasLive || (document.handSets ?? []).contains { $0.displayType == display }
        }
        for display in document.displays + matrix.handDisplays {
            for code in locales where !document.rendersByTemplate(locale: code, displayType: display) {
                addLiveRow(code, display: display, to: &matrix, snapshot: snapshot)
            }
        }
        for set in document.handSets ?? [] {
            guard let locale = snapshot.locale(code: set.locale) else { continue }
            addHandRow(set, locale: locale, to: &matrix, snapshot: snapshot, engine: engine)
        }
    }

    /// A row Atlas doesn't render: every screenshot of its live set.
    private func addLiveRow(_ code: String, display: ScreenshotDisplayType, to matrix: inout ScreenshotMatrix, snapshot: ScreenshotsSnapshot) {
        guard let set = snapshot.live.set(locale: code, displayType: display) else { return }
        let isPinned = snapshot.document.scope.isPinned(code)
        let template = matrix.slotCount(on: display)
        let isRendered = snapshot.document.displays.contains(display)
        // On a device the template lays out, the row keeps the template's
        // length unless the live set is longer (the Sets grid lines up).
        guard !isRendered || set.screenshots.count > template else { return }
        for (slot, shot) in set.screenshots.enumerated() {
            let key = ScreenshotCellKey(locale: code, displayType: display, slot: slot)
            matrix.cells[key] = ScreenshotCell(
                key: key, state: isPinned ? .restored : .uploadedByHand, image: .live(shot), caption: nil, capture: nil, checks: [],
                showsPrimaryInterface: false, proposal: nil, live: shot
            )
        }
        // Past the end of a shorter live set, nothing shows.
        for slot in set.screenshots.count..<max(set.screenshots.count, template) {
            matrix.cells[ScreenshotCellKey(locale: code, displayType: display, slot: slot)] = nil
        }
        matrix.rowCounts[ScreenshotHandSet.key(locale: code, displayType: display)] = set.screenshots.count
    }

    /// A set changed by hand: its kept places from slot 0 on, and for the
    /// language page every place, the ones that will be deleted too.
    private func addHandRow(
        _ set: ScreenshotHandSet,
        locale: StoreLocale,
        to matrix: inout ScreenshotMatrix,
        snapshot: ScreenshotsSnapshot,
        engine: ScreenshotLayoutEngine
    ) {
        let document = snapshot.document
        let display = set.displayType
        let rowKey = set.id
        let oldCount = matrix.rowCounts[rowKey] ?? matrix.slotCount(on: display)
        for slot in 0..<oldCount {
            matrix.cells[ScreenshotCellKey(locale: set.locale, displayType: display, slot: slot)] = nil
        }
        let liveSet = snapshot.live.set(locale: set.locale, displayType: display)
        let renders = document.rendersByTemplate(locale: set.locale, displayType: display)
        let row = HandRow(locale: locale, renders: renders, liveSet: liveSet)
        var page: [ScreenshotCell] = []
        var position = 0
        for (index, slot) in set.slots.enumerated() {
            let key = ScreenshotCellKey(locale: set.locale, displayType: display, slot: slot.isDeleted ? 100 + index : position)
            guard var cell = handCell(slot, key: key, row: row, snapshot: snapshot, engine: engine) else { continue }
            cell.hand = ScreenshotHandCellInfo(slot: slot, index: index)
            if slot.isDeleted {
                // Only what's live goes: a deleted render never pushed just
                // isn't there any more.
                guard let match = Self.liveMatch(for: cell, in: liveSet, document: document, claimed: []) else { continue }
                cell.live = match
                cell.state = .willBeDeleted
            } else {
                cell.live = liveSet?.screenshot(slot: position)
                matrix.cells[key] = cell
                position += 1
            }
            page.append(cell)
        }
        matrix.rowCounts[rowKey] = position
        matrix.handRows[rowKey] = page
    }

    /// What every place of one hand row shares.
    private struct HandRow {
        var locale: StoreLocale
        /// Whether Atlas renders this language's set from the template.
        var renders: Bool
        var liveSet: LiveScreenshotSet?
    }

    /// One place's cell: its file, the template's render of its slot, or
    /// the live screenshot it was; nil when that's gone.
    private func handCell(
        _ slot: ScreenshotHandSlot,
        key: ScreenshotCellKey,
        row: HandRow,
        snapshot: ScreenshotsSnapshot,
        engine: ScreenshotLayoutEngine
    ) -> ScreenshotCell? {
        let liveSet = row.liveSet
        if let file = slot.file {
            let isLive = liveSet?.screenshots.contains { $0.checksum == file.checksum } ?? false
            return ScreenshotCell(
                key: key, state: isLive ? .live : (slot.isAdded ? .handNew : .handReplaced), image: .hand(file), caption: nil, capture: nil,
                checks: [], showsPrimaryInterface: false, proposal: nil, live: nil
            )
        }
        switch slot.base {
        case let .template(templateSlot):
            guard row.renders, templateSlot < snapshot.document.slotCount(on: key.displayType) else { return nil }
            let baseKey = ScreenshotCellKey(locale: key.locale, displayType: key.displayType, slot: templateSlot)
            var cell = managedCell(baseKey, locale: row.locale, snapshot: snapshot, engine: engine)
            cell.key = key
            // A render moved by hand is live wherever the set has it.
            if case .notPushed = cell.state, Self.isLive(cell, in: liveSet, document: snapshot.document) { cell.state = .live }
            return cell
        case let .live(id, _, _):
            guard let shot = liveSet?.screenshots.first(where: { $0.id == id }) else { return nil }
            let isPinned = snapshot.document.scope.isPinned(key.locale)
            return ScreenshotCell(
                key: key, state: isPinned ? .restored : .uploadedByHand, image: .live(shot), caption: nil, capture: nil, checks: [],
                showsPrimaryInterface: false, proposal: nil, live: shot
            )
        case nil:
            return nil
        }
    }

    /// Whether what the cell shows is in the live set: its file or live
    /// screenshot, or a render Atlas pushed.
    static func isLive(_ cell: ScreenshotCell, in liveSet: LiveScreenshotSet?, document: ScreenshotsDocument) -> Bool {
        liveMatch(for: cell, in: liveSet, document: document, claimed: []) != nil
    }

    /// The live screenshot that is what the cell shows, skipping those
    /// already `claimed` by an earlier place.
    static func liveMatch(for cell: ScreenshotCell, in liveSet: LiveScreenshotSet?, document: ScreenshotsDocument, claimed: Set<String>)
        -> LiveScreenshot?
    {
        guard let shots = liveSet?.screenshots.filter({ !claimed.contains($0.id) }) else { return nil }
        switch cell.image {
        case let .hand(file): return shots.first { $0.checksum == file.checksum }
        case let .live(shot): return shots.first { $0.id == shot.id }
        case let .render(job):
            let checksums = Set(document.pushed.filter {
                $0.renderKey == job.key && $0.cell.locale == cell.key.locale && $0.cell.displayType == cell.key.displayType
            }.map(\.checksum))
            return shots.first { $0.checksum.map(checksums.contains) ?? false }
        case .none: return nil
        }
    }
}
