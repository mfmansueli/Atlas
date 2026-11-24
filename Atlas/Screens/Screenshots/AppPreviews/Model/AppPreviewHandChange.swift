//
//  AppPreviewHandChange.swift
//  Atlas
//

import Foundation

/// The Review & Push change of one language's App Previews on one device,
/// changed by hand on the Screenshots language page or proposed with
/// `propose_app_preview_file`: one change per language and device, in
/// place of the one queued before. Pushing it uploads, then deletes, then
/// puts the set in order (`AppPreviewSetPush`).
enum AppPreviewHandChange {
    static let idPrefix = "screenshots.appPreviews."

    static func id(appID: StoreApp.ID, locale: String, displayType: ScreenshotDisplayType) -> String {
        "\(idPrefix)\(appID).\(locale).\(displayType.rawValue)"
    }

    static func isChange(_ change: PendingChange) -> Bool {
        change.id.hasPrefix(idPrefix)
    }

    /// What the queued change pushes.
    static func content(of change: PendingChange) -> AppPreviewSetPush.Content? {
        guard isChange(change) else { return nil }
        return change.requests.lazy.compactMap(AppPreviewSetPush.init).first?.content
    }

    /// The set waiting in Review & Push for the language and device.
    @MainActor
    static func queued(in queue: ChangeQueue, appID: StoreApp.ID, locale: String, displayType: ScreenshotDisplayType) -> PendingChange? {
        queue.change(id: id(appID: appID, locale: locale, displayType: displayType))
    }

    /// "German · iPhone App Previews": 1 live → "2 App Previews · 1 new ·
    /// 1 deleted".
    static func change(
        _ content: AppPreviewSetPush.Content, localeName: String, liveCount: Int, source: ChangeSource = .you, reason: String? = nil
    ) -> PendingChange {
        let display = content.displayType.title
        return PendingChange(
            id: id(appID: content.appID, locale: content.locale, displayType: content.displayType),
            appID: content.appID,
            section: .screenshots,
            group: String(localized: "App Previews · \(display)", comment: "kind:label"),
            groupNote: reason.flatMap { $0.isEmpty ? nil : $0 },
            title: String(localized: "\(localeName) · App Previews", comment: "kind:label"),
            oldValue: count(liveCount),
            newValue: summary(content),
            source: source,
            requests: [AppPreviewSetPush(content).request]
        )
    }

    /// "2 App Previews", "No App Previews".
    static func count(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "No App Previews", comment: "kind:label")
        case 1: String(localized: "1 App Preview", comment: "kind:label")
        default: String(localized: "\(count) App Previews", comment: "kind:label")
        }
    }

    /// "2 App Previews · 1 new · 1 deleted · new order".
    static func summary(_ content: AppPreviewSetPush.Content) -> String {
        var parts = [count(content.slots.count)]
        let new = content.slots.count { $0.file != nil }
        if new > 0 { parts.append(String(localized: "\(new) new", comment: "kind:label")) }
        let deleted = content.deletedIDs.count - content.slots.count { $0.replacesID != nil && $0.file != nil }
        if deleted > 0 { parts.append(String(localized: "\(deleted) deleted", comment: "kind:label")) }
        return parts.joined(separator: " · ")
    }
}
