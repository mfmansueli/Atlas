//
//  ScreenshotMatrix.swift
//  Atlas
//

import Foundation

/// The Sets matrix for every rendered display type: one cell per locale ×
/// display type × slot, with the locales grouped the way the rows are.
struct ScreenshotMatrix: Hashable, Sendable {
    var slotCount: Int
    var cells: [ScreenshotCellKey: ScreenshotCell]
    /// In the scope and rendered, primary first.
    var localizedLocales: [String]
    /// Restored and pinned.
    var restoredLocales: [String]
    /// Out of the scope: the App Store shows the primary locale's set.
    var fallbackLocales: [String]
    var hasTemplate: Bool
    var hasCaptures: Bool
    /// Apple Watch's and Apple Vision Pro's screens, when the set has them.
    var ownSlotCounts: [ScreenshotDisplayType: Int] = [:]
    /// The set has Mac screenshots (it has Mac captures).
    var hasMac = false
    /// Rows whose length isn't the set's slot count: sets changed by hand,
    /// and live sets longer than the template, by `ScreenshotHandSet.key`.
    var rowCounts: [String: Int] = [:]
    /// The rows of sets changed by hand as the language page draws them:
    /// every place in order, the ones that will be deleted too.
    var handRows: [String: [ScreenshotCell]] = [:]
    /// Devices Atlas doesn't render that have live screenshots or sets
    /// changed by hand (Mac without captures, Apple Watch, Apple Vision
    /// Pro): the language page shows and edits them.
    var handDisplays: [ScreenshotDisplayType] = []

    static let empty = ScreenshotMatrix(
        slotCount: 0, cells: [:], localizedLocales: [], restoredLocales: [], fallbackLocales: [], hasTemplate: false, hasCaptures: false
    )

    func cell(locale: String, displayType: ScreenshotDisplayType, slot: Int) -> ScreenshotCell? {
        cells[ScreenshotCellKey(locale: locale, displayType: displayType, slot: slot)]
    }

    func row(locale: String, displayType: ScreenshotDisplayType) -> [ScreenshotCell] {
        let count = rowCounts[ScreenshotHandSet.key(locale: locale, displayType: displayType)] ?? slotCount(on: displayType)
        return (0..<count).compactMap { cell(locale: locale, displayType: displayType, slot: $0) }
    }

    /// A row as the language page draws it: with a set changed by hand,
    /// every place, the ones that will be deleted too.
    func pageRow(locale: String, displayType: ScreenshotDisplayType) -> [ScreenshotCell] {
        handRows[ScreenshotHandSet.key(locale: locale, displayType: displayType)] ?? row(locale: locale, displayType: displayType)
    }

    /// Whether the row's set was changed by hand.
    func isHandRow(locale: String, displayType: ScreenshotDisplayType) -> Bool {
        handRows[ScreenshotHandSet.key(locale: locale, displayType: displayType)] != nil
    }

    /// The set's slots on iPhone and iPad; Apple Watch's and Apple Vision
    /// Pro's own screens, and iPhone Duo's when it has some.
    func slotCount(on display: ScreenshotDisplayType) -> Int {
        ownSlotCounts[display] ?? (display.hasOwnScreens ? 0 : slotCount)
    }

    /// iPhone, iPhone Duo and iPad, Mac when the set has it, then the
    /// devices with screens of their own.
    var displays: [ScreenshotDisplayType] {
        ScreenshotDisplayType.standard + (hasMac ? [.mac] : []) + ScreenshotDisplayType.ownScreens.filter { (ownSlotCounts[$0] ?? 0) > 0 }
    }

    /// The localized cells in push order: iPhone then iPad, locales in
    /// scope order, slots in order.
    var localizedCells: [ScreenshotCell] {
        displays.flatMap { display in
            localizedLocales.flatMap { row(locale: $0, displayType: display) }
        }
    }

    /// Renders waiting for Review & Push, on every display type.
    var pendingCount: Int {
        localizedCells.count { $0.state.isPending }
    }

    /// Renders that fail a check, in push order.
    var failedCells: [ScreenshotCell] {
        localizedCells.filter(\.state.isFailed)
    }

    /// Captions in the scope that overflow on `displayType`: the red count
    /// on Captions.
    func overflowingCaptionCount(on displayType: ScreenshotDisplayType) -> Int {
        localizedLocales.reduce(0) { total, locale in
            total + row(locale: locale, displayType: displayType).count { cell in
                cell.checks.contains { $0.kind == .fit && $0.status == .failed }
            }
        }
    }

    /// The localized cells' render jobs, deduplicated, in push order, for
    /// the render queue; the primary locale's come first so fallback rows
    /// fill in early.
    var renderJobs: [RenderJob] {
        var seen = Set<RenderKey>()
        return localizedCells.compactMap(\.image.renderJob).filter { seen.insert($0.key).inserted }
    }
}
