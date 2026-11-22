//
//  IntroductoryOfferDuration.swift
//  Atlas
//

import Foundation

/// How long an introductory offer lasts (a free trial, or a pay up front
/// offer), or one period of a pay as you go offer: App Store Connect's
/// `SubscriptionOfferDuration`.
enum IntroductoryOfferDuration: String, CaseIterable, Codable, Hashable, Sendable {
    case threeDays = "THREE_DAYS"
    case oneWeek = "ONE_WEEK"
    case twoWeeks = "TWO_WEEKS"
    case oneMonth = "ONE_MONTH"
    case twoMonths = "TWO_MONTHS"
    case threeMonths = "THREE_MONTHS"
    case sixMonths = "SIX_MONTHS"
    case oneYear = "ONE_YEAR"

    /// "1 week".
    var title: String {
        switch self {
        case .threeDays: String(localized: "3 days")
        case .oneWeek: String(localized: "1 week")
        case .twoWeeks: String(localized: "2 weeks")
        case .oneMonth: String(localized: "1 month")
        case .twoMonths: String(localized: "2 months")
        case .threeMonths: String(localized: "3 months")
        case .sixMonths: String(localized: "6 months")
        case .oneYear: String(localized: "1 year")
        }
    }

    /// "week", for "$0.99 a week for 3 weeks".
    var unitTitle: String {
        switch self {
        case .threeDays: String(localized: "3 days")
        case .oneWeek: String(localized: "week")
        case .twoWeeks: String(localized: "2 weeks")
        case .oneMonth: String(localized: "month")
        case .twoMonths: String(localized: "2 months")
        case .threeMonths: String(localized: "3 months")
        case .sixMonths: String(localized: "6 months")
        case .oneYear: String(localized: "year")
        }
    }

    /// The offer duration that is one billing period of `period`.
    init(_ period: SubscriptionPeriod) {
        switch period {
        case .oneWeek: self = .oneWeek
        case .oneMonth: self = .oneMonth
        case .twoMonths: self = .twoMonths
        case .threeMonths: self = .threeMonths
        case .sixMonths: self = .sixMonths
        case .oneYear: self = .oneYear
        }
    }
}
