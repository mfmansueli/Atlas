//
//  InAppEventDesignFacts.swift
//  Atlas
//

import Foundation

/// get_in_app_events' `design`: what an event's card and details page are
/// designed from, the way Autopilot's HTML pages are. It has the
/// app's look and design language, what Atlas knows of the app, and its
/// design project, with how to make each piece as a page Atlas renders,
/// still or as a seamless loop, and the art direction every brief has.
enum InAppEventDesignFacts {
    static func json(look: AppLookProfile?, knowledge: AppKnowledge?, project: DesignProject?) -> JSONValue {
        var design: [String: JSONValue] = ["how": .string(how), "artDirection": EventArtworkDirection.json]
        if let look {
            design["look"] = look.mcpJSON
        } else {
            design["lookMissing"] = .string("""
            Atlas doesn't have the app's look yet. Read it in the project (design docs, the theme in code, the icon) and \
            send it with report_app_support's look before designing, so this art and the next start from it.
            """)
        }
        if let knowledge, !knowledge.isEmpty { design["knowledge"] = knowledge.mcpJSON }
        if let project { design["designProject"] = projectJSON(project) }
        return .object(design)
    }

    /// How each piece is made: an HTML page, rendered by Atlas.
    static let how = """
    Design the card and the details page as HTML pages: one full HTML page each, with CSS and inline SVG, laid \
    out at the canvas size (3840 × 2160 for the card, 2160 × 3840 for the details page), built from the app's own world \
    (the look's colors, motifs and personality, and the scenes the project draws) and about the event, as artDirection \
    says. Keep them without words or logos, and the lower part dark and quiet but still part of the scene. Render each \
    with render_event_artwork, look at it under the App Store's text and fix it against artDirection's selfCheck. Give a \
    page motion with CSS or SVG animation (page JavaScript doesn't run, and nothing loads from the web) that loops \
    seamlessly over 20 seconds, so the last moment matches the first, then render it with motion: true for the video, \
    or without motion for a still.
    """

    /// The connected project: design in it when it can be opened from
    /// where the assistant runs, else from what was found in it.
    private static func projectJSON(_ project: DesignProject) -> JSONValue {
        var json: [String: JSONValue] = [
            "kind": .string(project.kind.rawValue),
            "source": .string(project.link),
            "use": """
            Design the event's art in this project when you can open it (Claude Design, Figma), in its colors, type and \
            motifs, then bring each piece back as the HTML page for render_event_artwork.
            """,
            "ifYouCantOpenIt": """
            Don't stop: design from the summary and the look here. Claude Code that Atlas starts has only Atlas's tools.
            """,
        ]
        if let summary = project.summary { json["summary"] = summary.mcpJSON }
        return .object(json)
    }
}
