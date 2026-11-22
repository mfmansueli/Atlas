//
//  AutopilotRecaptureTargets.swift
//  Atlas
//

import Foundation

/// Between the set's cells (a language's slot on a device, as Screenshots
/// → Captures shows them) and a plan's capture targets: the slot a target's
/// capture goes on, and the targets that fill a cell (iPhone Duo's cover
/// display beside the inner one fills the same cell). Pure.
enum AutopilotRecaptureTargets {
    /// The set's slot `target`'s capture goes on, and whether it's the
    /// slot's companion (iPhone Duo's cover display beside the inner one);
    /// nil for a target the plan doesn't place.
    static func documentSlot(of target: AutopilotCaptureTarget, in plan: AutopilotPlan) -> (slot: Int, isCompanion: Bool)? {
        guard let slot = plan.slot(of: target.screenID) else { return nil }
        guard let pose = plan.duoPose(for: target) else { return (slot, false) }
        return plan.duoPlacement(slot: slot, pose: pose)
    }

    /// The plan's targets whose captures fill `slot` of `locale` on
    /// `display`: one screen, or iPhone Duo's poses shown on that slot.
    static func targets(locale: String, display: ScreenshotDisplayType, slot: Int, in plan: AutopilotPlan) -> [AutopilotCaptureTarget] {
        plan.targets.filter { target in
            target.locale == locale && target.displayType == display && documentSlot(of: target, in: plan)?.slot == slot
        }
    }

    /// The plan's targets for cells, each once, in the plan's order.
    static func targets(cells: [(locale: String, display: ScreenshotDisplayType, slot: Int)], in plan: AutopilotPlan) -> [AutopilotCaptureTarget] {
        let wanted = Set(cells.flatMap { targets(locale: $0.locale, display: $0.display, slot: $0.slot, in: plan) })
        return plan.targets.filter(wanted.contains)
    }
}
