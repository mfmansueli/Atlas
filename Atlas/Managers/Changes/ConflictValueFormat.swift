//
//  ConflictValueFormat.swift
//  Atlas
//

import Foundation

/// How a `ConflictCheck` turns the raw value it read into what the review
/// row shows: text as it is, a decimal price in a currency, or a date.
enum ConflictValueFormat: Hashable, Codable, Sendable {
    case text
    /// `customerPrice` strings like "199.9", shown as e.g. "R$ 199,90".
    case currency(code: String, localeIdentifier: String)
    /// An ISO 8601 date and time (an event's `publishStart`), compared by
    /// the moment it names: `…T00:00:00Z` and `…T00:00:00.000Z` match.
    case date

    func display(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return String(localized: "Empty") }
        switch self {
        case .text:
            return raw
        case let .currency(code, localeIdentifier):
            guard let amount = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) else { return raw }
            return amount.formatted(.currency(code: code).locale(Locale(identifier: localeIdentifier)))
        case .date:
            return AppStoreConnectDate.date(raw).map { InAppEventDateText.current.date($0) } ?? raw
        }
    }
}
