//
//  GuidedPushOutcome.swift
//  Atlas
//

import Foundation

/// What the Done step says once Approve All put the set in Review & Push.
/// The push itself only goes from Review & Push, with everything else
/// waiting there; Done follows it in one line and sends the person there
/// for its progress, failures and Try Again. "Sent" is only said when
/// every image and extra was.
enum GuidedPushOutcome: Hashable, Sendable {
    /// Approved and waiting in Review & Push; no push has gone yet.
    case approved
    /// Review & Push is pushing it.
    case sending
    case sent
    /// Something didn't go: failed, cancelled, or never sent.
    case partly
    /// Pushed from the sheet by a run from before Approve All (board 57),
    /// and Atlas closed since, so it can't tell how it ended.
    case unknown

    /// One push's counts.
    struct Tally: Hashable, Sendable {
        var total: Int
        var done: Int
        var isRunning: Bool
    }

    /// `pushedFromSheet`: the run is from before Approve All and was
    /// pushed from the guided sheet itself.
    static func make(images: Tally?, extras: Tally?, pushedFromSheet: Bool = false) -> GuidedPushOutcome {
        let tallies = [images, extras].compactMap(\.self)
        guard !tallies.isEmpty else { return pushedFromSheet ? .unknown : .approved }
        if tallies.contains(where: \.isRunning) { return .sending }
        return tallies.allSatisfy { $0.done == $0.total } ? .sent : .partly
    }

    var symbol: String {
        switch self {
        case .partly: "exclamationmark"
        case .sending, .unknown: "arrow.up"
        case .sent, .approved: "checkmark"
        }
    }

    var title: String {
        switch self {
        case .approved: String(localized: "Waiting in Review & Push")
        case .sending: String(localized: "Pushing from Review & Push")
        case .sent: String(localized: "Sent to the App Store")
        case .partly: String(localized: "Not everything was sent")
        case .unknown: String(localized: "Sent from this Mac")
        }
    }

    /// The line under the title; nil when the step writes its own.
    var detail: String? {
        switch self {
        case .approved:
            String(localized: "Everything is approved and waiting in Review & Push, top right, with your other changes. Push it from there.")
        case .sending:
            String(localized: "Its progress is in Review & Push, top right.")
        case .sent:
            nil
        case .partly:
            String(localized: "What was sent is on App Store Connect; the rest stays in Review & Push, where you can try again.")
        case .unknown:
            String(localized: "Atlas closed since this push, so it can’t tell how it ended. Anything not sent is still in Review & Push.")
        }
    }

    /// Whether Done offers Open Review & Push…: everything but a push
    /// that's all sent.
    var opensReviewPush: Bool { self != .sent }

    /// Open Review & Push…, or Show Progress… while it pushes.
    var reviewPushTitle: String {
        self == .sending ? String(localized: "Show Progress…") : String(localized: "Open Review & Push…")
    }
}
