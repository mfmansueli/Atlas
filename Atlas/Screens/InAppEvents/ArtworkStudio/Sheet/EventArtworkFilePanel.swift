//
//  EventArtworkFilePanel.swift
//  Atlas
//

import AppKit
import UniformTypeIdentifiers

/// Choose Files…: the open panel for an event's card and details image
/// (images or videos), and the pasteboard for a prompt Atlas couldn't
/// start Claude Code with.
@MainActor
enum EventArtworkFilePanel {
    static func choose(eventName: String) -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = String(localized: "Choose the artwork for \(eventName)")
        panel.message = String(localized: "Choose the event card (16:9), the event details image (9:16), or both. Images or videos.")
        panel.prompt = String(localized: "Choose")
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .mpeg4Movie, .quickTimeMovie]
        guard panel.runModal() == .OK else { return nil }
        return panel.urls
    }

    static func copy(_ text: String) {
        #if DEBUG
        // DEBUG scenes and UI tests leave the person's pasteboard alone.
        if DebugScene.requestedID != nil { return }
        #endif
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
