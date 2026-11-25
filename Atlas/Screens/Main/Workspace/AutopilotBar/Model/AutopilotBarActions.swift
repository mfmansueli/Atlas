//
//  AutopilotBarActions.swift
//  Atlas
//

import Foundation

/// The section's actions as the Autopilot bar shows them (board 80): the
/// first two as buttons beside the closed field (a click sends the request
/// like a message), the rest under More with Everything for the app last;
/// open, every one of them in a list over the conversation. Where the
/// field is narrow the second button folds into More, then the first.
struct AutopilotBarActions: Equatable {
    /// The buttons beside the field, at most.
    static let buttonLimit = 2

    let items: [WorkspaceAutopilotItem]
    /// “Everything for Lumen…”; nil on Overview, whose first action is
    /// Suggest Everything… already.
    var everythingTitle: String?

    /// The bar's own action, ⌥⌘A.
    var primary: WorkspaceAutopilotItem? { items.first }

    /// The buttons beside the field when `room` of them fit (2, 1 or 0).
    func buttons(fitting room: Int = buttonLimit) -> [WorkspaceAutopilotItem] {
        Array(items.prefix(Self.clamped(room)))
    }

    /// What More lists: the actions that have no button.
    func more(fitting room: Int = buttonLimit) -> [WorkspaceAutopilotItem] {
        Array(items.dropFirst(Self.clamped(room)))
    }

    /// How many buttons to try, widest first: two, then one, then none.
    static var fittingOrder: [Int] { Array((0...buttonLimit).reversed()) }

    private static func clamped(_ room: Int) -> Int {
        min(max(room, 0), buttonLimit)
    }

    /// “Everything for Lumen…” for every section but Overview.
    static func everythingTitle(section: AppWorkspaceSection, appName: String) -> String? {
        section == .overview ? nil : String(localized: "Everything for \(appName)…", comment: "kind:menu-item · Suggest Everything, from the Autopilot bar")
    }
}
