//
//  CapturesViewModel+Selection.swift
//  Atlas
//

import Foundation

/// Choosing captures to redo in Screenshots → Captures: ⌘-click a cell, or
/// a language's row or a screen's column, then Replace… (one capture) or
/// Capture Again with Claude Code (a capture-only run for just those).
extension CapturesViewModel {
    func key(_ cell: CaptureCoverage.Cell, of row: CaptureCoverage.Row) -> CaptureCellKey {
        CaptureCellKey(locale: row.locale.code, displayType: screenshots.displayType, slot: cell.slot)
    }

    func isSelected(_ cell: CaptureCoverage.Cell, of row: CaptureCoverage.Row) -> Bool {
        selection.contains(key(cell, of: row))
    }

    /// ⌘-click: in or out of the selection.
    func toggle(_ cell: CaptureCoverage.Cell, of row: CaptureCoverage.Row) {
        let key = key(cell, of: row)
        if selection.remove(key) == nil { selection.insert(key) }
    }

    /// A language's row: all of its screens, or none when all were.
    func toggleRow(_ row: CaptureCoverage.Row) {
        toggle(row.cells.map { key($0, of: row) })
    }

    /// A screen's column: that screen in every language shown.
    func toggleColumn(_ slot: Int) {
        guard let coverage else { return }
        let rows = coverage.groups.flatMap(\.rows)
        toggle(rows.compactMap { row in row.cells.first { $0.slot == slot }.map { key($0, of: row) } })
    }

    func clearSelection() {
        selection = []
    }

    private func toggle(_ keys: [CaptureCellKey]) {
        if Set(keys).isSubset(of: selection) { selection.subtract(keys) } else { selection.formUnion(keys) }
    }

    /// "3 selected".
    var selectionTitle: String {
        selection.count == 1 ? String(localized: "1 selected") : String(localized: "\(selection.count) selected")
    }

    /// The run's capture targets for the selection, in its plan's order;
    /// empty when the plan doesn't capture them. With no saved run, the
    /// plan made from the set's captures, and only cells with a capture.
    var selectedTargets: [AutopilotCaptureTarget] {
        selectedTargets(fromCaptures: screenshots.studio.recapturePlanFromCaptures)
    }

    private func selectedTargets(fromCaptures: AutopilotRecapturePlanFromCaptures?) -> [AutopilotCaptureTarget] {
        let cells = selection.map { ($0.locale, $0.displayType, $0.slot) }
        if let fromCaptures {
            let captured = fromCaptures.capturedTargets
            return AutopilotRecaptureTargets.targets(cells: cells, in: fromCaptures.plan).filter(captured.contains)
        }
        guard let plan = screenshots.studio.autopilot?.run(for: screenshots.app.id)?.plan else { return [] }
        return AutopilotRecaptureTargets.targets(cells: cells, in: plan)
    }

    /// Why Capture Again with Claude Code can't start now; nil when it can.
    var captureAgainRefusal: String? {
        guard let center = screenshots.studio.autopilot else { return String(localized: "Autopilot isn’t available here.") }
        if let refusal = center.recaptureRefusal(appID: screenshots.app.id) { return refusal }
        if center.redoesFromCaptures(appID: screenshots.app.id), screenshots.studio.recapturePlanFromCaptures == nil {
            return AutopilotCenter.noCapturesRefusal(appName: screenshots.app.name)
        }
        if selectedTargets.isEmpty { return String(localized: "Autopilot’s plan doesn’t capture these. Run Autopilot… to plan them.") }
        return nil
    }

    /// Capture Again with Claude Code: a capture-only run for the
    /// selection; Claude Code starts on it (or its prompt is copied).
    func captureAgain(_ keys: Set<CaptureCellKey>? = nil) {
        if let keys { selection = keys }
        guard let center = screenshots.studio.autopilot else { return }
        let fromCaptures = screenshots.studio.recapturePlanFromCaptures
        do {
            try center.openRecapture(
                appID: screenshots.app.id, targets: selectedTargets(fromCaptures: fromCaptures), client: nil, fromCaptures: fromCaptures
            )
        } catch let error as AutopilotError {
            errorMessage = error.localizedDescription
            return
        } catch {
            errorMessage = AppleErrorCopy(String(localized: "The run for these captures didn’t open.", comment: "kind:error"), error: error).text
            return
        }
        selection = []
        viewed = nil
        screenshots.studio.openAutopilot()
        screenshots.studio.continueRun()
    }
}
