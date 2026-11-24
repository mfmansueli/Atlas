//
//  HelpLibrary.swift
//  Atlas
//

import Foundation

/// Atlas Help's articles, read once from the bundled `help-*.md` files,
/// in the design's order within each group; and searching them.
struct HelpLibrary: Sendable {
    let articles: [HelpArticle]

    static let shared = HelpLibrary(bundle: .main)

    /// The design's order: Start here first, then each group.
    static let order = [
        "what", "connect", "suggest", "push",
        "store", "shots", "pages", "events", "info", "pricing",
        "submit", "reviews", "analytics",
        "assistant", "menubar", "pro", "privacy", "keys", "fix",
    ]

    /// The searches offered on the home page.
    static let tries = ["Add a language", "Vendor number", "The key was refused", "Pair Claude Code", "Price increase"]

    init(articles: [HelpArticle]) {
        self.articles = articles.sorted { (Self.order.firstIndex(of: $0.id) ?? .max) < (Self.order.firstIndex(of: $1.id) ?? .max) }
    }

    init(bundle: Bundle) {
        let urls = bundle.urls(forResourcesWithExtension: "md", subdirectory: nil) ?? []
        let articles = urls.filter { $0.lastPathComponent.hasPrefix("help-") }.compactMap { url in
            (try? String(contentsOf: url, encoding: .utf8)).flatMap(HelpArticleParser.article(from:))
        }
        self.init(articles: articles)
    }

    func article(_ id: String) -> HelpArticle? {
        articles.first { $0.id == id }
    }

    func articles(in group: HelpGroup) -> [HelpArticle] {
        articles.filter { $0.group == group }
    }

    func related(to article: HelpArticle) -> [HelpArticle] {
        article.related.compactMap(self.article)
    }

    /// Every word of the query has to be somewhere in the article; a match
    /// in the title counts most, then the keywords, the summary, the text.
    func search(_ query: String) -> [HelpArticle] {
        let words = Self.words(query)
        guard !words.isEmpty else { return [] }
        let scored = articles.compactMap { article -> (HelpArticle, Int)? in
            let title = Self.fold(article.title)
            let keywords = Self.fold(article.keywords.joined(separator: " "))
            let summary = Self.fold(article.summary)
            let text = Self.fold(article.blocks.map(\.text).joined(separator: " "))
            var score = 0
            for word in words {
                if title.contains(word) {
                    score += 8
                } else if keywords.contains(word) {
                    score += 5
                } else if summary.contains(word) {
                    score += 3
                } else if text.contains(word) {
                    score += 1
                } else {
                    return nil
                }
            }
            return (article, score)
        }
        return scored.sorted { $0.1 > $1.1 }.map(\.0)
    }

    /// The words that count: folded, without the little ones.
    static func words(_ query: String) -> [String] {
        let stop: Set = ["a", "an", "the", "to", "of", "in", "on", "my", "i", "how", "do", "is", "was", "and", "or"]
        return fold(query).split { !$0.isLetter && !$0.isNumber && $0 != "." }.map(String.init).filter { !stop.contains($0) }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).replacingOccurrences(of: "’", with: "'")
    }
}
