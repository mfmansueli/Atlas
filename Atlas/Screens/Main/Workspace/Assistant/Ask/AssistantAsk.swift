//
//  AssistantAsk.swift
//  Atlas
//

import Foundation

/// One request sent to the person's assistant from an asking button
/// ("Ask Claude Code…", Suggest Pages…): what it's about, and whether it's
/// still on its way to the toolbar or being worked on. One at a time for
/// each app (`AssistantAskCenter`).
struct AssistantAsk: Identifiable, Hashable, Sendable {
    enum Phase: Hashable, Sendable {
        /// The token is flying to the toolbar's Assistant button.
        case sending
        /// The assistant works on it: the toolbar says Working….
        case working
    }

    var id = UUID()
    let appID: StoreApp.ID
    /// "Claude Code".
    let client: String
    /// What it's about, shown and said: "Store Page", "In-App Events ·
    /// Winter Reflection 2026".
    let subject: String
    var phase: Phase = .sending
    /// The Claude Code run Atlas started for it, once it did.
    var runID: ClaudeCodeRun.ID?

    /// The subject as VoiceOver says it: commas, not dots.
    var spokenSubject: String { subject.replacingOccurrences(of: " · ", with: ", ") }

    /// "Sent to Claude Code: Store Page. The Assistant button in the
    /// toolbar shows it’s working."
    var announcement: String {
        String(localized: "Sent to \(client): \(spokenSubject). The Assistant button in the toolbar shows it’s working.")
    }

    /// The asking buttons' title meanwhile: "Claude Code Is Working…".
    var busyTitle: String { Self.busyTitle(client: client) }

    static func busyTitle(client: String) -> String {
        String(localized: "\(client) Is Working…")
    }

    /// The toolbar button's label: "Assistant, Claude Code is working on
    /// Store Page".
    var toolbarLabel: String {
        String(localized: "Assistant, \(client) is working on \(spokenSubject)")
    }

    /// What the toolbar's popover says about it.
    var popoverText: String {
        String(localized: "\(client) is working on \(subject). What it suggests will show up in purple.")
    }
}
