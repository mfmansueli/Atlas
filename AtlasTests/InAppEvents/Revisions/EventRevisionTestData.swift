//
//  EventRevisionTestData.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Alba's streak, Nov 19: written in English, Portuguese and German, each
/// long description ending "by Sunday", and the event now ends on
/// Wednesday, December 2. A draft, so its texts can still change.
enum EventRevisionTestData {
    typealias Data = InAppEventsTestData

    static let eventID = "streak"

    static let sunday: [String: String] = [
        "en-US": "Write one thank-you each evening and reach the 7-day streak milestone by Sunday.",
        "pt-BR": "Escreva um agradecimento por noite e alcance a marca de 7 dias de sequência até domingo.",
        "de-DE": "Schreibe jeden Abend ein Dankeschön und erreiche die 7-Tage-Serie bis Sonntag.",
    ]

    static let december: [String: String] = [
        "en-US": "Write one thank-you each evening and reach the 7-day streak milestone by December 2.",
        "pt-BR": "Escreva um agradecimento por noite e alcance a marca de 7 dias de sequência até 2 de dezembro.",
        "de-DE": "Schreibe jeden Abend ein Dankeschön und erreiche die 7-Tage-Serie bis 2. Dezember.",
    ]

    static let names = ["en-US": "7-Day Gratitude Streak", "pt-BR": "Sequência de 7 Dias", "de-DE": "7-Tage-Dankbarkeit"]

    static let why = "The event now ends on Wednesday, December 2, so “by Sunday” is wrong."

    static func event(state: InAppEventState = .draft) -> InAppEvent {
        InAppEvent(
            id: eventID, referenceName: "7-Day Streak", badge: .challenge, state: state, deepLink: "alba://streak", primaryLocale: "en-US",
            purpose: .appropriateForAllUsers,
            schedules: [InAppEventSchedule(territories: ["USA"], publishStart: Data.day(5), eventStart: Data.day(7), eventEnd: Data.day(16))],
            localizations: ["en-US", "pt-BR", "de-DE"].map { locale in
                InAppEventLocalization(
                    id: "loc-\(locale)", locale: locale, name: names[locale] ?? "", shortDescription: "A thank-you a day",
                    longDescription: sunday[locale] ?? "", media: Data.media
                )
            }
        )
    }

    /// `propose_event_texts`' revision of each language's long
    /// description.
    static func revisions(_ locales: [String] = ["en-US", "pt-BR", "de-DE"]) -> JSONValue {
        .array(locales.map { locale in
            ["locale": .string(locale), "longDescription": .string(december[locale] ?? ""), "why": .string(why)]
        })
    }

    static func revision(_ locale: String, longDescription: String? = nil) -> InAppEventTextSuggestion {
        InAppEventTextSuggestion(
            eventID: eventID, locale: locale, name: "", shortDescription: "", longDescription: longDescription ?? december[locale] ?? "",
            why: why, source: "Claude Code", date: Data.now, revisedFields: [.longDescription]
        )
    }
}
