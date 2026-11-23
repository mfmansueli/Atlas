//
//  RetentionAskKind.swift
//  Atlas
//

import Foundation

/// What a Retention ask button asks the assistant for.
enum RetentionAskKind: Hashable {
    /// The header's "Ask Claude Code…": draft a message.
    case draft
    /// The empty page's "Ask Claude Code to Draft One…".
    case draftOne
    /// A shorter wording for one language.
    case shorten(message: String, language: String, locale: String, header: String, body: String)
    /// The image sheet's "Make One with Claude…".
    case image(message: String)

    var identifier: String {
        switch self {
        case .draft: "retention.ask"
        case .draftOne: "retention.empty.ask"
        case .shorten: "retention.shorten.ask"
        case .image: "retention.image.make"
        }
    }

    func title(client: String) -> String {
        switch self {
        case .draft: String(localized: "Ask \(client)…")
        case .draftOne: String(localized: "Ask \(client) to Draft One…")
        case .shorten: String(localized: "Ask \(client) to Shorten It…")
        case .image: String(localized: "Make One with Claude…")
        }
    }

    func prompt(app: String) -> String {
        switch self {
        case .draft, .draftOne:
            RetentionAskPrompts.draft(app: app)
        case let .shorten(message, language, locale, header, body):
            RetentionAskPrompts.shorten(app: app, message: message, language: language, locale: locale, header: header, body: body)
        case let .image(message):
            RetentionAskPrompts.image(app: app, message: message, folder: String(localized: "the app's project folder"))
        }
    }

    func help(client: String, app: String) -> String {
        switch self {
        case .draft, .draftOne: String(localized: "Ask \(client) to draft a retention message from \(app)’s features, in your voice")
        case .shorten: String(localized: "Ask \(client) for a shorter version that fits Apple’s limits")
        case .image: String(localized: "Ask \(client) to make an image for the message")
        }
    }

    func explanation(client: String, app: String) -> String {
        switch self {
        case .draft, .draftOne:
            String(localized: """
            \(client) drafts a message in your voice from \(app)’s project and listing. Atlas translates it. Nothing is sent until you \
            push.
            """)
        case .shorten:
            String(localized: "\(client) writes a shorter version and adds it to Review & Push.")
        case .image:
            String(localized: "\(client) makes a 3840 × 1000 image. It joins the Asset Library when you push the message.")
        }
    }
}
