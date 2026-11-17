//
//  FindingSource.swift
//  Atlas
//

import Foundation

/// Who saw a finding, marked the way suggestions mark their source.
enum FindingSource: Hashable, Sendable, Codable {
    /// Atlas's own rules, run after each download.
    case builtIn
    /// An assistant reading the same numbers over MCP, e.g. "Claude Code".
    case assistant(String)

    /// The two letters on the mark: "AL", "CC".
    var mark: String {
        switch self {
        case .builtIn: "AL"
        case let .assistant(name): ChangeSource.assistant(client: name).monogram ?? "AI"
        }
    }

    var title: String {
        switch self {
        case .builtIn: String(localized: "Built-in")
        case let .assistant(name): name
        }
    }
}
