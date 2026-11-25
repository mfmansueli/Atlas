//
//  ReviewRisksDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// DEBUG scenes (`-AtlasDebugScene <id>`) for the Overview's App Review
/// card:
///
/// - `rr-card`: four risks (two block review), one check that couldn't run.
/// - `rr-empty`: never checked: Check Now.
/// - `rr-clear`: checked, nothing found.
enum ReviewRisksDebugScenes {
    static let ids = ["rr-card", "rr-empty", "rr-clear"]

    @MainActor
    static func view(for id: String) -> AnyView? {
        switch id {
        case "rr-card": AnyView(ReviewRisksDebugCard(report: ReviewRisksDebugData.report(ReviewRisksDebugData.risks)))
        case "rr-empty": AnyView(ReviewRisksDebugCard(report: nil))
        case "rr-clear": AnyView(ReviewRisksDebugCard(report: ReviewRisksDebugData.report([], gaps: 0)))
        default: nil
        }
    }
}
#endif
