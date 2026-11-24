//
//  NominationLink.swift
//  Atlas
//

import Foundation

/// A nomination's materials are links (`supplementalMaterialsUris`): Apple
/// takes no files. A link is a full `https://` URL with a host.
enum NominationLink {
    static func isValid(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace), let url = URL(string: trimmed), url.scheme?.lowercased() == "https",
              let host = url.host(), host.contains(".")
        else { return false }
        return true
    }

    /// "lumen.app" for `https://lumen.app/press-kit`.
    static func host(of text: String) -> String {
        URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))?.host() ?? text
    }

    /// The links in `text` (a description Apple refused for one): what
    /// "Move Link to Materials" takes out.
    static func links(in text: String) -> [String] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
    }
}
