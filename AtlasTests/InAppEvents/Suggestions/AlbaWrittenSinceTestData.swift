//
//  AlbaWrittenSinceTestData.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Alba, Nov 19: Claude Code suggested 13 new languages of "New Year, New
/// Mindset" at 10:37 GMT; since, all 14 were written in App Store Connect.
/// Nine read as suggested (Korean only with a trailing space), four don't:
/// Portuguese (Brazil) another name, Portuguese (Portugal) another long
/// description, Spanish (Mexico) both descriptions, French (Canada) all
/// three.
enum AlbaWrittenSinceTestData {
    static let app = StoreApp(id: "6825428345", name: "Alba", bundleID: "com.lima.alba", sku: "ALBA", primaryLocale: "en-US")
    static let eventID = "6835869914"
    /// Nov 19, 2026, 10:37 GMT.
    static let suggestedAt = Date(timeIntervalSince1970: 1_795_084_620)
    /// The clock: Nov 19, 19:40 GMT.
    static let now = Date(timeIntervalSince1970: 1_795_117_200)

    static let suggestedLocales = ["en-GB", "en-AU", "en-CA", "pt-BR", "pt-PT", "es-ES", "es-MX", "fr-FR", "fr-CA", "de-DE", "it", "ja", "ko"]
    static let why = "Matches the voice of your store page."

    /// The languages written as suggested.
    static var sameLocales: [String] { suggestedLocales.filter { differing[$0] == nil } }
    /// The fields written otherwise, by language.
    static let differing: [String: [InAppEventField]] = [
        "pt-BR": [.name],
        "pt-PT": [.longDescription],
        "es-MX": [.shortDescription, .longDescription],
        "fr-CA": [.name, .shortDescription, .longDescription],
    ]

    static func suggested(_ field: InAppEventField, _ locale: String) -> String {
        switch field {
        case .name: "New Year \(locale)"
        case .shortDescription: "A fresh start \(locale)"
        case .longDescription: "Seven days of small habits for the new year, \(locale)."
        }
    }

    static func written(_ field: InAppEventField, _ locale: String) -> String {
        if differing[locale]?.contains(field) == true { return "Written in App Store Connect: \(field.rawValue) \(locale)" }
        // Korean was written with a trailing space: the same text.
        return locale == "ko" ? suggested(field, locale) + " " : suggested(field, locale)
    }

    static var event: InAppEvent {
        let publish = now.addingTimeInterval(3 * 86400)
        return InAppEvent(
            id: eventID, referenceName: "New Year, New Mindset", badge: .challenge, state: .draft, deepLink: "alba://new-year",
            primaryLocale: "en-US", purpose: .appropriateForAllUsers,
            schedules: [InAppEventSchedule(
                territories: ["USA"], publishStart: publish, eventStart: publish.addingTimeInterval(4 * 86400),
                eventEnd: publish.addingTimeInterval(10 * 86400)
            )],
            localizations: (["en-US"] + suggestedLocales).map { locale in
                InAppEventLocalization(
                    id: "loc-\(locale)", locale: locale, name: written(.name, locale), shortDescription: written(.shortDescription, locale),
                    longDescription: written(.longDescription, locale), media: InAppEventsTestData.media
                )
            }
        )
    }

    /// Claude Code's 13 new languages, all three texts each.
    static var suggestions: [InAppEventTextSuggestion] {
        suggestedLocales.map { locale in
            InAppEventTextSuggestion(
                eventID: eventID, locale: locale, name: suggested(.name, locale), shortDescription: suggested(.shortDescription, locale),
                longDescription: suggested(.longDescription, locale), why: why, source: "Claude Code", date: suggestedAt
            )
        }
    }
}
