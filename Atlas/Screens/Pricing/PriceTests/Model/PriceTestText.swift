//
//  PriceTestText.swift
//  Atlas
//

import Foundation

/// Dates and lines several price test views share.
enum PriceTestText {
    /// "Dec 23", in GMT like Results' dates.
    static func shortDate(_ date: Date) -> String {
        date.formatted(shortStyle)
    }

    /// "Day 9 of 28".
    static func day(_ day: Int) -> String {
        String(localized: "Day \(day) of \(PriceTest.days)", comment: "kind:pill")
    }

    /// "Europe · day 9 of 28 · ends Dec 23", the product pill's tooltip.
    static func pillTip(_ test: PriceTest, today: Date) -> String {
        guard let endsOn = test.endsOn else {
            return String(localized: "\(test.region.title) · waits in Review & Push", comment: "kind:tooltip")
        }
        return String(
            localized: "\(test.region.title) · day \(test.day(on: today)) of \(PriceTest.days) · ends \(shortDate(endsOn))",
            comment: "kind:tooltip"
        )
    }

    /// "Germany €39.99 → €31.99, France €39.99 → €31.99, Spain …".
    static func examples(_ countries: [PriceTestCountry]) -> String {
        countries.prefix(3).map { $0.example() }.joined(separator: ", ")
    }

    private static let shortStyle = Date.FormatStyle(date: .abbreviated, time: .omitted, locale: Locale(identifier: "en_US"), timeZone: .gmt)
        .year(.omitted)
}
