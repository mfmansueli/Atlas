//
//  AssistantAskFinish.swift
//  Atlas
//

import Foundation

/// An ask that ended with something to say: the Autopilot bar's strip says
/// what was suggested and where (board 80).
struct AssistantAskFinish: Identifiable, Hashable, Sendable {
    var id = UUID()
    let appID: StoreApp.ID
    /// What it was about, as the ask named it: “Pricing · review screenshots”.
    var subject = ""
    let text: String
    /// Its run stopped with a problem: the strip says why instead.
    var isFailure = false
}
