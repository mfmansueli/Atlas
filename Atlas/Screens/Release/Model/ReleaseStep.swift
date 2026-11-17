//
//  ReleaseStep.swift
//  Atlas
//

import Foundation

/// One step of the version's way to the App Store, on the card's line.
struct ReleaseStep: Identifiable, Hashable, Sendable {
    enum State: Hashable, Sendable {
        case done
        case current
        case upcoming
        /// App Review sent the version back here.
        case rejected
    }

    var id: Int
    var title: String
    /// "Nov 16, 10:42", "Usually about a day", "Day 3 of 7".
    var detail: String
    var state: State
}
