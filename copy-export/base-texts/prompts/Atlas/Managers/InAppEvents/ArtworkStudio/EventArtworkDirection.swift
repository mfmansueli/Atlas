//
//  EventArtworkDirection.swift
//  Atlas
//

import Foundation

/// What good In-App Event art is, as every brief tells Claude. Apple's
/// own guidance is short: no words or logos, no borders or gradients, the card
/// and the details page alike, seamless loops. The rest is art direction:
/// the idea (this event, from the app's own world), where the App Store lays
/// its text over the art, the craft that makes an HTML page look like a
/// finished illustration rather than clip art, and the check of each render
/// before it's sent.
///
/// The first Alba run without it (2026-11-18) drew the app's mark on an empty
/// night sky three times, never looked at a render and left the lower 40%
/// as a flat dark band, so each line here answers one of those.
enum EventArtworkDirection {
    /// The brief's and `design`'s `artDirection`.
    static var json: JSONValue {
        [
            "idea": .array(idea.map(JSONValue.string)),
            "appStoreLayout": [
                "card": .string(cardLayout),
                "details": .string(detailsLayout),
                "lowerPart": .string(lowerPart),
            ],
            "craft": .array(craft.map(JSONValue.string)),
            "pair": .string(pair),
            "selfCheck": .array(selfCheck.map(JSONValue.string)),
        ]
    }

    /// What the art is about and where it comes from.
    static let idea = [
        """
        Show this event, not the app in general: what people do or feel during it (a week of grateful mornings, sharing \
        kindness at Christmas, a fresh start in January), told in one image without words.
        """,
        """
        Build it from the app's own world: the scenes, backgrounds, illustrations and motifs the project draws (read the \
        look's designSource files and the code that draws them). If the app already has a scene that fits the event, such \
        as a holiday, fireworks or a season, start from it. The art should look like the app on its best day.
        """,
        """
        Make it this event's alone: find what's particular to it in its own texts (gratitude is warmth between people \
        and small kind moments; a 30-day January streak is a fresh start and a climb). Two events of one app share its \
        world and colors, never the same idea, even with the same badge.
        """,
        """
        Don't redraw the app's icon or mark as the subject: it's a logo, and Apple asks for none. A motif the mark comes \
        from, like a sun or a horizon, is fine as part of a scene.
        """,
        """
        Aim for the art Apple features on the Today tab: a finished, full-bleed illustration with one clear subject, depth \
        and light. Never a centered symbol on an empty background, a diagram, a pattern or the app's interface.
        """,
        """
        Make the concepts different ideas, not three versions of one: different subjects, compositions and viewpoints, \
        such as a wide landscape, a close-up of one object, or a gathering of figures or lights.
        """,
        """
        One image is shown in every country the event runs in, so prefer what's true everywhere (warm lights, a night \
        sky, people together) over what fits one hemisphere or culture, like snow in December, unless the event is about it.
        """,
    ]

    static let cardLayout = """
    Shown about 340 to 640 points wide with rounded corners, in search, on Today and on the product page. Apple darkens \
    the lower 60% with its own fade and writes, from the lower left, the badge, the event's name in bold (up to two lines) \
    and the short description, with the app's icon, name and Get button under them. Put the subject in the upper two \
    thirds, at the center or on the right, big enough to read at 340 points wide: a third of the height or more, and at \
    least 6% inside every edge, since the corners are rounded.
    """

    static let detailsLayout = """
    The top of the event's page, full width on iPhone. Apple fades the lower half and writes the badge, the name and the \
    long description there; the top 8% sits under the status bar and the close button. Put the subject in the \
    upper middle, between about 15% and 55% of the height.
    """

    static let lowerPart = """
    From 60% of the height down, Atlas checks that the art is dark (mean luminance under 0.6) and quiet (few sharp \
    edges) so Apple's white text reads. Keep it part of the picture: ground, water, hills, haze or soft shadow that \
    continue the scene. Never an empty band of flat color.
    """

    /// How a page of HTML, CSS and inline SVG at 3840 pixels looks
    /// finished.
    static let craft = [
        """
        Depth: three to six layers from back to front (sky, far forms, middle, near silhouettes). Each nearer layer is \
        darker and sharper, the far ones hazier and closer to the sky's color.
        """,
        """
        Light: one clear source the whole scene answers to, with a glow around it (radial gradients, feGaussianBlur), rim \
        light on the edges that face it, and its color in reflections and on the ground.
        """,
        """
        Organic shapes: ridges, hills, clouds, plants and figures as paths with many points and varied curves. Never \
        three-point arcs, perfect ellipses or rounded rectangles standing in for things.
        """,
        """
        Draw the subject with care, from several overlapping shapes with their own light and shadow: a tree's trunk \
        tapers and its branches fork and thin, a firework is glowing trails with falling sparks rather than spokes with \
        dots, a person has a real silhouette (head, shoulders, coat) or isn't drawn at all.
        """,
        """
        Ground and water are never one flat fill: they take the light (a warm pool under the subject, reflections broken \
        into ripples), fade with distance and carry soft texture.
        """,
        """
        Texture: a fine grain over everything (an feTurbulence filter at 3 to 6% opacity, on a layer that doesn't move), \
        so large gradients don't band and the page doesn't look like vector clip art. Gradients have four or more stops.
        """,
        """
        Detail where the eye goes: dozens of stars or particles of different sizes and brightness, small highlights on \
        the subject. Keep the lower part simpler.
        """,
        """
        Color: the app's palette, lit. The light warms the colors near it and the shadows cool them, instead of big shapes \
        filled with one flat color.
        """,
        """
        Size html and body to the canvas with overflow hidden. Draw with inline SVG and CSS: JavaScript doesn't run, and \
        web fonts and images from the web don't load.
        """,
    ]

    static let pair = """
    The details image is the same world recomposed for the tall frame, not a crop of the card: more sky above, the \
    subject in the upper middle, and the scene going down into the calm lower part.
    """

    /// What each render is checked against before it's sent.
    static let selfCheck = [
        """
        Before sending a concept, render its card and its details image with render_event_artwork (no motion) and look at \
        both images it returns: the art, and the art under the App Store's text. Fix what fails below and render again. \
        Send only what passes.
        """,
        "Does it say this event at a glance, without words?",
        "Is it a finished illustration you'd expect the App Store to feature, not an icon, a diagram or clip art?",
        "Does it have depth, one clear light and texture, with the subject drawn with care and the ground taking the light?",
        "Under the App Store's text, is the subject clear of the words and still readable at card size?",
        "Is the lower part dark and quiet, yet still part of the scene?",
        "Would someone who uses the app recognize its world and colors?",
        "Are the concepts clearly different from each other, and from otherEvents' ideas?",
    ]
}
