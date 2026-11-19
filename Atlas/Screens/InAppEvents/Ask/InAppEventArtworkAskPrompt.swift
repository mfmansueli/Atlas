//
//  InAppEventArtworkAskPrompt.swift
//  Atlas
//

import Foundation

/// What "Ask Claude Code…" on an event's Images and video starts Claude
/// Code with, or copies: design that event's card and details page the way
/// Autopilot's HTML pages are made (from the app's look, its
/// design project when one is connected, and the project's own visuals),
/// as pages Atlas renders still or as seamless loops, check them and
/// queue them.
enum InAppEventArtworkAskPrompt {
    /// The run's purpose, so the button finds its own run for this event.
    static func purpose(eventID: String) -> ClaudeCodeRunPurpose {
        .eventArtwork(eventID: eventID)
    }

    static func text(app: String, appID: String, event: String, eventID: String) -> String {
        String(localized: """
        Design the art for \(app)’s In-App Event “\(event)” (app \(appID), event \(eventID)) in Atlas with Claude \
        Design: its card (16:9) and its details page (9:16). Read the event with get_in_app_events: its badge, texts, \
        dates, which languages lack their own card or details page, and `design`, the app's look and design language, \
        what Atlas knows of the app, its design project and the art direction (the idea, where the App Store lays its \
        text, the craft and the check of each render). If `design` says the look is missing, read it in the project and \
        send it with report_app_support first. When the design project opens from here, design in it; when it doesn't, \
        design from what `design` gives, and never stop for it. Look at how the project draws its own visuals (scenes, \
        backgrounds, motifs, animated loops) with Glob, Grep and Read, so the art belongs to the app and to the event's \
        theme. Make each piece one page of HTML, CSS and inline SVG at the canvas size, crafted as the art \
        direction says, with motion as CSS or SVG animation that loops seamlessly over 20 seconds (JavaScript doesn't \
        run, and nothing loads from the web), and render it with render_event_artwork and motion: true for a video, or \
        without motion for a still. When the project renders its own scenes and you can run that, you may render a piece \
        with it instead and send the file with curl -s --data-binary @<file> '<artworkUpload link>?name=<file name>'. No \
        words or logos in the art, and no border or gradient overlay of your own: the App Store lays its own fade under \
        the text, while color that belongs to the scene, like a sky, is fine. Keep the lower part dark and quiet, where \
        Apple lays the badge, name and description, but still part of the scene. Look at each render under the event's \
        text, check it against the art direction's selfCheck, and fix what fails, every refusal and the warnings you \
        can. Then queue the card and the details page with propose_event_artwork for the languages that need them (the \
        primary language's shows in the others). Never push and never submit the event for review: the person accepts \
        and pushes it.
        """)
    }
}
