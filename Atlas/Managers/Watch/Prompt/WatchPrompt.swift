//
//  WatchPrompt.swift
//  Atlas
//

import Foundation

/// What a Look for Improvements run starts Claude Code with: one app, its
/// findings, and for each the exact tools to read and to propose with. The
/// assistant follows Atlas's voice (`MCPEndpoint.instructions`) and never
/// pushes; artwork, captures, recordings, Autopilot, replies and releases
/// stay with the person. In English, like Atlas's other instructions to
/// assistants: it's never shown as copy.
enum WatchPrompt {
    /// The tools one kind of finding is read and answered with.
    struct Tools: Hashable, Sendable {
        var reads: [String]
        var proposes: [String]

        var all: [String] { reads + proposes }
    }

    /// Tools a run must never call: they start expensive work, speak for the
    /// person, or decide what only they decide.
    static let neverCalled = [
        "propose_review_replies",
        "propose_release_action",
        "propose_event_submission",
        "render_event_artwork",
        "propose_event_artwork",
        "propose_event_artwork_concept",
        "render_artwork",
        "propose_artwork_concept",
        "next_step",
        "request_recapture",
        "request_page_recapture",
        "propose_page_screenshots",
        "start_display_recording",
        "revise_app_preview",
    ]

    static func tools(for kind: WatchSignalKind) -> Tools {
        switch kind {
        case .crashesWorse: Tools(reads: ["get_analytics_crashes", "get_release"], proposes: ["add_finding"])
        case .whatsNewMissing: Tools(reads: ["get_release", "get_listing"], proposes: ["suggest_fields"])
        case .eventDeadline: Tools(reads: ["get_in_app_events"], proposes: ["propose_event_texts", "propose_event_details", "report_deep_link_check"])
        case .reviewsAfterRelease: Tools(reads: ["get_reviews"], proposes: ["propose_review_themes"])
        case .appReviewRisk:
            Tools(
                reads: ["get_review_risks", "get_listing", "get_age_rating", "get_compliance"],
                proposes: [
                    "suggest_fields", "propose_listing_text", "propose_in_app_texts", "propose_age_rating", "propose_compliance_answers",
                    "propose_captions", "report_review_risk",
                ]
            )
        case .submissionBlocked, .versionRejected: Tools(reads: [], proposes: [])
        }
    }

    /// Every tool the prompt for `signals` names.
    static func toolNames(for signals: [WatchSignal]) -> Set<String> {
        Set(signals.filter { !$0.kind.isLocalOnly }.flatMap { tools(for: $0.kind).all } + neverCalled)
    }

    /// The prompt for `signals` (the local-only ones left out); nil when
    /// none is left to send.
    static func text(appID: StoreApp.ID, appName: String, signals: [WatchSignal]) -> String? {
        let sent = signals.filter { !$0.kind.isLocalOnly }
        guard !sent.isEmpty else { return nil }
        let items = sent.enumerated().map { index, signal in
            "\(index + 1). \(signal.summary)\n   \(instruction(for: signal))"
        }
        return """
        Look for Improvements is on for \(appName) in Atlas (appId \(appID)). Atlas's own checks found what's below; nobody asked \
        for this run and nobody is watching it. For each item, read what it names, look for the cause in the project when it \
        helps (reading files and read-only git), and send a fix only when the evidence supports one; otherwise send nothing \
        for it.

        \(items.joined(separator: "\n"))

        Rules:
        - Use only the tools named above.
        - Never call \(neverCalled.joined(separator: ", ")): artwork, captures, recordings, Autopilot, replies, submissions \
        and releases stay with the person.
        - Everything you write is shown on a card in Atlas: a title with the result first, at most 8 words; a why of one \
        sentence with one number, at most 110 characters; the rest in details. Plain words, second person, no exclamation \
        marks.
        - You can't push: every proposal waits in Atlas for the person to review.
        - End with one short line per item: what you sent, or why you sent nothing.
        """
    }

    /// What to read and send for one finding.
    static func instruction(for signal: WatchSignal) -> String {
        switch signal.kind {
        case .crashesWorse:
            """
            Read get_analytics_crashes (devices and days) and get_release, then the commits between the two versions with read-only \
            git (git log, git diff between their tags). Send one add_finding with area stability: the likely cause in the code \
            as the title, the crash number as why, the files and commits in details and read. Say the numbers are a sample. \
            Pausing a phased release is the person's decision.
            """
        case .whatsNewMissing:
            """
            Read get_release (whatsNew per language) and get_listing with fields ["whatsNew"], then the commits since the last \
            tag with git log. Send suggest_fields items with area store and field whatsNew, one per missing language, each \
            written in that language about what changed for people (no internal work), with a gloss in English and evidence \
            {kind: "git", ref: "<tag>..HEAD"}.
            """
        case .eventDeadline:
            """
            Read get_in_app_events with eventId "\(signal.subject)". For the languages it isn't written in, send \
            propose_event_texts. For a date that has passed or leaves App Review too little time, send propose_event_details \
            with dates that work (missingForReview and suggested say which). Propose a deep link only after checking in the \
            project that the app opens it, and report what you found with report_deep_link_check. Leave the card and details \
            images to the person.
            """
        case .reviewsAfterRelease:
            """
            Read get_reviews with show "all" (it also has the groups sent before). Send propose_review_themes with the subjects \
            people write about since version \(signal.subject), most mentioned first, keeping the groups sent before that still \
            hold: the call replaces them. Don't reply to reviews.
            """
        case .appReviewRisk:
            """
            Read get_review_risks for appId "\(signal.appID)". For each risk whose fix names a tool, propose that fix with it, in \
            the risk's language, following the store text rules (a rewrite must keep every Terms of Use and Privacy Policy \
            link). Leave risks only App Store Connect can fix (App Compliance, the license agreement) to the person. For each \
            project check in projectChecks that isn't answered, read the project (files and read-only git) and call \
            report_review_risk with verdict confirmed or cleared and file:line evidence. Never guess a filing number.
            """
        case .submissionBlocked, .versionRejected:
            ""
        }
    }
}
