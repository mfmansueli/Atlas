//
//  ScreenshotsViewModel+HandArrangements.swift
//  Atlas
//

import Foundation

// Screenshots an assistant suggested deleting, or a new order for a set
// (propose_screenshot_removal, propose_screenshot_order), on the language
// page beside the suggested files: Accept deletes or moves them as Delete…
// and ◀ ▶ do, waiting in Review & Push; Dismiss drops the suggestion.
extension ScreenshotsViewModel {
    /// The removals and orders waiting for a language on a device.
    func handArrangements(locale: String, displayType: ScreenshotDisplayType) -> [ScreenshotHandArrangement] {
        (document?.handArrangements ?? []).filter { $0.isWaiting && $0.locale == locale && $0.displayType == displayType }
    }

    /// "Delete screenshots 2 and 4", "New order: 3, 1, 2, 4, 5".
    func handArrangementTitle(_ arrangement: ScreenshotHandArrangement) -> String {
        switch arrangement.action {
        case .removal where arrangement.places.count == 1:
            String(localized: "Delete screenshot \(arrangement.numbers)")
        case .removal:
            String(localized: "Delete screenshots \(arrangement.numbers)")
        case .order:
            String(localized: "New order: \(arrangement.numbers)")
        }
    }

    /// The page's cells for the screenshots it names, in its order; nil
    /// for one that isn't in the set any more.
    func handArrangementCells(_ arrangement: ScreenshotHandArrangement) -> [ScreenshotCell?] {
        guard let document else { return arrangement.places.map { _ in nil } }
        let saved = document.handSet(locale: arrangement.locale, displayType: arrangement.displayType)
        let set = saved ?? document.handSetOrStart(locale: arrangement.locale, displayType: arrangement.displayType, live: live)
        let kept = set.kept
        let items = handPageItems(locale: arrangement.locale, displayType: arrangement.displayType).filter { !$0.isDeleted }
        return arrangement.places.map { place in
            guard let index = kept.firstIndex(where: place.matches) else { return nil }
            // A set changed by hand names its places; one as it starts has
            // them in the same order as the page.
            if saved != nil { return items.first { $0.cell.hand?.slotID == kept[index].id }?.cell }
            return items.indices.contains(index) ? items[index].cell : nil
        }
    }

    func acceptHandArrangement(_ arrangement: ScreenshotHandArrangement) async {
        guard var document else { return }
        let before = document
        let set = document.handSetOrStart(locale: arrangement.locale, displayType: arrangement.displayType, live: live)
        let isPrimary = arrangement.locale == context.primaryLocale.code
        let changed: ScreenshotHandSet
        switch arrangement.applied(to: set, isPrimary: isPrimary) {
        case let .success(set):
            changed = set
        case .failure(.lastPrimary):
            notice = String(localized: """
            \(context.primaryLocale.name) is the primary language, and Apple needs at least one \(arrangement.displayType.title) screenshot in it.
            """)
            return
        case .failure(.unchanged):
            notice = String(localized: "The set is already like that. Dismiss the suggestion.")
            return
        case .failure(.changed):
            notice = String(localized: "The set changed since \(arrangement.client) suggested this. Dismiss it and ask again.")
            return
        }
        document.storeHandSet(changed, live: live)
        decide(arrangement.id, status: .accepted, in: &document)
        handSelection = nil
        let name = locale(code: arrangement.locale)?.name ?? arrangement.locale
        let text = switch arrangement.action {
        case .removal where arrangement.places.count == 1:
            String(localized: "Screenshot \(arrangement.numbers) will be deleted in \(name) when you push.")
        case .removal:
            String(localized: "Screenshots \(arrangement.numbers) will be deleted in \(name) when you push.")
        case .order:
            String(localized: "\(name)’s screenshots are in \(arrangement.client)’s order. It’s waiting in Review & Push.")
        }
        await commit(document)
        handRevision += 1
        captionUndo = { [weak self] in
            await self?.commit(before)
            self?.handRevision += 1
        }
        captionToast = ToastMessage(text: text, canUndo: true, actionTitle: String(localized: "Review & Push"))
    }

    func dismissHandArrangement(_ arrangement: ScreenshotHandArrangement) async {
        guard var document else { return }
        let before = document
        decide(arrangement.id, status: .rejected, in: &document)
        await commit(document)
        captionUndo = { [weak self] in await self?.commit(before) }
        captionToast = ToastMessage(text: String(localized: "\(arrangement.client)’s suggestion dismissed."), canUndo: true)
    }

    private func decide(_ id: String, status: ScreenshotProposalStatus, in document: inout ScreenshotsDocument) {
        guard var arrangements = document.handArrangements, let index = arrangements.firstIndex(where: { $0.id == id }) else { return }
        arrangements[index].status = status
        arrangements[index].decidedAt = .now
        document.handArrangements = arrangements
    }
}
