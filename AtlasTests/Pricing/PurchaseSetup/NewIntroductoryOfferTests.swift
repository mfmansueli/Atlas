//
//  NewIntroductoryOfferTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Add Introductory Offer… and `propose_introductory_offer` refuse:
/// durations each mode takes, periods, prices below the subscription's,
/// territories and dates.
@Suite("NewIntroductoryOffer")
struct NewIntroductoryOfferTests {
    private static let today = NewIntroductoryOffer.day(from: "2026-11-22") ?? .now
    private static let monthlyPrice = Decimal(string: "9.99")

    private func problems(_ offer: NewIntroductoryOffer, period: SubscriptionPeriod = .oneMonth, existing: String? = nil) -> [IntroductoryOfferProblem] {
        offer.problems(period: period, subscriptionPrice: Self.monthlyPrice, existing: existing, today: Self.today)
    }

    @Test func aOneWeekFreeTrialEverywhereHasNoProblems() {
        #expect(problems(NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek)).isEmpty)
    }

    @Test func everyDurationAllowsAFreeTrialButPayUpFrontStartsAtAMonth() {
        #expect(OfferPaymentMode.freeTrial.allowedDurations(for: .oneMonth) == IntroductoryOfferDuration.allCases)
        #expect(OfferPaymentMode.payUpFront.allowedDurations(for: .oneMonth) == [.oneMonth, .twoMonths, .threeMonths, .sixMonths, .oneYear])
        let upFront = NewIntroductoryOffer(mode: .payUpFront, duration: .oneWeek, price: Decimal(string: "0.99"))
        #expect(problems(upFront).contains { if case .durationNotAllowed = $0 { true } else { false } })
    }

    @Test func payAsYouGoRunsInTheSubscriptionsOwnPeriod() {
        #expect(OfferPaymentMode.payAsYouGo.allowedDurations(for: .oneYear) == [.oneYear])
        #expect(OfferPaymentMode.payAsYouGo.allowedPeriods(for: .oneMonth) == 1...12)
        #expect(OfferPaymentMode.payAsYouGo.allowedPeriods(for: .oneYear) == 1...1)
        let threeMonths = NewIntroductoryOffer(mode: .payAsYouGo, duration: .oneMonth, numberOfPeriods: 3, price: Decimal(string: "4.99"))
        #expect(problems(threeMonths).isEmpty)
        #expect(threeMonths.sentPeriods == 3)
        var tooMany = threeMonths
        tooMany.numberOfPeriods = 13
        #expect(problems(tooMany) == [.periodsOutOfRange(1...12)])
        // Pay as you go in weeks on a monthly subscription isn't offered.
        tooMany.duration = .oneWeek
        tooMany.numberOfPeriods = 2
        #expect(problems(tooMany).contains { if case .durationNotAllowed = $0 { true } else { false } })
    }

    @Test func aPaidOfferNeedsAPriceBelowTheSubscriptions() {
        #expect(problems(NewIntroductoryOffer(mode: .payAsYouGo, duration: .oneMonth)) == [.missingPrice])
        #expect(problems(NewIntroductoryOffer(mode: .payAsYouGo, duration: .oneMonth, price: Decimal(string: "0.999"))) == [.invalidPrice])
        let same = problems(NewIntroductoryOffer(mode: .payAsYouGo, duration: .oneMonth, price: Decimal(string: "9.99")))
        #expect(same.count == 1)
        #expect(same.first.map { if case .notBelowSubscriptionPrice = $0 { true } else { false } } == true)
        // Three months up front may cost more than one month, less than three.
        #expect(problems(NewIntroductoryOffer(mode: .payUpFront, duration: .threeMonths, price: Decimal(string: "19.99"))).isEmpty)
        #expect(!problems(NewIntroductoryOffer(mode: .payUpFront, duration: .threeMonths, price: Decimal(string: "29.97"))).isEmpty)
    }

    @Test func aFreeTrialIgnoresAnyPrice() {
        let trial = NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek, numberOfPeriods: 4, price: Decimal(string: "99"))
        #expect(problems(trial).isEmpty)
        #expect(trial.sentPeriods == 1)
        #expect(trial.formattedPrice == nil)
    }

    @Test func chosenTerritoriesMustBeKnown() {
        var offer = NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek)
        offer.territories = .chosen([])
        #expect(problems(offer) == [.noTerritories])
        offer.territories = .chosen(["USA", "BRA", "XYZ"])
        #expect(problems(offer) == [.unknownTerritories(["XYZ"])])
        offer.territories = .chosen(["USA", "BRA"])
        #expect(problems(offer).isEmpty)
    }

    @Test func datesMustStartTodayOrLaterAndEndAfterTheStart() {
        var offer = NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek)
        offer.startDate = NewIntroductoryOffer.day(from: "2026-11-01")
        #expect(problems(offer) == [.startsInThePast])
        offer.startDate = NewIntroductoryOffer.day(from: "2026-12-01")
        offer.endDate = NewIntroductoryOffer.day(from: "2026-12-01")
        #expect(problems(offer) == [.endsBeforeStart])
        offer.endDate = NewIntroductoryOffer.day(from: "2027-01-01")
        #expect(problems(offer).isEmpty)
    }

    @Test func aSubscriptionWithAnOfferTakesNoOther() {
        let problems = problems(NewIntroductoryOffer(mode: .freeTrial, duration: .oneWeek), existing: "Free for 1 week")
        #expect(problems == [.alreadyHasOne("Free for 1 week")])
    }

    @Test func daysAreAppStoreConnectDates() {
        let day = NewIntroductoryOffer.day(from: "2026-12-01")
        #expect(day.map(NewIntroductoryOffer.dayString) == "2026-12-01")
        #expect(NewIntroductoryOffer.day(from: "12/01/2026") == nil)
    }

    @Test func modesAndDurationsUseTheAPIsValues() {
        #expect(OfferPaymentMode.allCases.map(\.apiValue).sorted() == ["FREE_TRIAL", "PAY_AS_YOU_GO", "PAY_UP_FRONT"])
        #expect(OfferPaymentMode(apiValue: "PAY_UP_FRONT") == .payUpFront)
        #expect(IntroductoryOfferDuration(.oneYear) == .oneYear)
        #expect(IntroductoryOfferDuration.allCases.map(\.rawValue) == [
            "THREE_DAYS", "ONE_WEEK", "TWO_WEEKS", "ONE_MONTH", "TWO_MONTHS", "THREE_MONTHS", "SIX_MONTHS", "ONE_YEAR",
        ])
    }
}
