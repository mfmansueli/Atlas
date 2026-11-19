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
    let text: String
}
