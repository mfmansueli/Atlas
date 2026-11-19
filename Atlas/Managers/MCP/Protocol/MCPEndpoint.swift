//
//  MCPEndpoint.swift
//  Atlas
//

import Foundation

/// Where the MCP server listens and what it calls itself.
enum MCPEndpoint {
    static let host = "127.0.0.1"
    static let defaultPort: UInt16 = 47321
    static let path = "/mcp"
    /// Where a client trades a pairing code for its token.
    static let pairingPath = "/mcp/pair"
    /// The stdio bridge's name, in the app bundle's `Contents/MacOS`.
    static let bridgeName = "atlas-mcp"
    /// The name assistants show for the server, as in `mcp__atlas__…`.
    static let serverName = "atlas"

    /// Where Screenshot Autopilot's captures are uploaded: `POST
    /// /autopilot/<run token>` with the PNG as the body.
    static let autopilotPath = "/autopilot/"

    /// A run's upload link.
    static func autopilotUploadURL(port: UInt16, token: String) -> String {
        "http://\(host):\(port)\(autopilotPath)\(token)"
    }

    /// Where an In-App Event's card or details page file is uploaded:
    /// `POST /event-artwork/<token>/<app ID>?name=<file name>` with the
    /// image or video as the body.
    static let eventArtworkPath = "/event-artwork/"

    /// An app's event art upload link, for this launch.
    static func eventArtworkUploadURL(port: UInt16, token: String, appID: String) -> String {
        "http://\(host):\(port)\(eventArtworkPath)\(token)/\(appID)"
    }

    static func url(port: UInt16) -> String {
        "http://\(host):\(port)\(path)"
    }

    /// The stdio bridge Claude Desktop and Codex launch, inside this app.
    static var bridgePath: String {
        Bundle.main.bundleURL.appending(path: "Contents/MacOS/\(bridgeName)").path(percentEncoded: false)
    }

    /// "127.0.0.1:47321", as Settings shows it.
    static func address(port: UInt16) -> String {
        "\(host):\(port)"
    }

    /// What `initialize` tells the assistant about the server.
    static let instructions = """
    Atlas manages the App Store Connect data of the person's apps: store listings, subscription prices \
    and app information. Read with the list_ and get_ tools. Change things with the propose_ tools: each \
    proposal is validated like a manual edit and queued in Atlas, where the person reviews and pushes \
    it. You can't push, and nothing reaches App Store Connect until the person does. When a proposal is \
    refused, the reason says how to fix it. \(StoreTextRules.summary) Screenshot Autopilot runs are driven by you: once the person \
    starts one, call get_capture_plan, then next_step after each step until it says done. When the app's \
    screens change outside a run, send new ones with propose_screens and new steps, sample data or setup \
    commands with update_capture_plan: they wait for the person in the next plan. To find what to improve, read \
    the get_analytics_ tools (the funnel from impression to paid subscriber, where it's weak, subscriptions), \
    propose the fix, and say why with add_finding; never quote a rate marked tooFewToTell. After release, read \
    the reviews with get_reviews, suggest a reply to each in the reviewer's own language with \
    propose_review_replies and group what people write about with propose_review_themes: the person sends every \
    reply, you never do. In-App Event texts, retention messages and review replies have their own rules (no prices \
    or offers in events and retention messages, no marketing in replies), in their tools and get_ results' \
    textRules; a text that breaks one is refused. For In-App Events, read get_in_app_events; propose a new one with propose_in_app_event and \
    write the missing languages with propose_event_texts. Make an event's card (16:9) and details page (9:16) with \
    render_event_artwork (an HTML page, or an image or video loop sent to get_in_app_events' artworkUpload link), \
    which shows it under the event's text and checks it against Apple's rules, then queue it with \
    propose_event_artwork: the person accepts it and pushes it. When the person asked for an event's artwork in Atlas \
    (Make the Artwork), read get_event_artwork_brief and send each concept with propose_event_artwork_concept: the \
    person chooses one there. When a release needs a new App Store version, read \
    get_app_versions and propose it with propose_app_version (the project's MARKETING_VERSION is a good number); \
    App Store Connect creates it when the person pushes. App Compliance answers (trader status, ICP Filing Number, \
    China mainland's AI content filing and Security Assessment, medical device) are suggested with get_compliance \
    and propose_compliance_answers; the person accepts each and enters it in App Store Connect. Submitting a version or an event for App Review and \
    releasing it are the person's: there is no tool for either, and the tools only ever queue changes. Always tell \
    the person what you couldn't see.
    """
}
