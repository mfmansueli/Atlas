//
//  PushProgressNote.swift
//  Atlas
//

import Foundation

/// A line under the progress bar about the push as a whole: paused for the
/// hourly budget, cancelling, waiting for room at Apple, or what a
/// screenshot push did to the live sets. `identifier` is the UI tests'.
struct PushProgressNote: Hashable, Sendable, Identifiable {
    enum Tone: Hashable, Sendable {
        case secondary
        case warning
        case danger
    }

    var identifier: String
    var text: String
    var systemImage: String
    var tone: Tone = .secondary

    var id: String { identifier }
}
