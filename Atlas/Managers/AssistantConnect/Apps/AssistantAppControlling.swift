//
//  AssistantAppControlling.swift
//  Atlas
//

import Foundation

/// Opens and restarts the assistants that are Mac apps (Claude for Mac,
/// Cursor): an assistant reads its MCP settings when it starts, so the
/// one already open is restarted after Atlas adds itself. DEBUG scenes and
/// tests use a pretend one that opens nothing.
@MainActor
protocol AssistantAppControlling: AnyObject {
    /// Whether the app is installed on this Mac.
    func isInstalled(_ assistant: ConnectableAssistant) -> Bool

    /// Quits the app when it's open, then opens it (on `folder`, for an
    /// editor). False when it couldn't be opened, or didn't quit.
    func restart(_ assistant: ConnectableAssistant, folder: URL?) async -> Bool

    /// Opens the app, e.g. to sign in.
    func open(_ assistant: ConnectableAssistant)
}
