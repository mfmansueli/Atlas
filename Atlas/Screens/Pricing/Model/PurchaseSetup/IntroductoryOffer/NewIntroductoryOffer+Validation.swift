//
//  NewIntroductoryOffer+Validation.swift
//  Atlas
//

import Foundation

extension NewIntroductoryOffer {
    /// Everything App Store Connect would refuse, in the form's order.
    /// `period` is the subscription's billing period and
    /// `subscriptionPrice` its US price, when it has one; `existing`
    /// describes the introductory offer it already has.
    func problems(
        period: SubscriptionPeriod,
        subscriptionPrice: Decimal?,
        existing: String? = nil,
        today: Date = .now
    ) -> [IntroductoryOfferProblem] {
        var problems: [IntroductoryOfferProblem] = []
        if let existing { problems.append(.alreadyHasOne(existing)) }
        let durations = mode.allowedDurations(for: period)
        if !durations.contains(duration) { problems.append(.durationNotAllowed(mode, allowed: durations)) }
        let periods = mode.allowedPeriods(for: period)
        if mode == .payAsYouGo, !periods.contains(numberOfPeriods) { problems.append(.periodsOutOfRange(periods)) }
        problems += priceProblems(subscriptionPrice: subscriptionPrice)
        problems += territoryProblems
        problems += dateProblems(today: today)
        return problems
    }

    private func priceProblems(subscriptionPrice: Decimal?) -> [IntroductoryOfferProblem] {
        guard mode != .freeTrial else { return [] }
        guard let price else { return [.missingPrice] }
        guard NewSubscription.isValidPrice(price) else { return [.invalidPrice] }
        if let subscriptionPrice, subscriptionPrice > 0, price >= subscriptionPrice * Decimal(mode == .payUpFront ? max(1, monthsCovered) : 1) {
            return [.notBelowSubscriptionPrice(CurrencyFormat.forCurrency("USD").format(subscriptionPrice))]
        }
        return []
    }

    /// How many billing periods a pay up front offer covers, roughly, so
    /// $4.99 for three months of a $1.99 monthly subscription passes.
    private var monthsCovered: Int {
        switch duration {
        case .threeDays, .oneWeek, .twoWeeks, .oneMonth: 1
        case .twoMonths: 2
        case .threeMonths: 3
        case .sixMonths: 6
        case .oneYear: 12
        }
    }

    private var territoryProblems: [IntroductoryOfferProblem] {
        guard let ids = territories.chosenIDs else { return [] }
        guard !ids.isEmpty else { return [.noTerritories] }
        let unknown = ids.filter { TerritoryCatalog.standard.territory(alpha3: $0) == nil }
        return unknown.isEmpty ? [] : [.unknownTerritories(unknown)]
    }

    private func dateProblems(today: Date) -> [IntroductoryOfferProblem] {
        var problems: [IntroductoryOfferProblem] = []
        let calendar = Calendar.current
        if let startDate, calendar.startOfDay(for: startDate) < calendar.startOfDay(for: today) { problems.append(.startsInThePast) }
        if let endDate, calendar.startOfDay(for: endDate) <= calendar.startOfDay(for: startDate ?? today) { problems.append(.endsBeforeStart) }
        return problems
    }
}
