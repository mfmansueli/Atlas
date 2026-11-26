//
//  AnalyticsTabAvailability.swift
//  Atlas
//

import Foundation

/// Why one Analytics view has nothing to show yet (README-DS §16 "No data
/// yet", Apple's rules in the docs). The view shows a small
/// ContentUnavailableView, its card in the strip and its Overview KPI say
/// the same case.
///
/// Apple's rules behind them: reports use Pacific time; subscription
/// reports start the day after the first auto-renewable subscription is
/// sold (free trials and introductory offers count); rows with fewer than
/// 5 people are left out; crashes come only from people who share
/// analytics with developers, and show once at least 5 of them had one.
enum AnalyticsTabAvailability: Hashable, Sendable {
    case available
    /// No auto-renewable subscription sold yet, trials included.
    case noSubscriptionsSold
    /// Trials, but nobody paid yet.
    case noPaidSubscribers(trials: Int)
    /// Too few subscribers for rates; counts stay complete.
    case tooFewSubscribers(count: Int)
    /// The newest version is too new for crash numbers.
    case versionTooNew(version: String, previous: String?, previousRate: Double?)
    /// The app has too few people yet.
    case notEnoughPeople
    /// Fewer than 5 opted-in people had a crash.
    case noCrashes

    /// Apple leaves out rows with fewer people than this, and shows a
    /// version's crashes only once this many people who share analytics
    /// with developers had one.
    static let minimumPeople = 5

    var isAvailable: Bool { self == .available }

    /// The empty state's title.
    var title: String {
        switch self {
        case .available: ""
        case .noSubscriptionsSold: String(localized: "No subscriptions sold yet", comment: "kind:empty-title")
        case .noPaidSubscribers: String(localized: "No paid subscribers yet", comment: "kind:empty-title")
        case .tooFewSubscribers: String(localized: "Too few subscribers to show rates", comment: "kind:empty-title")
        case let .versionTooNew(version, _, _): String(localized: "\(version) is too new to tell", comment: "kind:empty-title")
        case .notEnoughPeople: String(localized: "Not enough people yet", comment: "kind:empty-title")
        case .noCrashes: String(localized: "No crashes reported", comment: "kind:empty-title")
        }
    }

    /// The card's short summary in the strip, and the KPI's line.
    var cardSummary: String {
        switch self {
        case .available: ""
        case .noSubscriptionsSold: String(localized: "None sold yet", comment: "kind:card-summary")
        case .noPaidSubscribers: String(localized: "No paid subscribers yet", comment: "kind:card-summary")
        case .tooFewSubscribers: String(localized: "Too few to show rates", comment: "kind:card-summary")
        case let .versionTooNew(version, _, _): String(localized: "\(version) too new to tell", comment: "kind:card-summary")
        case .notEnoughPeople: String(localized: "Not enough people yet", comment: "kind:card-summary")
        case .noCrashes: String(localized: "No crashes reported", comment: "kind:card-summary")
        }
    }
}
