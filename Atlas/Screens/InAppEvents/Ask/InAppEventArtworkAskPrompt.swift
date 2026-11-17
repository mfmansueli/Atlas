//
//  InAppEventArtworkAskPrompt.swift
//  Atlas
//

import Foundation

/// What "Ask Claude Code…" on an event's Images and video starts Claude
/// Code with, or copies: make that event's card and details page, check
/// them and queue them.
enum InAppEventArtworkAskPrompt {
    /// The run's purpose, so the button finds its own run for this event.
    static func purpose(eventID: String) -> ClaudeCodeRunPurpose {
        .eventArtwork(eventID: eventID)
    }

    static func text(app: String, appID: String, event: String, eventID: String) -> String {
        String(localized: """
        Make the art for \(app)’s In-App Event “\(event)” (app \(appID), event \(eventID)) in Atlas: its card (16:9) \
        and its details page (9:16). Read the event with get_in_app_events: its badge, texts, dates, which languages lack \
        their own card or details page, and the artworkUpload link. Find how the app's project draws its own visuals \
        (scenes, backgrounds, animated loops, a render script) with Glob, Grep and Read, and make the art from them. Where \
        you can run the project's renderer, render the card and the details page at the event's sizes and send each file \
        with curl -s --data-binary @<file> '<artworkUpload link>?name=<file name>'. Where you can't, redraw them as one \
        static page of HTML, CSS and inline SVG for render_event_artwork (JavaScript doesn't run there). No words or logos \
        in the art, and no border or gradient overlay of your own: the App Store lays its own fade under the text, while \
        color that belongs to the scene, like a sky, is fine. Keep the lower part calm, where Apple lays the badge, name \
        and description, and make a video a seamless loop at 30 or 60 fps. Check each with render_event_artwork, look at \
        it under the event's text, and fix every refusal and the warnings you can. Then queue the card and the details \
        page with propose_event_artwork for the languages that need them (the primary language's shows in the others). \
        Never push and never submit the event for review: the person accepts and pushes it.
        """)
    }
}
