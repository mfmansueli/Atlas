//
//  SubscriptionOfferValidationTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What App Store Connect would refuse for a promotional offer, win-back
/// offer or offer code, checked the same way in Pricing's sheets and the
/// assistants' proposals.
@Suite("Subscription offer validation")
struct SubscriptionOfferValidationTests {
    static let today = NewIntroductoryOffer.day(from: "2026-11-23") ?? .now
    static let paid = OfferTerms(mode: .payAsYouGo, duration: .oneMonth, numberOfPeriods: 3, price: Decimal(string: "2.99"))
    static let trial = OfferTerms(mode: .freeTrial, duration: .oneMonth)

    private static func day(_ text: String) -> Date {
        NewIntroductoryOffer.day(from: text) ?? .now
    }

    // MARK: - Rules

    @Test func identifiersAreLettersDigitsUnderscoresAndDots() {
        #expect(SubscriptionOfferRules.isValidIdentifier("lumen.monthly_comeback2"))
        #expect(!SubscriptionOfferRules.isValidIdentifier(""))
        #expect(!SubscriptionOfferRules.isValidIdentifier("half price"))
        #expect(!SubscriptionOfferRules.isValidIdentifier("café"))
        #expect(!SubscriptionOfferRules.isValidIdentifier(String(repeating: "a", count: 65)))
    }

    @Test func anIdentifierFollowsTheName() {
        #expect(SubscriptionOfferRules.identifier(from: "Half price for 3 months!") == "half_price_for_3_months")
        #expect(SubscriptionOfferRules.identifier(from: "Été — volta") == "ete_volta")
        #expect(SubscriptionOfferRules.identifier(from: "  ") == "")
    }

    @Test func customCodesAreUppercaseLettersAndDigitsAndFollowAppReviewsRules() {
        #expect(SubscriptionOfferRules.customCode(" podcast30 ") == "PODCAST30")
        #expect(SubscriptionOfferRules.customCodeProblems("PODCAST30", taken: []).isEmpty)
        #expect(SubscriptionOfferRules.customCodeProblems("PODCAST 30", taken: []) == [.invalidCustomCode])
        #expect(SubscriptionOfferRules.customCodeProblems("PODCAST30", taken: ["PODCAST30"]) == [.customCodeTaken("PODCAST30")])
        // Customers type it: no other platforms, betas or placeholders.
        #expect(SubscriptionOfferRules.customCodeProblems("ANDROID", taken: []).contains { if case .customCodeGuideline = $0 { true } else { false } })
        #expect(SubscriptionOfferRules.customCodeProblems("BETA", taken: []).contains { if case .customCodeGuideline = $0 { true } else { false } })
    }

    @Test func datesStartTodayOrLaterAndEndAfterTheStart() {
        #expect(SubscriptionOfferRules.dateProblems(start: Self.today, end: nil, today: Self.today).isEmpty)
        #expect(SubscriptionOfferRules.dateProblems(start: Self.day("2026-11-01"), end: nil, today: Self.today) == [.startsInThePast])
        #expect(SubscriptionOfferRules.dateProblems(start: Self.day("2026-12-10"), end: Self.day("2026-12-01"), today: Self.today) == [.endsBeforeStart])
    }

    // MARK: - Terms

    @Test func termsCheckLikeAnIntroductoryOfferAndTheirTerritoryPrices() {
        #expect(Self.paid.problems(period: .oneMonth, subscriptionPrice: Decimal(string: "4.99")).isEmpty)
        // Not below the subscription's price.
        var expensive = Self.paid
        expensive.price = Decimal(string: "9.99")
        #expect(!expensive.problems(period: .oneMonth, subscriptionPrice: Decimal(string: "4.99")).isEmpty)

        var apart = Self.paid
        apart.territoryPrices = ["USA": 1, "BRA": Decimal(string: "4.90") ?? 0, "XYZ": 1]
        let problems = apart.problems(period: .oneMonth, subscriptionPrice: Decimal(string: "4.99"))
        #expect(problems.contains(.basePriceSetApart))
        #expect(problems.contains(.terms(.unknownTerritories(["XYZ"]))))

        var outside = Self.paid
        outside.territories = .chosen(["USA", "GBR"])
        outside.territoryPrices = ["BRA": Decimal(string: "4.90") ?? 0]
        #expect(outside.problems(period: .oneMonth, subscriptionPrice: nil).contains(.pricedOutsideTerritories(["BRA"])))

        var invalid = Self.paid
        invalid.territoryPrices = ["BRA": -1]
        #expect(invalid.problems(period: .oneMonth, subscriptionPrice: nil).contains(.invalidTerritoryPrices(["BRA"])))
    }

