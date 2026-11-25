//
//  WorkspaceAutopilotAction.swift
//  Atlas
//

import Foundation

/// Everything the toolbar's Autopilot button can do, section by section
/// (README-Toolbar, board 57). The first of a section's actions is the
/// button's own; the rest are in its menu, before Everything for the app.
/// The ones a section already had run that section's own flow (through
/// `WorkspaceIntent.autopilot`); the new ones ask Claude Code from the
/// toolbar (`WorkspaceAutopilotAsk`).
enum WorkspaceAutopilotAction: Hashable, Sendable {
    // Overview
    case suggestEverything
    case writeWhatsNew
    // Store Page
    case suggestTexts
    case suggestSourceLanguageOnly
    case translateNewLanguage
    case askSomethingElse
    // Screenshots
    case makeScreenshots
    case makeAppPreview
    case makeArtwork
    case recaptureSome
    // Custom Product Pages
    case suggestPages
    case makePageScreenshots
    // In-App Events
    case makeEventArtwork
    case writeEventTexts
    case checkEventsForReview
    /// An empty In-App Events' lead (board 74 · 3): the assistant drafts
    /// a first event.
    case suggestEvent
    // Nominations
    case suggestNomination
    case writeNominationDescription
    // App Information
    case suggestAnswers
    case checkPrivacy
    // Pricing
    case suggestPrices
    /// The App Review screenshots of the products missing one, captured
    /// in Simulator (README — Pricing: review screenshots).
    case makeReviewScreenshots
    case writeRetentionOffer
    // Reviews
    case draftReplies
    /// Reply Automatically… (board 58): its settings, in Reviews.
    case replyAutomatically
    case summarizeRequests
    // Analytics
    case findWhatToTry
    case explainChange

    /// The section's actions, its button's first.
    static func actions(for section: AppWorkspaceSection) -> [Self] {
        switch section {
        case .overview: [.suggestEverything, .makeScreenshots, .writeWhatsNew]
        case .storePage: [.suggestTexts, .suggestSourceLanguageOnly, .translateNewLanguage, .askSomethingElse]
        case .screenshots: [.makeScreenshots, .makeAppPreview, .makeArtwork, .recaptureSome]
        case .productPages: [.suggestPages, .makePageScreenshots]
        case .inAppEvents: [.makeEventArtwork, .writeEventTexts, .checkEventsForReview, .suggestEvent]
        case .nominations: [.suggestNomination, .writeNominationDescription]
        case .appInformation: [.suggestAnswers, .checkPrivacy]
        case .subscriptionPricing: [.suggestPrices, .makeReviewScreenshots, .writeRetentionOffer]
        case .reviews: [.draftReplies, .replyAutomatically, .summarizeRequests]
        case .analytics: [.findWhatToTry, .explainChange]
        }
    }

    /// The section's actions with a detail page open: the page's own
    /// first (Make the Artwork…, Make Screenshots for This Page…), then
    /// the section's others.
    static func actions(for section: AppWorkspaceSection, detail: WorkspaceAutopilotDetail?) -> [Self] {
        let actions = actions(for: section)
        guard let detail, detail.section == section else { return actions }
        let lead: Self = switch detail {
        case .event: .makeEventArtwork
        case .productPage: .makePageScreenshots
        case .noEvents: .suggestEvent
        }
        return [lead] + actions.filter { $0 != lead }
    }

    /// What it's called: a verb for what it makes. On a detail page, what
    /// it makes for that page.
    func title(version: String? = nil, sourceLanguage: String? = nil, detail: WorkspaceAutopilotDetail? = nil) -> String {
        switch self {
        case .makeEventArtwork where detail == .event:
            String(localized: "Make the Artwork…")
        case .makePageScreenshots where detail == .productPage:
            String(localized: "Make Screenshots for This Page…")
        case .writeWhatsNew:
            version.map { String(localized: "Write What’s New for \($0)…") } ?? String(localized: "Write What’s New…")
        case .suggestSourceLanguageOnly:
            sourceLanguage.map { String(localized: "Suggest for \($0) Only…") } ?? String(localized: "Suggest for the Primary Language Only…")
        default:
            Self.titles[self] ?? ""
        }
    }

