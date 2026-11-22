//
//  ScreenshotHandPlanner.swift
//  Atlas
//

import Foundation

/// What a push sends for the sets changed by hand: for each place, the
/// screenshot already live that stays there (moved if needed) or what's
/// uploaded into it (a file given by hand, or a render the template makes);
/// every live screenshot no place keeps is deleted; and, when only the
/// order changed, the new order. Pure; `ScreenshotPushPlanner` runs it.
struct ScreenshotHandPlanner {
    struct Result {
        var groups: [ScreenshotPlanGroup] = []
        var kept: [ScreenshotPlanItem] = []
        var excluded: [ScreenshotPlanExclusion] = []
    }

    func plan(_ input: ScreenshotPlanInput, matrix: ScreenshotMatrix, snapshot: ScreenshotsSnapshot) -> Result {
        var result = Result()
        for set in input.document.handSets ?? [] {
            // A restore queued for the language puts its kept screenshots back instead.
            guard input.state.restore(for: set.locale) == nil, let locale = snapshot.locale(code: set.locale) else { continue }
            plan(set, locale: locale, input: input, matrix: matrix, into: &result)
        }
        return result
    }

    /// One set's plan while it's made: what's kept where, what uploads,
    /// and the renders that failed their checks.
    private struct Draft {
        var claimed: Set<String> = []
        var arrangement: [ScreenshotHandTarget] = []
        var items: [ScreenshotPlanItem] = []
        var excluded: [ScreenshotPlanExclusion] = []

        /// Keeps a live screenshot in the next place.
        mutating func keep(_ id: String) {
            claimed.insert(id)
            arrangement.append(.keep(liveID: id))
        }

        /// Uploads into the next place.
        mutating func upload(_ item: ScreenshotPlanItem) {
            items.append(item)
            arrangement.append(.upload(itemID: item.id))
        }

        /// The live screenshots kept, in their new order.
        var keptOrder: [String] {
            arrangement.compactMap { target in
                if case let .keep(id) = target { return id }
                return nil
            }
        }
    }

    private func plan(_ set: ScreenshotHandSet, locale: StoreLocale, input: ScreenshotPlanInput, matrix: ScreenshotMatrix, into result: inout Result) {
        let display = set.displayType
        let liveSet = input.live.set(locale: locale.code, displayType: display)
        var draft = Draft()
        for cell in matrix.row(locale: locale.code, displayType: display) {
            arrange(cell, liveSet: liveSet, locale: locale, input: input, into: &draft)
        }
        let live = liveSet?.screenshots ?? []
        for (index, shot) in live.enumerated() where !draft.claimed.contains(shot.id) {
            draft.items.append(ScreenshotPlanItem(
                appID: input.appID, cell: ScreenshotCellKey(locale: locale.code, displayType: display, slot: index), slotName: "",
                content: .delete, old: shot, oldOrigin: Self.origin(of: shot, document: input.document, locale: locale.code, display: display),
                source: .you, handSlotID: Self.deletedSlotID(for: shot, in: matrix, locale: locale.code, display: display)
            ))
        }
        let keptOrder = draft.keptOrder
        if keptOrder != live.map(\.id).filter(draft.claimed.contains) {
            var item = ScreenshotPlanItem(
                appID: input.appID, cell: ScreenshotCellKey(locale: locale.code, displayType: display, slot: 0), slotName: "",
                content: .reorder, old: nil, source: .you
            )
            item.handOrder = keptOrder
            draft.items.append(item)
        }
        finish(draft, liveSet: liveSet, locale: locale, display: display, input: input, into: &result)
    }

