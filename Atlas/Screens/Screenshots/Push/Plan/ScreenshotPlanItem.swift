//
//  ScreenshotPlanItem.swift
//  Atlas
//

import Foundation

/// One image a screenshot push would send: what goes into a locale ×
/// display type × slot, and the live screenshot it replaces there, if any.
/// The plan is derived, so an item exists only while its render differs
/// from what's live (or a restore is queued for its slot).
struct ScreenshotPlanItem: Identifiable, Hashable, Sendable {
    var appID: StoreApp.ID
    var cell: ScreenshotCellKey
    /// "Today", from the capture files.
    var slotName: String
    var content: ScreenshotPlanContent
    /// What's live in this position now; nil adds a screenshot.
    var old: LiveScreenshot?
    /// How the live one was made, for its backup.
    var oldOrigin: ScreenshotBackupOrigin = .uploadedByHand
    /// Who made the change: an assistant whose caption proposal was
    /// accepted (the CC tag), machine translation, a restore, or you.
    var source: ChangeSource
    /// The place in a set changed by hand this change comes from; nil
    /// outside those sets (and for the set's new order).
    var handSlotID: String?
    /// For the new order: the live screenshots' IDs in the order they end
    /// in.
    var handOrder: [String] = []

    var id: String { "\(appID)|\(cell)\(content.idSuffix)" }

    var renderKey: RenderKey? { content.renderJob?.key }

    /// What a file, a delete or the new order is, so a discard holds only
    /// until it changes: the file's checksum, the screenshot deleted, the
    /// order. Nil for renders and restores, which are discarded by render
    /// key and backup.
    var handFingerprint: String? {
        switch content {
        case let .file(file): file.checksum
        case .delete: old?.id
        case .reorder: handOrder.joined(separator: ",")
        case .render, .restore: nil
        }
    }

    var isRestore: Bool { content.backupImage != nil }

    /// "1 Today", "Delete 3", "New order".
    var slotTitle: String {
        switch content {
        case .delete: String(localized: "Delete \(cell.slot + 1)")
        case .reorder: String(localized: "New order")
        case .file: String(localized: "\(cell.slot + 1) · your file")
        case .render, .restore: "\(cell.slot + 1) \(slotName)"
        }
    }

    /// "German · iPhone · 1 Today", for progress rows and Activity.
    func title(localeName: String) -> String {
        "\(localeName) · \(cell.displayType.shortTitle) · \(slotTitle)"
    }

    /// The name the uploaded file gets in App Store Connect, e.g.
    /// `de-DE_iPhone_1_Today.png`; a restore keeps its original name.
    var fileName: String {
        if let image = content.backupImage, !image.fileName.isEmpty { return image.fileName }
        if let file = content.handFile, !file.fileName.isEmpty { return file.fileName }
        let slug = slotName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        return "\(cell.locale)_\(cell.displayType.shortTitle)_\(cell.slot + 1)_\(slug).png"
    }
}
