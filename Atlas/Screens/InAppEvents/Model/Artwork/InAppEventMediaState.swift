//
//  InAppEventMediaState.swift
//  Atlas
//

import Foundation

/// What each language of an event shows as its card and details page: its
/// own image or video, or the primary language's (Apple's fallback), and
/// what's still missing: the kinds no language has (needed to submit) and
/// the languages without their own.
struct InAppEventMediaState: Hashable, Sendable {
    /// One language's card and details page.
    struct Language: Hashable, Sendable {
        var locale: String
        var own: [InAppEventMedia.Kind: InAppEventMedia] = [:]
        /// The primary language's, shown where there's no own one.
        var fallback: [InAppEventMedia.Kind: InAppEventMedia] = [:]
        var primaryLocale: String?

        /// "image 1920 × 1080", "video", "none · shows en-US's image" or
        /// "none".
        func text(_ kind: InAppEventMedia.Kind) -> String {
            if let media = own[kind] { return Self.describe(media) }
            if let media = fallback[kind], let primaryLocale {
                return String(localized: "none · shows \(primaryLocale)’s \(Self.describe(media))", comment: "kind:other")
            }
            return String(localized: "none", comment: "kind:other")
        }

        private static func describe(_ media: InAppEventMedia) -> String {
            media.isVideo ? "video" : media.sizeText.map { "image \($0)" } ?? "image"
        }
    }

    var languages: [Language]
    /// Kinds no language has: the event can't be submitted without them.
    var neededToSubmit: [InAppEventMedia.Kind]
    /// Per kind, the languages without their own.
    var withoutOwn: [InAppEventMedia.Kind: [String]]

    init(event: InAppEvent) {
        let primary = event.primaryLocalization
        let languages = event.localizations.map { localization in
            var language = Language(locale: localization.locale, primaryLocale: primary?.locale)
            for kind in InAppEventMedia.Kind.allCases {
                language.own[kind] = localization.media.first { $0.kind == kind }
                if localization.locale != primary?.locale { language.fallback[kind] = primary?.media.first { $0.kind == kind } }
            }
            return language
        }
        self.languages = languages
        neededToSubmit = InAppEventMedia.Kind.allCases.filter { event.media($0) == nil }
        withoutOwn = Dictionary(uniqueKeysWithValues: InAppEventMedia.Kind.allCases.map { kind in
            (kind, languages.filter { $0.own[kind] == nil }.map(\.locale))
        })
    }

    /// `get_in_app_events`' `stillMissing`.
    var missingJSON: [String: JSONValue] {
        var object: [String: JSONValue] = ["neededToSubmit": .array(neededToSubmit.map { .string($0.mcpValue) })]
        for kind in InAppEventMedia.Kind.allCases {
            object["\(kind.mcpValue)WithoutOwn"] = .array((withoutOwn[kind] ?? []).map(JSONValue.string))
        }
        return object
    }
}
