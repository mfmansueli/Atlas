//
//  PageShotsLook.swift
//  Atlas
//

import Foundation

/// What a page's set looks like (board 52's Look): the default page's
/// template, another of the starters, or a new look Claude Design draws
/// (three to choose from).
enum PageShotsLook: Codable, Hashable, Sendable {
    case same
    case starter(TemplateStarter)
    case claudeDesign

    var isClaudeDesign: Bool { self == .claudeDesign }
}
