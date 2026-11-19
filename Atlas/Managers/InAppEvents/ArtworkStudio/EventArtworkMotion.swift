//
//  EventArtworkMotion.swift
//  Atlas
//

import Foundation

/// How an In-App Event's moving version is made, as the brief tells Claude
/// Design when the person asked for one. Apple's part comes from the
/// In-App Events page on developer.apple.com and App Store Connect's
/// creative asset specifications (read 2026-11-18): videos play by
/// themselves and repeat, so aim for a seamless loop; 5 to 30 seconds at 30
/// or 60 fps; the card 16:9 from 1920 × 1080, the details page 9:16; tracks
/// without audio are supported; no words, logos, borders or gradients; the
/// card and the details page alike. The rest is Atlas's direction for a
/// loop that tells the event and is calm to watch.
enum EventArtworkMotion {
    /// The brief's `motionDirection`.
    static var json: JSONValue {
        [
            "apple": .array(apple.map(JSONValue.string)),
            "idea": .string(idea),
            "craft": .array(craft.map(JSONValue.string)),
            "selfCheck": .array(selfCheck.map(JSONValue.string)),
        ]
    }

    static let apple = [
        """
        The App Store plays event videos by themselves, muted, over and over, so the loop has to be seamless: no visible \
        restart.
        """,
        """
        Atlas makes a \(AutopilotArtworkMotion.loopSeconds)-second loop at \(AutopilotArtworkMotion.loopFramesPerSecond) fps \
        without sound, 1920 × 1080 for the card and 1080 × 1920 for the details page. Apple takes 5 to 30 seconds at 30 or \
        60 fps.
        """,
        """
        The still's rules hold: no words or logos, no borders or gradient overlays (Apple adds its own fade and crop), and \
        the card and the details page alike, moving the same way.
        """,
        "The still stays: Atlas keeps the page's first frame as the image, for where video doesn't play.",
    ]

    static let idea = """
    Let one thing move that tells the event, and keep the rest of the picture still or nearly still: lanterns rising one by \
    one for gratitude, light travelling from window to window for Christmas kindness, the sun climbing a little higher each \
    morning for a January streak. Around it, a little life: stars twinkling, snow or sparks drifting, mist, a gentle sway. \
    Motion that only decorates, with nothing of the event in it, isn't worth a video.
    """

    static let craft = [
        """
        Slow and calm: things take seconds to move, ease in and out and travel a short way. No flashing, strobing or \
        flickering (never more than three flashes a second), no shaking, no cuts.
        """,
        """
        The camera stays put: no zoom or pan of the whole scene, since Apple crops the card differently in each place. A \
        slight parallax between layers, a few percent of the width at most, is fine.
        """,
        """
        The first frame is the still and has to work alone: everything already in place at 0 seconds, nothing fading in from \
        an empty scene or entering from outside the frame at the start.
        """,
        """
        Seamless: every animation repeats a whole number of times in \(AutopilotArtworkMotion.loopSeconds) seconds \
        (durations of 1, 2, 2.5, 4, 5, 10 or 20 s, animation-iteration-count: infinite), with its 0% and 100% keyframes the \
        same. Stagger with a negative animation-delay, never a positive one. Something that travels comes back to where it \
        started by the end, or fades out and in again at the same spot.
        """,
        """
        The lower part stays calm under Apple's text: at most a slow shimmer on water or drifting haze, never a moving \
        subject behind the words.
        """,
        """
        Animate transform and opacity of whole layers or SVG groups, and colors or filter values sparingly. Atlas pauses \
        the page at each frame, so CSS animations and SVG <animate> work and JavaScript doesn't. Keep the grain layer \
        still, or the texture swims.
        """,
        """
        The details image moves the same elements at the same rhythm as the card, so opening the card into the event's \
        page feels like one piece.
        """,
    ]

    static let selfCheck = [
        """
        Before sending a concept, render its card and its details image with render_event_artwork and motionFrames: true, \
        and look at the frames it returns and at its loop check. It's quick: the video itself is made when you send the \
        concept.
        """,
        "Does what moves tell the event, with the rest calm?",
        "Is the first frame a finished image on its own?",
        "Does the loop check say every animation repeats evenly and the end meets the start?",
        "Is the lower part calm in every frame, and the subject clear of the text?",
    ]
}
