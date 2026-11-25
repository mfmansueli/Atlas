//
//  DesignSceneAliases.swift
//  Atlas
//

#if DEBUG
import Foundation

/// Scene names the canvas uses for states Atlas already draws under
/// another DEBUG id, so `-AtlasDebugScene` takes the canvas's name too.
enum DesignSceneAliases {
    static let aliases = [
        // Settings: Connect goes through the sheet, whose step 2 lists the
        // same three steps the canvas draws under the row.
        "set-assistants-busy": "set-wiz-busy",
        // Help.
        "help-search-none": "help-none",
        // Welcome & menu bar.
        "checking": "connect-checking",
        "checking-done": "sync-done",
        "addkey-filled": "addkey",
        "addkey-err": "addkey-403",
        "mb-closed": "mb-note",
        "mb-working-closed": "mb-running",
        "mb-settings": "set-general",
        // Board 74's empty states, drawn under their sections' ids.
        "es-ev": "ev-empty",
        "es-rv": "rv-empty",
        "es-an": "an-waiting",
        "es-rp": "review-empty",
        "es-pr": "pricing-nosubs",
        "es-find": "pr-prod-find-none",
        "es-pr-results": "pr-prod-results-none",
    ]

    /// The id Atlas knows the scene by.
    static func resolve(_ id: String) -> String {
        aliases[id] ?? id
    }
}
#endif
