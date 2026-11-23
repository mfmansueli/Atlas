//
//  WorkspaceAutopilotAsk.swift
//  Atlas
//

import Foundation

/// What the toolbar's Autopilot button asks Claude Code for an action no
/// section had a button for: the run's purpose (so the asking buttons find
/// it), the prompt, what it's about for the toolbar and the toast, and
/// where its suggestions land. Everything comes back through Atlas's MCP
/// tools as proposals; nothing is pushed.
struct WorkspaceAutopilotAsk: Equatable {
    let purpose: ClaudeCodeRunPurpose
    let prompt: String
    /// “Store Page · What’s New”.
    let subject: String
    /// The toast's text when the run is done.
    let done: String

    /// The ask for `action`, or nil when it runs a section's own flow.
    static func make(
        _ action: WorkspaceAutopilotAction, app: String, version: String? = nil, sourceLanguage: String? = nil, question: String? = nil
    ) -> WorkspaceAutopilotAsk? {
        switch action {
        case .writeWhatsNew: whatsNew(app: app, version: version)
        case .suggestSourceLanguageOnly: sourceOnly(app: app, language: sourceLanguage)
        case .askSomethingElse: question.map { something(app: app, question: $0) }
        default: byApp[action]?(app)
        }
    }

    /// The asks that need only the app's name.
    private static var byApp: [WorkspaceAutopilotAction: (String) -> WorkspaceAutopilotAsk] {
        [
            .recaptureSome: recapture(app:),
            .writeEventTexts: eventTexts(app:),
            .checkEventsForReview: eventsReview(app:),
            .suggestPrices: prices(app:),
            .writeRetentionOffer: retention(app:),
            .draftReplies: replies(app:),
            .summarizeRequests: requests(app:),
            .findWhatToTry: whatToTry(app:),
            .explainChange: change(app:),
        ]
    }

