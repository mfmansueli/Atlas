//
//  EventLocalizationPlaceholder.swift
//  Atlas
//

import Foundation

/// A language of an In-App Event that is created by the same push (its
/// texts' `POST`), named in a request before App Store Connect gives it an
/// ID: `{eventLocalization:<eventID>:<locale>}`. The event's card and
/// details page go into every language, new ones too; the push looks the
/// language up (`GET /v1/appEvents/<eventID>/localizations`) once its
/// texts are there, and the uploads go after them (`InAppEventPushOrder`).
struct EventLocalizationPlaceholder: Hashable, Sendable {
    var eventID: String
    var locale: String

    static let prefix = "{eventLocalization:"

    var token: String { "\(Self.prefix)\(eventID):\(locale)}" }

    init(eventID: String, locale: String) {
        self.eventID = eventID
        self.locale = locale
    }

    /// The first placeholder in `request`'s path or body; nil when none.
    init?(in request: PushRequest) {
        let body = request.body.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        self.init(text: request.path + "\n" + body)
    }

    init?(text: String) {
        guard let start = text.range(of: Self.prefix),
              let end = text[start.upperBound...].firstIndex(of: "}")
        else { return nil }
        let inside = text[start.upperBound..<end]
        guard let colon = inside.firstIndex(of: ":") else { return nil }
        let eventID = String(inside[..<colon])
        let locale = String(inside[inside.index(after: colon)...])
        guard !eventID.isEmpty, !locale.isEmpty else { return nil }
        self.init(eventID: eventID, locale: locale)
    }

    static func isPlaceholder(_ localizationID: String) -> Bool {
        localizationID.hasPrefix(prefix)
    }

    /// The event's languages in App Store Connect, by locale.
    @MainActor
    static func localizationIDs(
        eventID: String, via transport: any PushTransport, note: (AppStoreConnectRateLimit?) -> Void
    ) async throws -> [String: String] {
        var next: String? = "/v1/appEvents/\(eventID)/localizations?fields[appEventLocalizations]=locale&limit=50"
        var ids: [String: String] = [:]
        while let page = next {
            let response = try await transport.fetch(page)
            note(response.rateLimit)
            let object = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any]
            for resource in object?["data"] as? [[String: Any]] ?? [] {
                guard let id = resource["id"] as? String,
                      let locale = (resource["attributes"] as? [String: Any])?["locale"] as? String
                else { continue }
                ids[locale] = id
            }
            next = (object?["links"] as? [String: Any])?["next"] as? String
        }
        return ids
    }

    /// The language isn't on the event in App Store Connect: its texts
    /// weren't pushed (left out, refused, or removed from the queue).
    struct Missing: LocalizedError, Equatable {
        var locale: String

        var errorDescription: String? {
            let name = StoreLocaleCatalog.locale(code: locale)?.name ?? locale
            return String(localized: "\(name) isn’t on this event in App Store Connect yet. Push its texts first, then its images.")
        }
    }
}
