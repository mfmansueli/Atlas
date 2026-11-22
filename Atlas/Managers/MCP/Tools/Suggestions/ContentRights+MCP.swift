//
//  ContentRights+MCP.swift
//  Atlas
//

import Foundation

// Content rights as App Store Connect asks it, for `get_app_information`:
// Apple's question and its two answers, in Apple's words.
extension ContentRights {
    static let appleQuestion = "Does your app contain, show, or access third-party content?"

    var appleAnswer: String {
        switch self {
        case .usesThirdPartyContent: "Yes, it contains, shows, or accesses third-party content, and I have the necessary rights"
        case .doesNotUseThirdPartyContent: "No, it does not contain, show, or access third-party content"
        }
    }

    /// `choices.contentRights`' entry: the id to send, its name, Apple's
    /// answer.
    var mcpChoice: JSONValue {
        ["id": .string(rawValue), "name": .string(title), "answer": .string(appleAnswer)]
    }
}