    @Test func aFreeOfferIgnoresPricesAndAShareFollowsThePrice() {
        var trial = Self.trial
        trial.territoryPrices = ["BRA": 1]
        #expect(trial.problems(period: .oneMonth, subscriptionPrice: nil).isEmpty)
        #expect(trial.sentPrice == nil)
        #expect(trial.sentTerritoryPrices.isEmpty)
        #expect(Self.paid.priceShare(of: Decimal(string: "5.98")) == Decimal(string: "0.5"))
    }

    // MARK: - Promotional offers

    @Test func aPromotionalOfferNeedsANameAndAFreeIdentifier() {
        let offer = NewPromotionalOffer(name: "Come back", identifier: "come_back", terms: Self.paid)
        #expect(offer.problems(period: .oneMonth, subscriptionPrice: Decimal(string: "4.99"), existing: []).isEmpty)

        let existing = ExistingPromotionalOffer(id: "p1", name: "Old", identifier: "come_back", mode: .freeTrial, duration: .oneWeek)
        #expect(offer.problems(period: .oneMonth, subscriptionPrice: nil, existing: [existing])
            == [.identifierTaken(NewPromotionalOffer.identifierLabel, value: "come_back")])
        #expect(offer.problems(period: .oneMonth, subscriptionPrice: nil, existing: [], takenIdentifiers: ["come_back"])
            == [.identifierTaken(NewPromotionalOffer.identifierLabel, value: "come_back")])

        let unnamed = NewPromotionalOffer(name: " ", identifier: "come back", terms: Self.trial)
        #expect(unnamed.problems(period: .oneMonth, subscriptionPrice: nil, existing: []) == [
            .missingName(NewPromotionalOffer.nameLabel), .invalidIdentifier(NewPromotionalOffer.identifierLabel),
        ])
    }

    @Test func aSubscriptionTakesTenPromotionalOffers() {
        let existing = (1...10).map { ExistingPromotionalOffer(id: "p\($0)", name: "O\($0)", identifier: "o\($0)", mode: .freeTrial, duration: .oneWeek) }
        let offer = NewPromotionalOffer(name: "Eleventh", identifier: "eleventh", terms: Self.trial)
        #expect(offer.problems(period: .oneMonth, subscriptionPrice: nil, existing: existing).first == .tooMany(.promotional, limit: 10))
    }

    // MARK: - Win-back offers

    @Test func aWinBackOfferChecksItsEligibilityAndDates() {
        let settings = WinBackOfferSettings(startDate: Self.day("2026-12-01"))
        let offer = NewWinBackOffer(referenceName: "We miss you", offerID: "we_miss_you", terms: Self.trial, settings: settings)
        #expect(offer.problems(period: .oneMonth, subscriptionPrice: nil, existing: [], today: Self.today).isEmpty)

        var late = offer
        late.settings.startDate = Self.day("2026-11-01")
        late.settings.eligibility.paidMonths = 0
        late.settings.eligibility.waitMonths = 99
        let problems = late.problems(period: .oneMonth, subscriptionPrice: nil, existing: [], today: Self.today)
        #expect(problems.contains(.startsInThePast))
        #expect(problems.count(where: { if case .invalidEligibilityMonths = $0 { true } else { false } }) == 2)

        let existing = ExistingWinBackOffer(
            id: "w1", referenceName: "Old", offerID: "we_miss_you", mode: .freeTrial, duration: .oneWeek, settings: settings
        )
        #expect(offer.problems(period: .oneMonth, subscriptionPrice: nil, existing: [existing], today: Self.today)
            == [.identifierTaken(NewWinBackOffer.identifierLabel, value: "we_miss_you")])
    }

    @Test func aStartedWinBackOfferKeepsItsStart() {
        let settings = WinBackOfferSettings(startDate: Self.day("2026-11-01"), endDate: Self.day("2026-12-31"))
        #expect(settings.problems(today: Self.today, startIsFixed: true).isEmpty)
        #expect(settings.problems(today: Self.today) == [.startsInThePast])
        var ended = settings
        ended.endDate = Self.day("2026-11-20")
        #expect(ended.problems(today: Self.today, startIsFixed: true) == [.endsBeforeStart])
    }

    // MARK: - Offer codes

    @Test func anOfferCodeChecksItsNameEligibilityAndCodes() {
        var code = NewOfferCode(name: "Podcast listeners", terms: Self.trial)
        code.customCode = NewCustomCode(code: "podcast30", numberOfCodes: 1000, expirationDate: Self.day("2026-12-31"))
        code.oneTimeCodes = NewOneTimeCodes(numberOfCodes: 500, expirationDate: Self.day("2027-01-31"))
        #expect(code.problems(period: .oneMonth, subscriptionPrice: nil, existing: [], today: Self.today).isEmpty)

        let existing = ExistingOfferCode(
            id: "c1", name: "Podcast listeners", eligibilities: [.new], mode: .freeTrial, duration: .oneWeek,
            customCodes: [ExistingCustomCode(id: "cc1", code: "PODCAST30", numberOfCodes: 10)]
        )
        let problems = code.problems(period: .oneMonth, subscriptionPrice: nil, existing: [existing], today: Self.today)
        #expect(problems.contains(.identifierTaken(NewOfferCode.nameLabel, value: "Podcast listeners")))
        #expect(problems.contains(.customCodeTaken("PODCAST30")))

        code.eligibilities = []
        code.oneTimeCodes?.numberOfCodes = 0
        code.oneTimeCodes?.expirationDate = Self.today
        let more = code.problems(period: .oneMonth, subscriptionPrice: nil, existing: [], today: Self.today)
        #expect(more.contains(.noCustomerEligibility))
        #expect(more.contains(.numberOfCodesOutOfRange(SubscriptionOfferRules.numberOfCodes)))
        #expect(more.contains(.expiresInThePast))
    }

    @Test func onlyActiveOfferCodesCountTowardTen() {
        let inactive = (1...10).map {
            ExistingOfferCode(id: "c\($0)", name: "C\($0)", eligibilities: [.new], mode: .freeTrial, duration: .oneWeek, isActive: false)
        }
        let code = NewOfferCode(name: "Fresh", terms: Self.trial)
        #expect(code.problems(period: .oneMonth, subscriptionPrice: nil, existing: inactive, today: Self.today).isEmpty)
        var active = inactive
        for index in active.indices { active[index].isActive = true }
        #expect(code.problems(period: .oneMonth, subscriptionPrice: nil, existing: active, today: Self.today).first == .tooMany(.offerCode, limit: 10))
    }

    @Test func everyProblemSaysWhatsWrong() {
        let problems: [SubscriptionOfferProblem] = [
            .terms(.missingPrice), .basePriceSetApart, .pricedOutsideTerritories(["BRA"]), .invalidTerritoryPrices(["BRA"]),
            .missingName("reference name"), .nameTooLong("reference name", limit: 64), .invalidIdentifier("offer ID"),
            .identifierTaken("offer ID", value: "x"), .tooMany(.promotional, limit: 10), .subscriptionNotCreated,
            .noCustomerEligibility, .invalidEligibilityMonths("How long they paid", range: 1...60), .sinceLastSubscribedReversed,
            .startsInThePast, .endsBeforeStart, .invalidCustomCode, .customCodeTaken("X"), .customCodeGuideline("No Android."),
            .numberOfCodesOutOfRange(1...10), .expiresInThePast, .notActive, .nothingChanged,
        ]
        for problem in problems {
            #expect(!problem.message.isEmpty, "\(problem)")
        }
    }
}
