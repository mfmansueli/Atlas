//
//  HelpBlock.swift
//  Atlas
//

import Foundation

/// One piece of a Help article, parsed from its Markdown: a paragraph, a
/// heading, numbered steps, a list, a note in a box, a table, or a
/// picture bundled with the articles.
enum HelpBlock: Hashable, Sendable {
    case paragraph(String)
    case heading(String)
    /// `start` is the first step's number, so steps split by pictures
    /// keep counting.
    case steps([String], start: Int = 1)
    case bullets([String])
    case note(String)
    case table(header: [String], rows: [[String]])
    /// `![caption](name)`: `name` is one of Atlas's drawings
    /// (`HelpDrawing`) or an image bundled beside the articles, `caption`
    /// what VoiceOver reads for an image.
    case image(name: String, caption: String)

    /// The words a search looks through.
    var text: String {
        switch self {
        case let .paragraph(text), let .heading(text), let .note(text): text
        case let .steps(items, _), let .bullets(items): items.joined(separator: " ")
        case let .image(_, caption): caption
        case let .table(header, rows): (header + rows.flatMap(\.self)).joined(separator: " ")
        }
    }

    /// A heading's scroll anchor in the article (Fix a Problem's target).
    static func anchor(for heading: String) -> String {
        "heading." + heading
    }
}
