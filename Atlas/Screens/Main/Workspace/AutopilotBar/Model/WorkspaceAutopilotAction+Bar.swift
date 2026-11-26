//
//  WorkspaceAutopilotAction+Bar.swift
//  Atlas
//

import Foundation

extension WorkspaceAutopilotAction {
    /// Its button beside the Autopilot bar's field (board 80): the verb,
    /// short, without “…”, since a click sends it at once.
    func shortTitle(fullTitle: String) -> String {
        switch self {
        case .translateNewLanguage: String(localized: "Translate", comment: "kind:button · the Autopilot bar's button for Translate into a New Language…")
        case .makeAppPreview: String(localized: "App Preview", comment: "kind:button · the Autopilot bar's button for Make the App Preview…")
        case .makeArtwork: String(localized: "Header Art", comment: "kind:button · the Autopilot bar's button for Make Header and Search Artwork…")
        case .writeWhatsNew: String(localized: "What’s New", comment: "kind:button · the Autopilot bar's button for Write What’s New…")
        case .writeRetentionOffer: String(localized: "Retention Offer", comment: "kind:button · the Autopilot bar's button for Write a Retention Offer…")
        case .checkPrivacy: String(localized: "Check Privacy", comment: "kind:button · the Autopilot bar's button for Check Privacy Against the Code…")
        case .summarizeRequests: String(localized: "Summarize", comment: "kind:button · the Autopilot bar's button for Summarize What People Ask For…")
        case .makeReviewScreenshots:
            String(localized: "Review Screenshots", comment: "kind:button · the Autopilot bar's button for Make Review Screenshots…")
        case .makeEventArtwork: String(localized: "Event Artwork", comment: "kind:button · the Autopilot bar's button for Make Event Artwork…")
        case .writeEventTexts: String(localized: "Event Texts", comment: "kind:button · the Autopilot bar's button for Write Event Texts…")
        case .checkEventsForReview:
            String(localized: "Check App Review", comment: "kind:button · the Autopilot bar's button for Check It Will Pass App Review…")
        case .replyAutomatically: String(localized: "Auto-Reply", comment: "kind:button · the Autopilot bar's button for Reply Automatically…")
        case .makePageScreenshots: String(localized: "Page Screenshots", comment: "kind:button · the Autopilot bar's button for Make Screenshots for a Page…")
        default: fullTitle.hasSuffix("…") ? String(fullTitle.dropLast()) : fullTitle
        }
    }

    /// The line under it in the open bar's list: what it makes, from what.
    var subtitle: String? {
        switch self {
        case .suggestEverything: String(localized: "Every section, every language", comment: "kind:description · an Autopilot action")
        case .writeWhatsNew: String(localized: "From the commits since the last version", comment: "kind:description · an Autopilot action")
        case .suggestTexts: String(localized: "Every field in this language", comment: "kind:description · an Autopilot action")
        case .suggestSourceLanguageOnly: String(localized: "The primary language; the others follow", comment: "kind:description · an Autopilot action")
        case .translateNewLanguage: String(localized: "A whole page, in a new language", comment: "kind:description · an Autopilot action")
        case .makeScreenshots: String(localized: "Captures, design, every language", comment: "kind:description · an Autopilot action")
        case .makeAppPreview: String(localized: "From real captures", comment: "kind:description · an Autopilot action")
        case .makeArtwork: String(localized: "With Claude Design, in this app’s look", comment: "kind:description · an Autopilot action")
        case .recaptureSome: String(localized: "Only the screens that changed", comment: "kind:description · an Autopilot action")
        case .suggestPages: String(localized: "From reviews, analytics and keywords", comment: "kind:description · an Autopilot action")
        case .makePageScreenshots: String(localized: "For the page you open", comment: "kind:description · an Autopilot action")
        case .makeEventArtwork: String(localized: "For the event you open", comment: "kind:description · an Autopilot action")
        case .writeEventTexts: String(localized: "Every event, every language", comment: "kind:description · an Autopilot action")
        case .checkEventsForReview: String(localized: "Deep links, dates and texts", comment: "kind:description · an Autopilot action")
        case .suggestEvent: String(localized: "From what’s coming in the next version", comment: "kind:description · an Autopilot action")
        case .suggestNomination: String(localized: "From the next version and your events", comment: "kind:description · an Autopilot action")
        case .writeNominationDescription: String(localized: "From What’s New and your events", comment: "kind:description · an Autopilot action")
        case .suggestAnswers: String(localized: "Age Rating, Privacy, Accessibility", comment: "kind:description · an Autopilot action")
        case .checkPrivacy: String(localized: "Reads the project for data use", comment: "kind:description · an Autopilot action")
        case .suggestPrices: String(localized: "By purchasing power and your sales", comment: "kind:description · an Autopilot action")
        case .makeReviewScreenshots: String(localized: "For App Review, one per product", comment: "kind:description · an Autopilot action")
        case .writeRetentionOffer: String(localized: "A message and an offer when people cancel", comment: "kind:description · an Autopilot action")
        case .draftReplies: String(localized: "Unanswered reviews, in their language", comment: "kind:description · an Autopilot action")
        case .replyAutomatically: String(localized: "New reviews, with rules you set", comment: "kind:description · an Autopilot action")
        case .summarizeRequests: String(localized: "Reviews grouped by request", comment: "kind:description · an Autopilot action")
        case .findWhatToTry: String(localized: "From the last 4 weeks of reports", comment: "kind:description · an Autopilot action")
        case .explainChange: String(localized: "Pick a mark on the chart", comment: "kind:description · an Autopilot action")
        }
    }
}
