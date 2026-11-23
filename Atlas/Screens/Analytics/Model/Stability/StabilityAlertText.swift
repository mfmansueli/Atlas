//
//  StabilityAlertText.swift
//  Atlas
//

import Foundation

/// The Overview's crash banner, in two parts: the bold lead, “Version 1.4
/// crashes 3.2× as often as 1.3,”, and what follows, “mostly on iPhone 11.
/// Pausing keeps it away from the other 95%.” The pausing sentence shows
/// while a phased release is rolling out and not paused.
struct StabilityAlertText: Equatable {
    let lead: String
    let detail: String?

    /// nil when the report isn't worse or has nothing to compare with.
    static func make(_ report: StabilityReport, phase: ReleasePhase?) -> StabilityAlertText? {
        guard report.isWorse, let previous = report.previous, let times = report.times else { return nil }
        return make(version: report.latest.version, previous: previous.version, times: times, device: report.mostAffected?.device, phase: phase)
    }

    static func make(version: String, previous: String, times: Double, device: String?, phase: ReleasePhase?) -> StabilityAlertText {
        let multiple = AnalyticsText.times(times)
        let pausing = notYetReached(phase).map {
            String(localized: "Pausing keeps it away from the other \($0)%.", comment: "kind:banner")
        }
        guard let device else {
            return StabilityAlertText(
                lead: String(localized: "Version \(version) crashes \(multiple) as often as \(previous).", comment: "kind:banner"),
                detail: pausing
            )
        }
        let place = String(localized: "mostly on \(device).", comment: "kind:banner")
        return StabilityAlertText(
            lead: String(localized: "Version \(version) crashes \(multiple) as often as \(previous),", comment: "kind:banner"),
            detail: [place, pausing].compactMap(\.self).joined(separator: " ")
        )
    }

    /// The share of automatic updates that don't have the version yet,
    /// while a phased release rolls out; nil when it's paused, done or not
    /// phased.
    static func notYetReached(_ phase: ReleasePhase?) -> Int? {
        guard case let .phased(day, isPaused) = phase, !isPaused else { return nil }
        let rest = 100 - PhasedRelease.percentage(day: day)
        return rest > 0 ? rest : nil
    }

    /// Pause Phased Release… shows beside the banner.
    static func canPause(_ phase: ReleasePhase?) -> Bool {
        if case .phased(_, false) = phase { return true }
        return false
    }
}
