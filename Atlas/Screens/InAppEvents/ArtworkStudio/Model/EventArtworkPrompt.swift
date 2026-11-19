//
//  EventArtworkPrompt.swift
//  Atlas
//

import Foundation

/// What Make the Artwork starts Claude Code with (or copies, when Atlas
/// can't start it here): read the brief, find the app's own visual world,
/// design the concepts with Claude, render and look at each one
/// under the App Store's text, then send it. A change to one concept gets
/// its own prompt, and so does motion for concepts already drawn.
enum EventArtworkPrompt {
    static func purpose(eventID: String) -> ClaudeCodeRunPurpose {
        .eventArtworkConcepts(eventID: eventID)
    }

    static func text(app: String, appID: String, event: String, eventID: String, count: Int, makesMotion: Bool = false) -> String {
        let motion = makesMotion ? " " + motionStep : ""
        return String(localized: """
        The person asked Atlas for the artwork of \(app)’s In-App Event “\(event)” (app \(appID), event \(eventID)): \
        \(count) concepts from Claude, each the event card (16:9) and the event details image (9:16) as a matching \
        pair. Work in this order.
        1. Read get_event_artwork_brief: the brief in the person’s words (it comes first), the look to start from, the \
        options, the event’s texts, the app’s design, the art direction and the rules. If its design says the look is \
        missing, read it in the project and send it with report_app_support.
        2. Find the app’s visual world with Glob, Grep and Read: the look’s designSource files and the code that draws \
        its scenes, backgrounds or illustrations, above all any that fit this event. The art should look like it comes \
        from the app.
        3. Choose \(count) different ideas about this event, then make each image one full HTML page with CSS and inline \
        SVG at the canvas size, crafted as the art direction says.
        4. Render each card and details page with render_event_artwork, without motion, and look at both images it \
        returns: the art, and the art under the App Store’s text. Check them against the art direction’s selfCheck, \
        fix what fails and render again.\(motion)
        5. Send each concept with propose_event_artwork_concept, one call each, marking the one you’d choose with pick. \
        Fix every refusal and send it again.
        Never push and never submit the event: the person chooses a concept in Atlas.
        """)
    }

    /// The person asked for a moving version: step 4's second half.
    private static let motionStep = String(localized: """
    Then give both pages motion as the brief’s motionDirection says (one thing that tells the event moves, slowly, in a \
    seamless 20-second loop) and check them with render_event_artwork and motionFrames: true.
    """)

    /// Make Them Move: the concepts the person saw, animated as they are.
    static func motion(app: String, appID: String, event: String, eventID: String, concepts: [String]) -> String {
        let names = concepts.map { "“\($0)”" }.formatted(.list(type: .and))
        return String(localized: """
        The person liked the concepts for \(app)’s In-App Event “\(event)” (app \(appID), event \(eventID)) and asked \
        for them to move: \(names). Read get_event_artwork_brief: its addMotion has each concept’s two pages and its \
        motionDirection has Apple’s rules for event videos and how the loop should move. Keep every drawing exactly as it \
        is and add CSS or SVG animation to its pages: one thing that tells the event moves, slowly, the camera stays \
        put, the first frame is complete on its own and nothing flashes. Check each page with render_event_artwork and \
        motionFrames: true, fix what its loop check says, then send each concept with propose_event_artwork_concept and \
        replaces, one call each. Never push and never submit the event.
        """)
    }

    static func revision(app: String, appID: String, event: String, eventID: String, concept: String) -> String {
        String(localized: """
        The person asked for a change to the concept “\(concept)” of \(app)’s In-App Event “\(event)” (app \(appID), \
        event \(eventID)). Read get_event_artwork_brief: its revision has what they asked for, the concept’s pages and \
        its images. Redraw only that concept, keeping what they didn’t ask to change. Render it with \
        render_event_artwork and look at it under the App Store’s text before you send it with \
        propose_event_artwork_concept and replaces. Never push and never submit the event.
        """)
    }
}
