//
//  ScreenshotPushState.swift
//  Atlas
//

import Foundation

/// What Review & Push remembers about one app's screenshots between
/// launches, besides the document: renders discarded to keep what's live,
/// and restores waiting to be pushed.
struct ScreenshotPushState: Codable, Hashable, Sendable {
    /// Discarded renders by cell: the render key that was discarded. A
    /// cell comes back to review as soon as its render key changes.
    var kept: [ScreenshotCellKey: RenderKey] = [:]
    var restores: [ScreenshotRestoreRequest] = []
    /// Kept screenshots discarded from a queued restore, by backup image
    /// ID: they stay out of the push until Undo.
    var keptRestores: Set<String> = []
    /// Changes made by hand discarded in review, by plan item ID: what
    /// each was (its file's checksum, the screenshot it deletes, the
    /// order). They stay out of the push until they change or Undo. Nil in
    /// states from before them.
    var keptHand: [String: String]?

    var isEmpty: Bool { kept.isEmpty && restores.isEmpty && keptRestores.isEmpty && (keptHand ?? [:]).isEmpty }

    /// Whether a change made by hand was discarded as it is now.
    func isKept(_ item: ScreenshotPlanItem) -> Bool {
        guard let fingerprint = item.handFingerprint else { return false }
        return keptHand?[item.id] == fingerprint
    }

    func restore(for locale: String) -> ScreenshotRestoreRequest? {
        restores.first { $0.locale == locale }
    }

    /// Queues `request`, replacing an earlier one for the same locale.
    mutating func queue(_ request: ScreenshotRestoreRequest) {
        removeRestore(for: request.locale)
        restores.append(request)
    }

    /// Drops a locale's restore and its discards.
    mutating func removeRestore(for locale: String) {
        let images = Set(restores.filter { $0.locale == locale }.flatMap(\.images).map(\.id))
        keptRestores.subtract(images)
        restores.removeAll { $0.locale == locale }
    }

    /// Drops restores for locales that went back to the template (Use
    /// Template Again unpinned them). Returns whether anything changed.
    mutating func pruneRestores(keeping isPinned: (String) -> Bool) -> Bool {
        let unpinned = restores.map(\.locale).filter { !isPinned($0) }
        for locale in unpinned { removeRestore(for: locale) }
        return !unpinned.isEmpty
    }
}
