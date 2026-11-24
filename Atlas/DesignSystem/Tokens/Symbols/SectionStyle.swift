//
//  SectionStyle.swift
//  Atlas
//

import SwiftUI

/// A place's SF Symbol and the system colour it's drawn in (README —
/// Design system §13, board 72): the outline symbol, no tile behind it.
/// The workspace's sections and Settings' panes each have one; the values
/// are `design-tokens.json → symbol`.
struct SectionStyle: Hashable, Sendable {
    let symbol: String
    let tint: SymbolTint

    var color: Color { tint.color }

    // MARK: - Workspace sections

    static let overview = SectionStyle(symbol: "square.grid.2x2", tint: .systemGray)
    static let storePage = SectionStyle(symbol: "doc.text", tint: .systemBlue)
    static let screenshots = SectionStyle(symbol: "iphone", tint: .systemOrange)
    static let productPages = SectionStyle(symbol: "rectangle.stack", tint: .systemTeal)
    static let inAppEvents = SectionStyle(symbol: "calendar", tint: .systemPink)
    static let nominations = SectionStyle(symbol: "rosette", tint: .systemBrown)
    static let appInformation = SectionStyle(symbol: "info.circle", tint: .systemGray)
    static let pricing = SectionStyle(symbol: "tag", tint: .systemGreen)
    static let reviews = SectionStyle(symbol: "star", tint: .systemYellow)
    static let analytics = SectionStyle(symbol: "chart.bar", tint: .systemIndigo)

    // MARK: - Settings panes

    static let settingsGeneral = SectionStyle(symbol: "gearshape", tint: .systemGray)
    static let settingsAccounts = SectionStyle(symbol: "key", tint: .systemBlue)
    static let settingsAssistants = SectionStyle(symbol: "sparkles", tint: .ai)
    static let settingsSuggestions = SectionStyle(symbol: "tag", tint: .systemIndigo)
    static let settingsPricing = SectionStyle(symbol: "dollarsign.circle", tint: .systemGreen)
    static let settingsScreenshots = SectionStyle(symbol: "iphone", tint: .systemOrange)
    static let settingsNotifications = SectionStyle(symbol: "bell", tint: .systemRed)
    static let settingsPro = SectionStyle(symbol: "star", tint: .systemBlue)
    static let settingsPrivacy = SectionStyle(symbol: "hand.raised", tint: .systemBlue)
}
