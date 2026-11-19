//
//  EventArtworkRenderedPages.swift
//  Atlas
//

import Foundation

/// The HTML page behind each file render_event_artwork made from one, so a
/// concept sent with that file's id instead of the page still keeps its
/// page: for Ask for Changes, the name in each language and the moving
/// version. The first Alba run with the render check (2026-11-18) sent
/// every concept by file id. Kept for this launch only; the newest few
/// hundred are enough for the renders of a run.
@MainActor
final class EventArtworkRenderedPages {
    static let shared = EventArtworkRenderedPages()

    /// How many pages are kept, oldest dropped first.
    let limit: Int
    private var pages: [String: String] = [:]
    private var order: [String] = []

    init(limit: Int = 300) {
        self.limit = limit
    }

    /// Remembers `html` as the page `fileID` was rendered from.
    func remember(_ html: String, for fileID: String) {
        if pages.updateValue(html, forKey: fileID) == nil { order.append(fileID) }
        while order.count > limit {
            pages[order.removeFirst()] = nil
        }
    }

    /// The page `fileID` was rendered from, if render_event_artwork made it
    /// in this launch.
    func page(for fileID: String) -> String? {
        pages[fileID]
    }
}
