//
//  AssistantConfigWriting.swift
//  Atlas
//

import Foundation

/// Puts Atlas's entry in an assistant's MCP settings file, or takes it
/// out: the real files for real launches (`AssistantConfigAccess`), a
/// pretend one in DEBUG scenes and tests, which never touch the person's
/// Claude for Mac or Cursor.
@MainActor
protocol AssistantConfigWriting: AnyObject {
    /// Adds (or replaces) Atlas's entry, asking for the settings folder the
    /// first time. Throws what went wrong, in words for the person.
    func addAtlas(to assistant: ConnectableAssistant, token: String, bridgePath: String) throws

    /// Takes Atlas's entry out, when Atlas may still write there. Never
    /// asks.
    func removeAtlas(from assistant: ConnectableAssistant)
}
