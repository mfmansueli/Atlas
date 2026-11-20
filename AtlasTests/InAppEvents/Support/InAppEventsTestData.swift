//
//  InAppEventsTestData.swift
//  AtlasTests
//

import Foundation
@testable import Atlas

/// Events for the In-App Events tests: a draft challenge written in
/// English and German (German incomplete), a live update and an ended
/// week. "Now" is Nov 16, 2026.
enum InAppEventsTestData {
    static let app = StoreApp(id: "6450000001", name: "Lumen Journal", bundleID: "com.northpier.lumen", sku: "LUMEN-01", primaryLocale: "en-US")
    static let now = Date(timeIntervalSince1970: 1_794_830_400)

    static func day(_ offset: Double) -> Date {
        now.addingTimeInterval(offset * 86400)
    }

    static let media = [InAppEventMedia(kind: .card, width: 1920, height: 1080), InAppEventMedia(kind: .details, width: 1080, height: 1920)]

    static let winter = InAppEvent(
        id: "winter", referenceName: "Winter Reflection 2026", badge: .challenge, state: .draft, deepLink: "lumen://challenge/winter",
        primaryLocale: "en-US", purpose: .appropriateForAllUsers,
        schedules: [InAppEventSchedule(territories: [], publishStart: day(8), eventStart: day(15), eventEnd: day(45))],
        localizations: [
            InAppEventLocalization(
                id: "loc-en", locale: "en-US", name: "Winter Reflection Challenge", shortDescription: "31 prompts to close the year gently",
                longDescription: "Three lines a day through December.", media: media
            ),
            InAppEventLocalization(id: "loc-de", locale: "de-DE", name: "Winter-Reflexion"),
        ]
    )

    static let update = InAppEvent(
        id: "update", referenceName: "1.3 Weekly Review", badge: .majorUpdate, state: .published, primaryLocale: "en-US",
        schedules: [InAppEventSchedule(eventStart: day(-5), eventEnd: day(9))],
        localizations: [InAppEventLocalization(id: "loc-u", locale: "en-US", name: "Weekly Review", shortDescription: "s", longDescription: "l", media: media)]
    )

    static let gratitude = InAppEvent(
        id: "gratitude", referenceName: "Gratitude Week", badge: .specialEvent, state: .past, primaryLocale: "en-US",
        purpose: .appropriateForAllUsers,
        schedules: [InAppEventSchedule(publishStart: day(-23), eventStart: day(-16), eventEnd: day(-9))],
        localizations: [InAppEventLocalization(id: "loc-g", locale: "en-US", name: "Gratitude Week", shortDescription: "s", longDescription: "l", media: media)]
    )

    static let events = [winter, update, gratitude]

    static func suggestion(_ locale: String, event: String = "winter", name: String = "Name") -> InAppEventTextSuggestion {
        InAppEventTextSuggestion(
            eventID: event, locale: locale, name: name, shortDescription: "Short \(locale)", longDescription: "Long \(locale)",
            why: "Reads naturally.", source: "Claude Code", date: now
        )
    }
}
