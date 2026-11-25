//
//  WatchSignal.swift
//  Atlas
//

import Foundation

/// One thing a check found in an app, worth an improvement: what it is, what
/// it's about and the numbers behind it. Its fingerprint (kind, app,
/// subject and rounded numbers) tells the same finding from a new one, so
/// Look for Improvements never asks twice about the same thing.
struct WatchSignal: Identifiable, Hashable, Codable, Sendable {
    var kind: WatchSignalKind
    var appID: StoreApp.ID
    /// What it's about: a version ("1.4"), a version's id, an event's id.
    var subject: String
    /// The number it rests on, to tell when a dismissed one changed a lot.
    var value: Double
    /// The numbers behind it; rounded, they're part of the fingerprint.
    var numbers: [String: Double] = [:]
    /// One line for the assistant's prompt, in English like the prompt.
    var summary: String
    /// When it stops mattering, e.g. the day an event's card shows.
    var deadline: Date?

    /// A number that moved by more than this share is a new finding, as for
    /// a dismissed Analytics finding (`DismissedFinding`).
    static let returnShare = DismissedFinding.returnShare

    /// `kind.app.subject`: the same finding whatever its numbers.
    var identity: String { "\(kind.rawValue).\(appID).\(subject)" }

    /// `kind.app.subject|name=rounded|…`, the numbers in name order with two
    /// significant digits, so small moves keep it.
    var fingerprint: String {
        ([identity] + numbers.keys.sorted().map { "\($0)=\(Self.rounded(numbers[$0] ?? 0))" }).joined(separator: "|")
    }

    var id: String { fingerprint }

    /// Whether `value` moved by more than `returnShare` from `old`.
    func hasMovedALot(from old: Double) -> Bool {
        guard old != 0 else { return value != 0 }
        return abs(value - old) / abs(old) > Self.returnShare
    }

    /// Two significant digits, written the same on every Mac: 3.24 → "3.2",
    /// 1234 → "1200".
    static func rounded(_ value: Double) -> String {
        guard value.isFinite, value != 0 else { return "0" }
        return value.formatted(.number.precision(.significantDigits(1...2)).grouping(.never).locale(Locale(identifier: "en_US_POSIX")))
    }
}
