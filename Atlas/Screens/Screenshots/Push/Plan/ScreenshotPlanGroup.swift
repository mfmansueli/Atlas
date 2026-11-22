//
//  ScreenshotPlanGroup.swift
//  Atlas
//

import Foundation

/// One screenshot set a push changes: a locale × display type, with the
/// images that go into it in slot order. Review & Push shows one group
/// per set; the uploader works set by set.
struct ScreenshotPlanGroup: Identifiable, Hashable, Sendable {
    var appID: StoreApp.ID
    var locale: StoreLocale
    var displayType: ScreenshotDisplayType
    /// The version localization the set belongs to.
    var localizationID: String?
    /// The set live now, with its order; nil when the push creates it.
    var liveSet: LiveScreenshotSet?
    /// An empty set App Store Connect already has here: the push fills it
    /// instead of creating one, which would be refused.
    var emptySetID: String?
    var items: [ScreenshotPlanItem]
    /// Live screenshots past the end of a restored set: the push deletes
    /// them so the set matches what was kept.
    var extraLive: [LiveScreenshot] = []
    /// When the group puts kept screenshots back: when they were kept,
    /// for "Restore from Oct 12".
    var restoredFrom: Date?
    /// The App Previews in this locale and display type. They're listed
    /// read-only; nothing here uploads or deletes them.
    var previews: LiveAppPreviewSet?
    /// A set changed by hand: what goes in each place, in order. The push
    /// leaves the set in this order; nil for the template's sets.
    var arrangement: [ScreenshotHandTarget]?

    var id: String { "\(appID)|\(locale.code)|\(displayType.rawValue)" }

    var isRestore: Bool { restoredFrom != nil }

    /// Live screenshots the push replaces or removes.
    var deleteCount: Int { items.count { $0.old != nil && $0.content != .reorder } + extraLive.count }

    var isHand: Bool { arrangement != nil }

    /// The assistant whose accepted proposals some of the images carry.
    var assistant: ChangeSource? {
        items.first { $0.source.isAssistant }?.source
    }

    /// "5 images", or for a set changed by hand "2 images, 1 delete".
    var countTitle: String {
        let uploads = items.count { !$0.content.isSetChange }
        let deletes = items.count { $0.content == .delete }
        var parts: [String] = []
        if uploads > 0 || deletes == 0 { parts.append(uploads == 1 ? String(localized: "1 image") : String(localized: "\(uploads) images")) }
        if deletes > 0 { parts.append(deletes == 1 ? String(localized: "1 delete") : String(localized: "\(deletes) deletes")) }
        if items.contains(where: { $0.content == .reorder }) { parts.append(String(localized: "new order")) }
        return parts.joined(separator: ", ")
    }
}
