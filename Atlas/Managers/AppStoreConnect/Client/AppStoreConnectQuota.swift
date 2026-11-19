//
//  AppStoreConnectQuota.swift
//  Atlas
//

import Foundation
import Synchronization

/// The hourly quota App Store Connect reported last, per API key, from the
/// `X-Rate-Limit` header of every read. Reading sections ahead in the
/// background asks it first, so it never spends what the person's own
/// work needs.
final class AppStoreConnectQuota: Sendable {
    static let shared = AppStoreConnectQuota()

    /// How long a reading says anything: the quota is per rolling hour.
    static let readingLifetime: TimeInterval = 60 * 60

    private let readings = Mutex<[String: Reading]>([:])

    private struct Reading {
        var rateLimit: AppStoreConnectRateLimit
        var date: Date
    }

    /// Notes what a response said about the key's quota; a missing or
    /// malformed header changes nothing.
    func record(header: String?, keyID: String, at date: Date) {
        guard let rateLimit = AppStoreConnectRateLimit(header: header) else { return }
        readings.withLock { $0[keyID] = Reading(rateLimit: rateLimit, date: date) }
    }

    /// The quota last reported for the key; nil before its first read and
    /// once the reading is over an hour old.
    func rateLimit(keyID: String, now: Date = .now) -> AppStoreConnectRateLimit? {
        readings.withLock { readings in
            guard let reading = readings[keyID], now.timeIntervalSince(reading.date) < Self.readingLifetime else { return nil }
            return reading.rateLimit
        }
    }
}