    /// One kept place: the live screenshot it matches, or what uploads.
    private func arrange(_ cell: ScreenshotCell, liveSet: LiveScreenshotSet?, locale: StoreLocale, input: ScreenshotPlanInput, into draft: inout Draft) {
        if let match = ScreenshotMatrixBuilder.liveMatch(for: cell, in: liveSet, document: input.document, claimed: draft.claimed) {
            draft.keep(match.id)
            return
        }
        switch cell.image {
        case let .hand(file):
            draft.upload(upload(.file(file), cell: cell, input: input, source: file.proposedBy.map { .assistant(client: $0) } ?? .you))
        case let .render(job) where cell.state == .notPushed:
            draft.upload(upload(.render(job), cell: cell, input: input, source: Self.source(of: cell.caption)))
        case .render:
            // A render that can't go keeps what's live in its place.
            if case let .failed(reason) = cell.state {
                draft.excluded.append(ScreenshotPlanExclusion(appID: input.appID, cell: cell.key, localeName: locale.name, failedCheck: reason))
            }
            if let live = cell.live, !draft.claimed.contains(live.id) { draft.keep(live.id) }
        case .live, .none:
            break
        }
    }

    /// The set's group, without what the person discarded; nothing goes
    /// for a language not on the version yet.
    private func finish(
        _ draft: Draft,
        liveSet: LiveScreenshotSet?,
        locale: StoreLocale,
        display: ScreenshotDisplayType,
        input: ScreenshotPlanInput,
        into result: inout Result
    ) {
        let pending = draft.items.filter { !isDiscarded($0, state: input.state) }
        result.kept += draft.items.filter { isDiscarded($0, state: input.state) }
        guard let localizationID = input.context.localizationID(for: locale, displayType: display) else {
            result.excluded += pending.filter { !$0.content.isSetChange }.map {
                ScreenshotPlanExclusion(appID: input.appID, cell: $0.cell, localeName: locale.name, failedCheck: nil)
            }
            return
        }
        result.excluded += draft.excluded
        guard !pending.isEmpty else { return }
        result.groups.append(ScreenshotPlanGroup(
            appID: input.appID, locale: locale, displayType: display, localizationID: localizationID, liveSet: liveSet,
            emptySetID: input.live.emptySet(locale: locale.code, displayType: display)?.id, items: pending,
            previews: input.live.previews(locale: locale.code, displayType: display), arrangement: draft.arrangement
        ))
    }

    private func upload(_ content: ScreenshotPlanContent, cell: ScreenshotCell, input: ScreenshotPlanInput, source: ChangeSource) -> ScreenshotPlanItem {
        let slotName = cell.image.renderJob == nil ? "" : input.document.slotName(cell.key.slot, on: cell.key.displayType)
        return ScreenshotPlanItem(
            appID: input.appID, cell: cell.key, slotName: slotName, content: content, old: nil, source: source, handSlotID: cell.hand?.slotID
        )
    }

    private func isDiscarded(_ item: ScreenshotPlanItem, state: ScreenshotPushState) -> Bool {
        if let job = item.content.renderJob { return state.kept[item.cell] == job.key }
        return state.isKept(item)
    }

    /// The deleted place a live screenshot was, so the push can forget it.
    private static func deletedSlotID(for shot: LiveScreenshot, in matrix: ScreenshotMatrix, locale: String, display: ScreenshotDisplayType) -> String? {
        let page = matrix.pageRow(locale: locale, displayType: display)
        return page.first { $0.state == .willBeDeleted && $0.live?.id == shot.id }?.hand?.slotID
    }

    /// Who made a render's change: an assistant whose caption was
    /// accepted, machine translation, or you.
    static func source(of caption: ScreenshotCaption?) -> ChangeSource {
        guard let caption else { return .you }
        if let assistant = caption.provenance.assistant { return assistant }
        return caption.provenance.isMachineTranslated ? .machineTranslation : .you
    }

    /// A live screenshot Atlas pushed is "from the template".
    private static func origin(of shot: LiveScreenshot, document: ScreenshotsDocument, locale: String, display: ScreenshotDisplayType)
        -> ScreenshotBackupOrigin
    {
        let pushed = document.pushed.contains { $0.cell.locale == locale && $0.cell.displayType == display && $0.checksum == shot.checksum }
        return pushed ? .template : .uploadedByHand
    }
}
