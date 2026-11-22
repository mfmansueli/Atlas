//
//  ScreenshotPlanContent.swift
//  Atlas
//

import Foundation

/// What one planned change does: upload a render made from the template, a
/// screenshot kept on this Mac by an earlier push, or a file given by hand;
/// or, in a set changed by hand, delete a live screenshot or put the set in
/// its new order. Deletes and the order wait until the set's uploads are
/// done, so a failed upload never leaves fewer screenshots than before.
enum ScreenshotPlanContent: Hashable, Sendable {
    case render(RenderJob)
    case restore(ScreenshotBackupImage)
    case file(ScreenshotHandFile)
    /// Deletes the item's `old` screenshot.
    case delete
    /// Puts the set in the order the person left it.
    case reorder

    var renderJob: RenderJob? {
        if case let .render(job) = self { return job }
        return nil
    }

    var backupImage: ScreenshotBackupImage? {
        if case let .restore(image) = self { return image }
        return nil
    }

    var handFile: ScreenshotHandFile? {
        if case let .file(file) = self { return file }
        return nil
    }

    /// Nothing to upload: a delete or the new order.
    var isSetChange: Bool {
        switch self {
        case .delete, .reorder: true
        case .render, .restore, .file: false
        }
    }

    /// Told apart from an upload in the same place.
    var idSuffix: String {
        switch self {
        case .render, .restore: ""
        case .file: "|file"
        case .delete: "|delete"
        case .reorder: "|order"
        }
    }
}
