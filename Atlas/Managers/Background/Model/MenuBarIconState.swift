//
//  MenuBarIconState.swift
//  Atlas
//

import Foundation

/// What the menu bar icon says, from the design's board 46: still when
/// nothing runs or waits, a bright stretch sweeping round the globe while
/// something works, a dot when something needs the person, dimmed with a
/// pause mark when background work is paused, and a stroke across it when
/// the key was refused or Apple can't be reached.
enum MenuBarIconState: Hashable, Sendable {
    case idle
    case working
    case needsYou
    case paused
    case cantConnect

    /// Working wins over everything while something runs: the dot comes
    /// back when it stops. Paused comes next, since a paused Atlas isn't
    /// checking, so what it last heard from Apple is old news.
    static func resolve(isWorking: Bool, isPaused: Bool, hasConnectionProblem: Bool, needsCount: Int) -> MenuBarIconState {
        if isWorking { return .working }
        if isPaused { return .paused }
        if hasConnectionProblem { return .cantConnect }
        return needsCount > 0 ? .needsYou : .idle
    }

    /// The status item's VoiceOver label.
    var accessibilityLabel: String {
        switch self {
        case .idle: String(localized: "Atlas")
        case .working: String(localized: "Atlas, running")
        case .needsYou: String(localized: "Atlas, needs you")
        case .paused: String(localized: "Atlas, paused")
        case .cantConnect: String(localized: "Atlas, can’t connect")
        }
    }
}
