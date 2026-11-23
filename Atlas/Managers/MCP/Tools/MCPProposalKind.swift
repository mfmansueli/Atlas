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
    /// Submitting, releasing and the phased release (`propose_release_action`).
    case release

    var id: Self { self }

    var title: String {
        switch self {
        case .storeText: String(localized: "Store text")
        case .screenshots: String(localized: "Screenshot templates and captions")
        case .prices: String(localized: "Prices")
        case .appInformation: String(localized: "App Information answers")
        case .reviewReplies: String(localized: "Replies to reviews")
        case .artwork: String(localized: "Event and header artwork")
        case .release: String(localized: "Release actions")
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
        case .release: String(localized: "Submit for review, release, the phased release. Waits on the version card for you.")
        }
    }

    /// The refusal an assistant gets while the switch is off.
    var refusal: String {
        switch self {
        case .storeText:
            String(localized: "Suggesting store text is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .screenshots:
            String(localized: "Suggesting screenshots is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .prices:
            String(localized: "Suggesting prices is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .appInformation:
            String(localized: "Suggesting app information is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .reviewReplies:
            String(localized: "Suggesting replies to reviews is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .artwork:
            String(localized: "Suggesting event and header artwork is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        case .release:
            String(localized: "Suggesting release actions is turned off. The person can turn it on in Atlas → Settings → AI Assistants.")
        }
    }

    /// The kinds the switches had before board 48: a saved choice made
    /// then leaves the newer ones on, unless they were under a switch of
    /// their own before (`formerSwitch`).
    static let firstKinds: Set<Self> = [.storeText, .screenshots, .prices, .appInformation]

    /// The switch a kind was under before it had its own: a choice saved
    /// before then keeps what it allowed. Release actions were store text's.
    var formerSwitch: Self? {
        self == .release ? .storeText : nil
    }
}
