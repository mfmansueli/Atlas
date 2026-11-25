//
//  ResultsEvaluator.swift
//  Atlas
//

import Foundation

/// Before-and-after rules for the Results tab: 28-day windows either side of
/// a change, plain verdicts, and "too few to tell" under 28 days or 30
/// starts on a side (HowSure's "Sure" asks the same).
enum ResultsEvaluator {
    static let windowDays = 28
    /// Fewer starts than this on either side is too few to tell.
    static let minimumStarts = 30

    /// Conversion decides, with Analytics' two-proportion test at 90% (the
    /// 90% interval for the change excludes zero); proceeds can only hold a
    /// verdict back: more starts for less money, or fewer starts for more,
    /// is about the same.
    static func verdict(before: SalesWindow, after: SalesWindow) -> ResultVerdict {
        guard before.days >= windowDays, after.days >= windowDays,
              before.starts >= minimumStarts, after.starts >= minimumStarts,
              // Starts from outside the page (offer codes, the web) would
              // make the rate meaningless.
              before.starts <= before.pageViews, after.starts <= after.pageViews
        else { return .tooLittleData }
        switch conversionChange(before: before, after: after).outcome {
        case .tooFew: return .tooLittleData
        case .same: return .aboutTheSame
        case .higher: return after.proceeds >= before.proceeds ? .better : .aboutTheSame
        case .lower: return after.proceeds <= before.proceeds ? .worse : .aboutTheSame
        }
    }

    /// Page view → start conversion after the change against before it.
    static func conversionChange(before: SalesWindow, after: SalesWindow) -> PeriodComparison {
        AnalyticsStatistics.compare(
            count: after.starts, total: after.pageViews, previousCount: before.starts, previousTotal: before.pageViews,
            minimumCount: minimumStarts
        )
    }

    /// Too early until 28 days have passed since the change (the change day
    /// is day 1), then ready.
    static func availability(changedOn date: Date, now: Date, calendar: Calendar = .gmtGregorian) -> ResultsAvailability {
        let start = calendar.startOfDay(for: date)
        let elapsed = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: now)).day ?? 0
        guard elapsed < windowDays else { return .ready }
        let arrivesOn = calendar.date(byAdding: .day, value: windowDays, to: start) ?? start
        return .tooEarly(day: max(elapsed, 0) + 1, arrivesOn: arrivesOn)
    }

    /// Totals over the territories with enough data.
    static func summarize(_ results: [PriceChangeResult]) -> ResultsSummary {
        let counted = results.filter(\.verdict.hasEnoughData)
        return ResultsSummary(
            territoryCount: results.count,
            countedCount: counted.count,
            betterCount: counted.count { $0.verdict == .better },
            worseCount: counted.count { $0.verdict == .worse },
            tooLittleDataCount: results.count - counted.count,
            startsBefore: counted.reduce(0) { $0 + $1.before.starts },
            startsAfter: counted.reduce(0) { $0 + $1.after.starts },
            proceedsBefore: counted.reduce(0) { $0 + $1.before.proceeds },
            proceedsAfter: counted.reduce(0) { $0 + $1.after.proceeds }
        )
    }

    /// Proceeds of `starts` at `price`, in US dollars: starts × price ÷ (1 +
    /// tax) × (1 − commission) ÷ the currency's rate.
    static func proceeds(
        starts: Int,
        price: Decimal,
        territory: Territory,
        commission: Commission,
        rates: ExchangeRates = .current
    ) -> Decimal {
        let local = commission.proceeds(customerPrice: price, taxRate: territory.taxRate) * Decimal(starts)
        return rates.dollars(local, currency: territory.currencyCode) ?? local
    }
}
