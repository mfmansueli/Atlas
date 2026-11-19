//
//  HelpBlock.swift
//  Atlas
//

import Foundation

/// One piece of a Help article, parsed from its Markdown: a paragraph, a
/// heading, numbered steps, a list, a note in a box, or a table.
enum HelpBlock: Hashable, Sendable {
    case paragraph(String)
    case heading(String)
    case steps([String])
    case bullets([String])
    case note(String)
    case table(header: [String], rows: [[String]])

    /// The words a search looks through.
    var text: String {
        switch self {
        case let .paragraph(text), let .heading(text), let .note(text): text
        case let .steps(items), let .bullets(items): items.joined(separator: " ")
        case let .table(header, rows): (header + rows.flatMap(\.self)).joined(separator: " ")
        }
    }
}
