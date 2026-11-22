//
//  GuidedPushOutcome.swift
//  Atlas
//

import Foundation

/// How the guided run's push went, for the Done step. "Sent" is only said
/// when every image and extra was: a push stopped by going offline isn't a
/// failure in its rows, and after a relaunch there's no push left to ask.
enum GuidedPushOutcome: Hashable, Sendable {
    case sending
    case sent
    /// Something didn't go: failed, cancelled, or never sent.
    case partly
    /// Atlas closed since the push, so it can't tell how it ended.
    case unknown
    /// Approve All put it in Review & Push, and no push has gone yet.
    case approved

    /// One push's counts.
    struct Tally: Hashable, Sendable {
        var total: Int
        var done: Int
        var isRunning: Bool
    }

    /// `approvedOnly`: the set went to Review & Push with Approve All, not
    /// pushed from the sheet.
    static func make(images: Tally?, extras: Tally?, approvedOnly: Bool = false) -> GuidedPushOutcome {
        let tallies = [images, extras].compactMap(\.self)
        guard !tallies.isEmpty else { return approvedOnly ? .approved : .unknown }
        if tallies.contains(where: \.isRunning) { return .sending }
        return tallies.allSatisfy { $0.done == $0.total } ? .sent : .partly
    }

    var symbol: String {
        switch self {
        case .partly: "exclamationmark"
        case .unknown: "arrow.up"
        case .sending, .sent, .approved: "checkmark"
        }
    }

    var title: String {
        switch self {
        case .sending: String(localized: "Sending to the App Store")
        case .sent: String(localized: "Sent to the App Store")
        case .partly: String(localized: "Not everything was sent")
        case .unknown: String(localized: "Sent from this Mac")
        case .approved: String(localized: "Waiting in Review & Push")
        }
    }

    /// The line under the title; nil when the step writes its own.
    var detail: String? {
        switch self {
        case .sending, .sent: nil
        case .partly: String(localized: "What was sent is on App Store Connect; the rest stays in Review & Push.")
        case .unknown: String(localized: "Atlas closed since this push, so it can’t tell how it ended. Anything not sent is still in Review & Push.")
        case .approved: String(localized: "Everything is approved and waiting in Review & Push, top right. Push it from there; this shows how it goes.")
        }
    }
}
