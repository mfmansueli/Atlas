//
//  AnalyticsDay.swift
//  Atlas
//

import Foundation

/// One calendar day of Apple's reports (they're in UTC), as days since
/// 1970, so periods are plain arithmetic.
struct AnalyticsDay: Hashable, Comparable, Sendable, Codable {
    var number: Int

    init(number: Int) {
        self.number = number
    }

    init(_ date: Date) {
        number = Int((date.timeIntervalSince1970 / 86400).rounded(.down))
    }

    /// From "2026-11-09", as the reports write it; nil for anything else.
    init?(iso text: String) {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = Calendar.gmtGregorian.date(from: components) else { return nil }
        self.init(date)
    }

    init(from decoder: any Decoder) throws {
        number = try decoder.singleValueContainer().decode(Int.self)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(number)
    }

    /// Midnight UTC of the day.
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(number) * 86400)
    }

    /// "2026-11-09".
    var iso: String {
        let parts = Calendar.gmtGregorian.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    func adding(_ days: Int) -> AnalyticsDay {
        AnalyticsDay(number: number + days)
    }

    static func < (lhs: AnalyticsDay, rhs: AnalyticsDay) -> Bool {
        lhs.number < rhs.number
    }
}
