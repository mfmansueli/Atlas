//
//  AppStoreConnectDate.swift
//  Atlas
//

import Foundation

/// App Store Connect's dates: ISO 8601 with a time zone, with or without
/// fractional seconds (`2026-11-15T10:42:00-08:00`, `2026-11-15T18:42:00.000Z`).
enum AppStoreConnectDate {
    static func date(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }

    /// As App Store Connect takes a date, e.g. a version's earliest release.
    static func text(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
