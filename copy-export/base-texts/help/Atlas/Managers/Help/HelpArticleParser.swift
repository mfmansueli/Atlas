//
//  HelpArticleParser.swift
//  Atlas
//

import Foundation

/// Reads a Help article's Markdown: front matter between `---` lines, then
/// blocks separated by blank lines. `## ` is a heading, `1. ` steps, `- `
/// a list, `> ` a note, `| ` a table (its second row the `---` divider);
/// anything else a paragraph. Inline `**bold**` stays for the view.
enum HelpArticleParser {
    static func article(from markdown: String) -> HelpArticle? {
        let lines = markdown.components(separatedBy: .newlines)
        guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---") else { return nil }
        var fields: [String: String] = [:]
        for line in lines[1..<end] {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let key = line[..<colon].trimmingCharacters(in: .whitespaces)
            fields[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        guard let id = fields["id"], !id.isEmpty, let title = fields["title"],
              let group = fields["group"].flatMap(HelpGroup.init(rawValue:)) else { return nil }
        return HelpArticle(
            id: id, group: group, title: title, summary: fields["summary"] ?? "",
            keywords: list(fields["keywords"]),
            showMe: fields["showMe"].flatMap(HelpShowMe.init),
            related: list(fields["related"]),
            blocks: blocks(Array(lines[(end + 1)...]))
        )
    }

    static func blocks(_ lines: [String]) -> [HelpBlock] {
        var blocks: [HelpBlock] = []
        var chunk: [String] = []
        for line in lines + [""] {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if let block = block(chunk) { blocks.append(block) }
                chunk = []
            } else {
                chunk.append(trimmed)
            }
        }
        return blocks
    }

    private static func block(_ lines: [String]) -> HelpBlock? {
        guard let first = lines.first else { return nil }
        if first.hasPrefix("## ") { return .heading(String(first.dropFirst(3))) }
        if first.hasPrefix("> ") { return .note(lines.map { String($0.drop { $0 == ">" || $0 == " " }) }.joined(separator: " ")) }
        if first.hasPrefix("- ") { return .bullets(lines.map { String($0.dropFirst(2)) }) }
        if first.hasPrefix("|") { return table(lines) }
        if first.first?.isNumber == true, first.contains(". ") {
            return .steps(lines.map { line in
                guard let dot = line.range(of: ". ") else { return line }
                return String(line[dot.upperBound...])
            })
        }
        return .paragraph(lines.joined(separator: " "))
    }

    private static func table(_ lines: [String]) -> HelpBlock? {
        let rows = lines.map(cells).filter { row in !row.allSatisfy { $0.allSatisfy { $0 == "-" } && !$0.isEmpty } }
        guard let header = rows.first else { return nil }
        return .table(header: header, rows: Array(rows.dropFirst()))
    }

    /// `| a | b |` → ["a", "b"]; an empty first cell stays.
    static func cells(_ line: String) -> [String] {
        var parts = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.first == "" { parts.removeFirst() }
        if parts.last == "" { parts.removeLast() }
        return parts
    }

    private static func list(_ text: String?) -> [String] {
        (text ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
