//
//  MCPProposalKind.swift
//  Atlas
//

import Foundation

/// What assistants may propose, each a switch in Settings → AI Assistants →
/// "Assistants may suggest" (board 48). Reading is always allowed while the
/// server runs.
enum MCPProposalKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case storeText
    case screenshots
    case prices
    case appInformation
    case reviewReplies
    case artwork

    var id: Self { self }

    var title: String {
        switch self {
        case .storeText: String(localized: "Store text")
        case .screenshots: String(localized: "Screenshot templates and captions")
        case .prices: String(localized: "Prices")
        case .appInformation: String(localized: "App Information answers")
        case .reviewReplies: String(localized: "Replies to reviews")
        case .artwork: String(localized: "Event and header artwork")
        }
    }

    var caption: String? {
        switch self {
        case .storeText: String(localized: "Listing text, translations, keywords and What’s New.")
        case .screenshots: nil
        case .prices: String(localized: "Always refused for apps set to “Keep my prices”.")
        case .appInformation: String(localized: "Age rating, accessibility, App Privacy. You accept each one.")
        case .reviewReplies: nil
        case .artwork: String(localized: "Drawn by Claude from the app’s design project.")
        }
    }

    /// The refusal an assistant gets while the switch is off.
    var refusal: String {
        switch self {
        case .storeText:
            String(localized: "Proposing store text is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .screenshots:
            String(localized: "Proposing screenshots is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .prices:
            String(localized: "Proposing prices is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .appInformation:
            String(localized: "Proposing app information is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .reviewReplies:
            String(localized: "Suggesting replies to reviews is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .artwork:
            String(localized: "Proposing event and header artwork is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        }
    }

    /// The kinds the switches had before board 48: a saved choice made
    /// then leaves the newer ones on.
    static let firstKinds: Set<Self> = [.storeText, .screenshots, .prices, .appInformation]
}
