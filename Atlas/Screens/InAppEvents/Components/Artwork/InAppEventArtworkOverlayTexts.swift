//
//  InAppEventArtworkOverlayTexts.swift
//  Atlas
//

import Foundation

/// What the App Store lays over an event's art in one language: the
/// badge, the event's name, and its short description (card) or long one
/// (details page), falling back to the primary language's text where the
/// language has none, as Apple does.
struct InAppEventArtworkOverlayTexts: Hashable, Sendable {
    var locale: String
    var isRightToLeft: Bool
    var badge: String
    var name: String
    var description: String
    var appName: String
    /// The texts came from the primary language: this one has none yet.
    var isFallback = false

    init(locale: String, isRightToLeft: Bool, badge: String, name: String, description: String, appName: String, isFallback: Bool = false) {
        self.locale = locale
        self.isRightToLeft = isRightToLeft
        self.badge = badge
        self.name = name
        self.description = description
        self.appName = appName
        self.isFallback = isFallback
    }

    init(event: InAppEvent, kind: InAppEventMedia.Kind, locale: String, appName: String) {
        let own = event.localizations.first { $0.locale == locale }
        let primary = event.primaryLocalization
        let shown = own?.isComplete == true ? own : (primary ?? own)
        let description = kind == .card ? shown?.shortDescription : shown?.longDescription
        self.init(
            locale: locale, isRightToLeft: StoreLocaleCatalog.locale(code: locale)?.isRTL ?? false,
            badge: event.badge?.title ?? "", name: shown?.name ?? event.referenceName, description: description ?? "",
            appName: appName, isFallback: own?.isComplete != true
        )
    }

    var json: [String: JSONValue] {
        var object: [String: JSONValue] = [
            "badge": .string(badge), "name": .string(name), "description": .string(description),
        ]
        if isFallback { object["note"] = "This language has no texts yet: the primary language's show, as on the App Store." }
        return object
    }
}
