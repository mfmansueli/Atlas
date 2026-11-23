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

    /// Where a product page's screens captured again are uploaded (Make
    /// Screenshots for This Page): `POST /page-shots/<run token>` with the
    /// PNG as the body.
    static let pageShotsPath = "/page-shots/"

    static func pageShotsUploadURL(port: UInt16, token: String) -> String {
        "http://\(host):\(port)\(pageShotsPath)\(token)"
    }

    /// Where an In-App Event's card or details page file is uploaded:
    /// `POST /event-artwork/<token>/<app ID>?name=<file name>` with the
    /// image or video as the body.
    static let eventArtworkPath = "/event-artwork/"

    /// An app's event art upload link, for this launch.
    static func eventArtworkUploadURL(port: UInt16, token: String, appID: String) -> String {
        "http://\(host):\(port)\(eventArtworkPath)\(token)/\(appID)"
    }

    /// Where a screenshot file for a set is uploaded (screenshots by hand):
    /// `POST /screenshot-file/<token>/<app ID>?name=<file name>` with the
    /// PNG or JPEG as the body.
    static let screenshotFilePath = "/screenshot-file/"

    static func screenshotFileUploadURL(port: UInt16, token: String, appID: String) -> String {
        "http://\(host):\(port)\(screenshotFilePath)\(token)/\(appID)"
    }

    /// The review screenshot upload link: a subscription's or in-app
    /// purchase's App Review screenshot for `propose_purchase_review_screenshot`.
    static let reviewScreenshotPath = "/review-screenshot/"

    static func reviewScreenshotUploadURL(port: UInt16, token: String, appID: String) -> String {
        "http://\(host):\(port)\(reviewScreenshotPath)\(token)/\(appID)"
    }

    static func url(port: UInt16) -> String {
        "http://\(host):\(port)\(path)"
    }

    /// The stdio bridge Claude Code, Claude Desktop and Codex launch, inside
    /// this app.
    static var bridgePath: String {
        Bundle.main.bundleURL.appending(path: "Contents/MacOS/\(bridgeName)").path(percentEncoded: false)
    }

    /// "127.0.0.1:47321", as Settings shows it.
    static func address(port: UInt16) -> String {
        "\(host):\(port)"
    }

    /// How to write what the person reads on a card (mcp-copy-changes §2),
    /// right after the instructions' second sentence.
    static let voice = """
    Everything you write for the person (titles, why, details, review themes, notes) is shown on a card in Atlas, so \
    write it the way Atlas writes: short, plain, second person, result first. Titles: what changes, at most 8 words \
    ("Lifetime: $79.99 → $59.99"). Why: the strongest evidence, one sentence, one number, at most 110 characters \
    ("9 of your last 220 reviews call it too expensive."). Everything else goes in details. Don't describe yourself or \
    how you worked ("I analysed…", "Claude found…"); say what you found. Words: suggestion, push, Review & Push. Never: \
    simply, just, easily, seamlessly, powerful, leverage, magic, please, successfully, "!". Round numbers people read; \
    exact ones in details.
    """

    /// What `initialize` tells the assistant about the server.
    static let instructions = """
    Atlas manages the App Store Connect data of the person's apps: store listings, subscription prices \
    and app information. Read with the list_ and get_ tools. \(voice) Change things with the propose_ tools: each \
    proposal is validated like a manual edit and queued in Atlas, where the person reviews and pushes \
    it. You can't push, and nothing reaches App Store Connect until the person does. When a proposal is \
    refused, the reason says how to fix it. Read only what you need: whole answers can outgrow what you take in at \
    once, so get_listing takes locales and fields (e.g. fields: ["whatsNew"]) and get_in_app_events takes eventId \
    and include. \(StoreTextRules.summary) Screenshot Autopilot runs are driven by you: once the person \
    starts one, call get_capture_plan, then next_step after each step until it says done. A simulator this Mac \
    lacks while its runtime is installed, Atlas makes itself (next_step waits meanwhile): report a device with \
    affectsDevice only when its runtime is missing. When the app's \
    screens change outside a run, send new ones with propose_screens and new steps, sample data or setup \
    commands with update_capture_plan: they wait for the person in the next plan. When only some captures no \
    longer show the app as it is (texts rewritten in a language, a redesigned screen), don't send the person back \
    to Autopilot: ask to redo just those with request_recapture (and a product page's with \
    request_page_recapture), even when no Autopilot run was saved (the run is then made from the captures the \
    set uses), or mark them out of date with mark_captures_stale; the person accepts, and \
    get_capture_plan and next_step then ask only for those. To change one language's set by hand, read it with \
    get_screenshot_context's locale and displayType, then propose a file with propose_screenshot_file, screenshots to \
    delete with propose_screenshot_removal or a new order with propose_screenshot_order: each waits on its language \
    page for the person. To find what to improve, read \
    the get_analytics_ tools (the funnel from impression to paid subscriber, where it's weak, subscriptions), \
    propose the fix, and say why with add_finding; never quote a rate marked tooFewToTell. After release, read \
    the reviews with get_reviews, suggest a reply to each in the reviewer's own language with \
    propose_review_replies and group what people write about with propose_review_themes: the person sends every \
    reply, you never do. In-App Event texts, retention messages and review replies have their own rules (no prices \
    or offers in events and retention messages, no marketing in replies), in their tools and get_ results' \
    textRules; a text that breaks one is refused. For In-App Events, read get_in_app_events (it leaves out \
    mediaDetails and design unless you ask with include; eventId reads one event); propose a new one with \
    propose_in_app_event, write the missing languages with propose_event_texts, and change texts a language \
    already has with its revise: true and why (only the texts you send change; the person sees what changed). An \
    event goes to App Review only with a deep link: set a \
    draft's deep link, purpose, priority or primary language with propose_event_details (its missingForReview says \
    what's left), and move dates that have passed, which App Store Connect refuses, with its publishStart, eventStart \
    and eventEnd (leave App Review up to 2 days before the card shows: reviewWarnings); dates the person queued \
    themselves stay, and yours wait beside them as a suggestion. Whenever you propose a \
    deep link (there or in propose_in_app_event), check in the project that \
    the app opens it on that event and report it with report_deep_link_check; a check made before the event's \
    dates moved is marked stale in get_in_app_events (deepLinkCheck.stale): check it again. Withdraw your own \
    suggestions that went stale: event texts and revisions with withdraw_event_texts, suggest_fields' ones with \
    withdraw_suggestion (or send the field again with suggest_fields to replace yours, or to give it a new reason). \
    Make an event's card (16:9) and details page (9:16) with \
    render_event_artwork (an HTML page, or an image or video loop sent to get_in_app_events' artworkUpload link), \
    which shows it under the event's text and checks it against Apple's rules, then queue it with \
    propose_event_artwork, for the primary language unless a language needs art of its own (the others show the \
    primary's): the person accepts it and pushes it. When the person asked for an event's artwork in Atlas \
    (Make the Artwork), read get_event_artwork_brief and send each concept with propose_event_artwork_concept: the \
    person chooses one there. For custom product pages, read get_product_pages; suggest a whole page with \
    propose_product_page (who it's for, its evidence from Analytics, the reviews or the approved version's keywords, \
    keywords no other page uses, promotional text in each language, the screens' order) and texts for a page's \
    languages with propose_product_page_texts: the person accepts each, and pushing, submitting and making a page \
    visible are theirs. When the person asked for a page's own screenshots (Make Screenshots for This Page), read \
    get_page_screenshots and send the plan with propose_page_screenshots: the default set's screens in the page's \
    order and a caption for each in every language; Atlas lays them out. When its look is claudeDesign, send three \
    looks with propose_page_look; when it has recapture, capture the screens that should show something else in the \
    Simulator and name each with report_page_capture. To A/B test the header or search results image (Product \
    Page Optimization), read get_page_tests (the app's tests, what each placement can be tested with, results aren't \
    in the API) and propose one with propose_page_test, its reason and evidence: one placement, one treatment (the \
    Autopilot run's variant, asked for when there's none, or an image in the app's library); App Store Connect runs \
    one test at a time, so a test that isn't over refuses it. The person creates it from Review & Push; a draft in \
    the way can be proposed for deletion (action: deleteDraft). When a release needs a new App Store version, read \
    get_app_versions and propose it with propose_app_version (the project's MARKETING_VERSION is a good number); \
    App Store Connect creates it when the person pushes. When a release changes what a subscription or in-app \
    purchase unlocks, update its Review Notes for App Review in the same task: get_in_app_review_notes, then \
    propose_in_app_review_note. When the project's prices change (StoreKit product IDs, a .storekit file, the \
    paywall, a price constant), compare them with get_app_price_and_availability, get_subscriptions and get_prices \
    and propose the difference with propose_prices, propose_subscription, propose_app_price or \
    propose_availability, with file and line as evidence. Offers the project's code uses (a promotional offer's \
    identifier, a win-back offer, an offer code or custom code the app or its marketing names) are read from \
    get_subscriptions' promotionalOffers, winBackOffers and offerCodes and proposed with \
    propose_promotional_offer, propose_win_back_offer and propose_offer_code (also to change a promotional \
    offer's prices, a win-back offer's eligibility, dates or priority, or to delete or deactivate one); a new \
    subscription still queued by propose_subscription takes them too, pushed after it; an in-app purchase's \
    offer codes, in get_subscriptions' inAppPurchases, with propose_in_app_purchase_offer_code. \
    App Compliance answers (trader status, ICP Filing Number, \
    China mainland's AI content filing and Security Assessment, medical device) are suggested with get_compliance \
    and propose_compliance_answers; the person accepts each and enters it in App Store Connect. \
    Only stopping sales in China mainland becomes a change in Review & Push. Export compliance comes from the code's \
    use of encryption: get_export_compliance, then propose_export_compliance queues the build's answer and any \
    encryption declaration in Review & Push. Once that answer is settled, the export compliance key in the app \
    target (get_export_compliance's infoPlistKey.expected) answers it for every build: when you add it in the \
    project, or find it there, report it with report_encryption_key; never push or upload. Submitting a version for App Review and releasing it are the \
    person's: read where it stands with get_release (phase, builds, What's New, phased release, submission, \
    possibleActions) and propose submit (build, release type, phased release, encryption, events), release, \
    pause, resume or complete the phased release, cancel the submission or resubmit with propose_release_action, \
    with a reason; it waits on the version card until the person confirms it: the tools only ever queue changes. App \
    Review's rejection message isn't in the API: ask the person for it. list_proposals lists yours too; withdraw them \
    with withdraw_release_action or withdraw_suggestion and the rp- id. Always tell the person what you couldn't see.
    """
}
