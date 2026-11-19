//
//  EventArtworkTemplate.swift
//  Atlas
//

import Foundation

/// Atlas's event layouts, for "Start from a template": each a composition
/// Claude fills with the app's colors and motifs, the lower third
/// left calm for the App Store's text.
enum EventArtworkTemplate: String, Codable, CaseIterable, Hashable, Sendable {
    case challenge
    case premiere
    case live
    case newSeason

    var title: String {
        switch self {
        case .challenge: String(localized: "Challenge")
        case .premiere: String(localized: "Premiere")
        case .live: String(localized: "Live")
        case .newSeason: String(localized: "New season")
        }
    }

    /// The layout, as the brief tells Claude: a composition to
    /// start a full scene from, never a picture to copy (the first Alba
    /// run drew "a row of steps" as six rounded bars).
    var layout: String {
        switch self {
        case .challenge:
            """
            A journey toward a goal: a path, trail, river or rising ground leads the eye from the lower left into a deep, \
            layered scene, toward a lit goal in the upper right (a summit, a dawn, a light). Progress you can feel, not a \
            row of steps or a chart. In a loop, light travels along the way.
            """
        case .premiere:
            """
            One hero subject, large, just above the middle, lit like a stage: a strong light behind or above it, rim light \
            on its edges, and the world around it falling into rich shadow. Nothing competes with it. In a loop, its glow \
            breathes.
            """
        case .live:
            """
            A scene happening now: many small lights, figures or things gathered around a lit center (a fire, a window, a \
            tree, a stage), warm and close, the edges falling into darkness. In a loop, the lights flicker and drift.
            """
        case .newSeason:
            """
            The season filling the frame (leaves, light, water, blossoms, a night sky) in its own colors and textures, with \
            one symbol of what's new in the upper half, caught in that season's light. In a loop, a soft drift.
            """
        }
    }

    /// The template that suits the event's badge first, then the rest.
    static func ordered(for badge: InAppEventBadge?) -> [Self] {
        let first: Self = switch badge {
        case .challenge, .competition: .challenge
        case .premiere, .majorUpdate: .premiere
        case .liveEvent, .specialEvent: .live
        case .newSeason: .newSeason
        case nil: .challenge
        }
        return [first] + allCases.filter { $0 != first }
    }

    var json: JSONValue {
        ["id": .string(rawValue), "title": .string(title), "layout": .string(layout)]
    }
}
