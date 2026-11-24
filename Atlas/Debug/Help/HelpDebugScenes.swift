//
//  HelpDebugScenes.swift
//  Atlas
//

#if DEBUG
import SwiftUI

/// Atlas Help DEBUG scenes (board 49), the Help window's content in the
/// main window: `help-home`, `help-search` ("vendor number"), `help-none`
/// (nothing matches), `help-connect` (steps and Show Me), `help-assistant`
/// (a table), `help-keys` (Keyboard Shortcuts), `help-shown` (after Show
/// Me), `help-fix-heading` (Fix a problem at “The key can’t do that”, as
/// Fix a Problem after a 403 opens it). `help-fix-links` is apart: an
/// error message and banners with their Fix a Problem links, which open
/// the real Help window.
enum HelpDebugScenes {
    static let ids = [
        "help-home", "help-search", "help-none", "help-connect", "help-assistant", "help-keys", "help-shown", "help-fix-heading",
        "help-fix-links",
    ]

    /// One navigation per scene, made once. Setting it up reads `place`
    /// inside the scene's body, so every click would rebuild the body; a
    /// new navigation each time would send it back to the first article.
    @MainActor private static var made: [String: HelpNavigation] = [:]

    @MainActor
    static func view(for id: String) -> AnyView? {
        guard ids.contains(id) else { return nil }
        if id == "help-fix-links" { return AnyView(HelpFixLinksDebugView()) }
        let navigation = made[id] ?? navigation(for: id)
        made[id] = navigation
        return AnyView(HelpWindow().environment(navigation))
    }

    @MainActor
    private static func navigation(for id: String) -> HelpNavigation {
        let navigation = HelpNavigation()
        switch id {
        case "help-search": navigation.query = "vendor number"
        case "help-none": navigation.query = "spaceship"
        case "help-connect": navigation.open("connect")
        case "help-assistant": navigation.open("assistant")
        case "help-keys": navigation.open("keys")
        case "help-fix-heading": navigation.open(.notAllowed)
        case "help-shown":
            navigation.open("connect")
            navigation.shown = String(localized: "Opened \(HelpShowMe.settings(.accounts).title) in Atlas.")
        default: break
        }
        return navigation
    }
}
#endif
