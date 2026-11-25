//
//  StoreArtworkMenuItem.swift
//  Atlas
//

import Foundation

/// One row of a header or search tile's menu, with what it does under it:
/// Add ▾ (Add Header…, Make with Autopilot…) when there's none, Edit ▾
/// (Replace…, Make a New One…, Delete…) when there is, Undo Change while
/// a change waits.
struct StoreArtworkMenuItem: Hashable, Identifiable {
    let action: StoreArtworkAction
    let title: String
    let detail: String
    /// Autopilot needs Pro: the row carries PRO on the Free plan.
    var isPro = false
    var isDestructive = false
    /// A divider goes above it.
    var startsGroup = false

    var id: StoreArtworkAction { action }

    static func items(for slot: StoreArtworkSlot) -> [StoreArtworkMenuItem] {
        let place = slot.place
        let undo = StoreArtworkMenuItem(
            action: .undo, title: String(localized: "Undo Change", comment: "kind:menu"),
            detail: String(localized: "Back to what’s on the App Store", comment: "kind:label"), startsGroup: true
        )
        switch slot.state {
        case .willBeDeleted:
            return [StoreArtworkMenuItem(action: undo.action, title: undo.title, detail: undo.detail)]
        case .none:
            return [
                StoreArtworkMenuItem(action: .add, title: place.addTitle, detail: place.fileRule),
                StoreArtworkMenuItem(
                    action: .makeWithAutopilot, title: String(localized: "Make with Autopilot…", comment: "kind:menu"),
                    detail: String(localized: "Claude Design, in this app’s look", comment: "kind:label"), isPro: true
                ),
            ]
        case .live, .new, .replaced:
            var items = [
                StoreArtworkMenuItem(action: .replace, title: String(localized: "Replace…", comment: "kind:menu"), detail: place.fileRule),
                StoreArtworkMenuItem(
                    action: .makeNew, title: String(localized: "Make a New One…", comment: "kind:menu"),
                    detail: String(localized: "Autopilot, with Claude Design", comment: "kind:label"), isPro: true
                ),
                StoreArtworkMenuItem(
                    action: .delete, title: String(localized: "Delete…", comment: "kind:menu"), detail: place.deleteNote,
                    isDestructive: true, startsGroup: true
                ),
            ]
            if slot.state.isNotPushed { items.append(undo) }
            return items
        }
    }
}