    /// The titles that name nothing but the action.
    private static var titles: [Self: String] {
        [
            .suggestEverything: String(localized: "Suggest Everything…"),
            .suggestTexts: String(localized: "Suggest Texts…"),
            .translateNewLanguage: String(localized: "Translate into a New Language…"),
            .askSomethingElse: String(localized: "Ask Claude Code Something Else…"),
            .makeScreenshots: String(localized: "Make Screenshots…"),
            .makeAppPreview: String(localized: "Make the App Preview…"),
            .makeArtwork: String(localized: "Make Header and Search Artwork…"),
            .recaptureSome: String(localized: "Capture Some Screens Again…"),
            .suggestPages: String(localized: "Suggest Pages…"),
            .makePageScreenshots: String(localized: "Make Screenshots for a Page…"),
            .makeEventArtwork: String(localized: "Make Event Artwork…"),
            .writeEventTexts: String(localized: "Write Event Texts…"),
            .checkEventsForReview: String(localized: "Check It Will Pass App Review…"),
            .suggestEvent: String(localized: "Suggest an Event…", comment: "kind:menu-item"),
            .suggestNomination: String(localized: "Suggest a Nomination…"),
            .writeNominationDescription: String(localized: "Write the Description…"),
            .suggestAnswers: String(localized: "Suggest Answers…"),
            .checkPrivacy: String(localized: "Check Privacy Against the Code…"),
            .suggestPrices: String(localized: "Suggest Prices…"),
            .makeReviewScreenshots: String(localized: "Make Review Screenshots…"),
            .writeRetentionOffer: String(localized: "Write a Retention Offer…"),
            .draftReplies: String(localized: "Draft Replies…"),
            .replyAutomatically: String(localized: "Reply Automatically…"),
            .summarizeRequests: String(localized: "Summarize What People Ask For…"),
            .findWhatToTry: String(localized: "Find What to Try…"),
            .explainChange: String(localized: "Explain a Change…"),
        ]
    }

    /// The menu's symbol column (README-DS §13, board 57 after the SF
    /// Symbols pass): one symbol per verb, sparkles for Suggest and for
    /// what has no verb of its own.
    var systemImage: String {
        switch self {
        case .makeScreenshots, .makePageScreenshots: "iphone"
        case .makeAppPreview: "film"
        case .makeArtwork, .makeEventArtwork: "photo"
        case .recaptureSome: "arrow.clockwise"
        case .writeWhatsNew, .writeEventTexts, .writeNominationDescription, .writeRetentionOffer: "square.and.pencil"
        case .translateNewLanguage: "translate"
        case .askSomethingElse, .draftReplies: "text.bubble"
        case .checkPrivacy, .checkEventsForReview: "checkmark.shield"
        case .replyAutomatically: "bolt"
        case .summarizeRequests: "doc.text"
        case .findWhatToTry: "lightbulb"
        case .explainChange: "questionmark.circle"
        case .suggestEverything, .suggestTexts, .suggestSourceLanguageOnly, .suggestPages, .suggestEvent, .suggestNomination,
             .suggestAnswers, .suggestPrices, .makeReviewScreenshots:
            "sparkles"
        }
    }

    /// The Pro feature it is, when Free can't run it.
    var paywall: PaywallContext? {
        switch self {
        case .makeScreenshots, .makeAppPreview, .makeArtwork, .makePageScreenshots, .draftReplies, .summarizeRequests: .autopilot
        case .makeEventArtwork: .eventArtwork
        case .writeRetentionOffer: .retention
        default: nil
        }
    }

    /// Where it runs: the section whose own flow it starts, or nil when
    /// the toolbar asks Claude Code itself.
    var section: AppWorkspaceSection? {
        switch self {
        case .suggestEverything: .overview
        case .suggestTexts, .translateNewLanguage: .storePage
        case .makeScreenshots, .makeAppPreview, .makeArtwork: .screenshots
        case .suggestPages, .makePageScreenshots: .productPages
        case .makeEventArtwork: .inAppEvents
        case .suggestAnswers, .checkPrivacy: .appInformation
        // Pricing knows the products missing one, their plans and prices.
        case .makeReviewScreenshots: .subscriptionPricing
        // Free sees the settings with Upgrade…; Turn On waits for Pro.
        case .replyAutomatically: .reviews
        case .writeEventTexts, .checkEventsForReview, .suggestEvent, .suggestNomination, .writeNominationDescription, .writeWhatsNew,
             .suggestSourceLanguageOnly, .askSomethingElse, .recaptureSome,
             .suggestPrices, .writeRetentionOffer, .draftReplies, .summarizeRequests, .findWhatToTry, .explainChange:
            nil
        }
    }

    /// Working on it needs the person's assistant (Claude Code or one
    /// connected over MCP); the section flows check it themselves.
    var asksAssistant: Bool { section == nil }
}
