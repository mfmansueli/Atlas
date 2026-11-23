//
//  AssistantAskFinish.swift
//  Atlas
//

import Foundation

/// An ask that ended with something to say: the window's toast says what
/// was suggested and where.
struct AssistantAskFinish: Identifiable, Hashable, Sendable {
    var id = UUID()
    let appID: StoreApp.ID
    /// What it was about, as the ask named it: “Pricing · review screenshots”.
    var subject = ""
    let text: String
}
