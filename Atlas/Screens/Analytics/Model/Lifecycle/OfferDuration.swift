//
//  OfferDuration.swift
//  Atlas
//

import Foundation

/// Reads Apple's Offer Duration ("1 Week", "3 Months", "7 Days", or an
/// ISO 8601 period such as "P1M") as days.
enum OfferDuration {
    static func days(_ text: String) -> Int? {
        let value = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !value.isEmpty else { return nil }
        if value.hasPrefix("p"), let unit = value.last, let number = Int(value.dropFirst().dropLast()) {
            return days(number, unit: String(unit))
        }
        let parts = value.split(separator: " ")
        guard parts.count >= 2, let number = Int(parts[0]) else { return nil }
        return days(number, unit: String(parts[1]))
    }

    private static func days(_ number: Int, unit: String) -> Int? {
        switch unit.prefix(1) {
        case "d": number
        case "w": number * 7
        case "m": number * 30
        case "y": number * 365
        default: nil
        }
    }
}