    private static func eventTexts(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: InAppEventsAskPrompt.purpose, prompt: InAppEventsAskPrompt.text(app: app),
            subject: String(localized: "In-App Events · texts"), done: String(localized: "Done. Texts are in In-App Events.")
        )
    }

    private static func retention(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: RetentionAskPrompts.purpose, prompt: RetentionAskPrompts.draft(app: app),
            subject: String(localized: "Pricing · retention offer"), done: String(localized: "Done. See Pricing, under Retention.")
        )
    }

    private static func replies(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: ReviewsAskPrompt.purpose, prompt: ReviewsAskPrompt.text(app: app),
            subject: String(localized: "Reviews · replies"), done: String(localized: "Done. Replies wait under each review; none sent.")
        )
    }

    private static func whatsNew(app: String, version: String?) -> WorkspaceAutopilotAsk {
        let which = version.map { String(localized: "version \($0)") } ?? String(localized: "the version being prepared")
        return WorkspaceAutopilotAsk(
            purpose: .ask(area: String(localized: "What’s New")),
            prompt: String(localized: """
            Write What’s New for \(app)’s \(which) in Atlas. Read get_app_versions and get_listing with fields ["whatsNew"] for \
            what earlier versions said, and this project's history since the last release (git log, the changed screens) for \
            what really changed. Write it for the people who use the app: what they can do now, what was fixed, in short lines, \
            no internal names. Send it with suggest_fields for whatsNew in the primary language, then in every language the \
            app has, each in that language's own words. Describe only what this version does.
            """),
            subject: String(localized: "Store Page · What’s New"),
            done: String(localized: "Done. What’s New is in Store Page, every language.")
        )
    }

    private static func sourceOnly(app: String, language: String?) -> WorkspaceAutopilotAsk {
        let which = language ?? String(localized: "the primary language")
        return WorkspaceAutopilotAsk(
            purpose: .ask(area: String(localized: "Store Page")),
            prompt: String(localized: """
            Suggest better store texts for \(app) in Atlas, in \(which) only. Read get_listing and get_store_page for that \
            language, get_reviews for the words people use, and this project for what the app really does. Suggest the \
            subtitle, promotional text, description and keywords with suggest_fields, each with its reason and evidence. \
            Leave the other languages: they're translated afterwards.
            """),
            subject: String(localized: "Store Page · \(which)"),
            done: String(localized: "Done. Suggestions for \(which) are in Store Page.")
        )
    }

    private static func something(app: String, question: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: .ask(area: String(localized: "Store Page")),
            prompt: String(localized: """
            In Atlas, for \(app): \(question)

            Read what you need with Atlas's get_ and list_ tools and this project. Send any change as a proposal with the \
            propose_ and suggest_ tools: the person reviews and pushes it. Don't push anything.
            """),
            subject: String(localized: "Store Page · \(question)"),
            done: String(localized: "Done. Suggestions are in purple.")
        )
    }

    private static func recapture(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: .autopilot,
            prompt: String(localized: """
            Find \(app)'s screenshots in Atlas that no longer show the app as it is. Read list_captures and get_capture_plan, \
            and this project's history since they were captured: screens redesigned, texts rewritten in a language. Ask to \
            capture only those again with request_recapture (a product page's with request_page_recapture), or mark them out \
            of date with mark_captures_stale, each with why. Don't start a new run: the person accepts, and the run asks only \
            for those.
            """),
            subject: String(localized: "Screenshots · captures to redo"),
            done: String(localized: "Done. Recaptures to accept are in Screenshots.")
        )
    }

    private static func eventsReview(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: .ask(area: String(localized: "In-App Events")),
            prompt: String(localized: """
            Check that \(app)'s In-App Events in Atlas will pass App Review. Read get_in_app_events with include \
            ["mediaDetails"]: each draft's missingForReview, reviewWarnings and deepLinkCheck. Set what's missing with \
            propose_event_details (deep link, purpose, priority, dates that have passed); check in this project that the app \
            opens each deep link on its event and report it with report_deep_link_check; fix a text that breaks App Review's \
            rules with propose_event_texts and revise true. \(StoreTextGuidelinePlace.eventText.summary)
            """),
            subject: String(localized: "In-App Events · App Review check"),
            done: String(localized: "Done. Findings are on each event.")
        )
    }

    private static func prices(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: .ask(area: String(localized: "Pricing")),
            prompt: String(localized: """
            Suggest prices for \(app)'s subscriptions in Atlas. Read get_subscriptions, get_prices and get_price_points, and \
            get_analytics_subscriptions and get_analytics_breakdown by territory for where people convert and where they \
            don't. Suggest each territory's price with propose_prices, from Apple's price points only, with the evidence for \
            each: what people there pay for apps like this, and the numbers. Never quote a rate marked tooFewToTell.
            """),
            subject: String(localized: "Pricing · prices"),
            done: String(localized: "Done. Price suggestions are in Pricing.")
        )
    }

    private static func requests(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: ReviewsAskPrompt.purpose,
            prompt: String(localized: """
            Summarize what people ask \(app) for, in Atlas. Read get_reviews in every language. Group what they ask for, \
            what's broken and what they love with propose_review_themes, most mentioned first, each with its count and one \
            action. Read this project to say which requests the app already answers. Don't reply to anyone.
            """),
            subject: String(localized: "Reviews · what people ask for"),
            done: String(localized: "Done. The groups are in Reviews.")
        )
    }

    private static func whatToTry(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: .ask(area: String(localized: "Analytics")),
            prompt: String(localized: """
            Find what to try next for \(app) in Atlas. Read get_analytics_funnel (impression to paid subscriber), \
            get_analytics_breakdown by source, language and territory, and get_analytics_subscriptions. Find the two or three \
            weakest steps, propose the fix for each with Atlas's propose_ and suggest_ tools, and say why with add_finding, \
            with the numbers. Never quote a rate marked tooFewToTell.
            """),
            subject: String(localized: "Analytics · what to try"),
            done: String(localized: "Done. The findings are in Analytics.")
        )
    }

    private static func change(app: String) -> WorkspaceAutopilotAsk {
        WorkspaceAutopilotAsk(
            purpose: .ask(area: String(localized: "Analytics")),
            prompt: String(localized: """
            Explain the latest change in \(app)'s numbers in Atlas. Read get_analytics_funnel and get_analytics_breakdown for \
            the last 30 days against the 30 before, get_app_versions for what was released when, and get_reviews. Say what \
            moved, where (source, language, territory) and the likeliest reason, with add_finding. Never quote a rate marked \
            tooFewToTell.
            """),
            subject: String(localized: "Analytics · a change"),
            done: String(localized: "Done. The finding is in Analytics.")
        )
    }
}
