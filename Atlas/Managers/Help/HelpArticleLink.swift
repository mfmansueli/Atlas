//
//  HelpArticleLink.swift
//  Atlas
//

import Foundation

/// A web page an article's steps happen on, opened from a button under
/// the article: front matter `link: Open App Store Connect | https://…`.
struct HelpArticleLink: Hashable, Sendable {
    var title: String
    var url: URL

    /// `Title | https://…`; nil without both, or for a URL that isn't https.
    init?(_ text: String) {
        let parts = text.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, !parts[0].isEmpty,
              let url = URL(string: parts[1]), url.scheme == "https", url.host() != nil else { return nil }
        title = parts[0]
        self.url = url
    }
}
