//
//  OfferPaymentMode+API.swift
//  Atlas
//

import Foundation

/// App Store Connect's `SubscriptionOfferMode` for each payment mode, and
/// what an introductory offer of that mode may last.
extension OfferPaymentMode {
    /// `FREE_TRIAL`, `PAY_AS_YOU_GO` or `PAY_UP_FRONT`.
    var apiValue: String {
        switch self {
        case .freeTrial: "FREE_TRIAL"
        case .payAsYouGo: "PAY_AS_YOU_GO"
        case .payUpFront: "PAY_UP_FRONT"
        }
    }

    init?(apiValue: String) {
        guard let mode = Self.allCases.first(where: { $0.apiValue == apiValue.uppercased() }) else { return nil }
        self = mode
    }

    /// The durations App Store Connect offers for this mode, as its
    /// Introductory Offers sheet lists them; a pay as you go offer's is one
    /// billing period of the subscription.
    func allowedDurations(for period: SubscriptionPeriod) -> [IntroductoryOfferDuration] {
        switch self {
        case .freeTrial: IntroductoryOfferDuration.allCases
        case .payUpFront: [.oneMonth, .twoMonths, .threeMonths, .sixMonths, .oneYear]
        case .payAsYouGo: [IntroductoryOfferDuration(period)]
        }
    }

    /// How many periods the offer may run: up to a year of a pay as you go
    /// offer's billing periods (12 weeks for a weekly one), one otherwise.
    func allowedPeriods(for period: SubscriptionPeriod) -> ClosedRange<Int> {
        guard self == .payAsYouGo else { return 1...1 }
        switch period {
        case .oneWeek, .oneMonth: return 1...12
        case .twoMonths: return 1...6
        case .threeMonths: return 1...4
        case .sixMonths: return 1...2
        case .oneYear: return 1...1
        }
    }
}
