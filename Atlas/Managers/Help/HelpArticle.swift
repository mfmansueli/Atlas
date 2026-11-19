//
//  HelpArticle.swift
//  Atlas
//

import Foundation

/// One Atlas Help article (board 49), from a bundled `help-<id>.md`: its
/// front matter (group, title, summary, keywords, Show Me, related) and
/// its blocks.
struct HelpArticle: Identifiable, Hashable, Sendable {
    var id: String
    var group: HelpGroup
    var title: String
    var summary: String
    var keywords: [String] = []
    var showMe: HelpShowMe?
    var related: [String] = []
    var blocks: [HelpBlock] = []
}
