//
//  AnalyticsEmptyContentTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Subscriptions and Stability say while they have nothing to show
/// (board 92): the title, Apple's rule in a sentence or two, 2 or 3 facts,
/// the one button and the small line, in Atlas's voice.
@Suite("Analytics · empty states' words")
struct AnalyticsEmptyContentTests {
    private let today = AnalyticsTestData.through

    private func subscriptions(_ soFar: SubscriptionsSoFar, appName: String = "Parcel Pal") throws -> AnalyticsEmptyContent {
        try #require(AnalyticsEmptyContent.subscriptions(soFar, appName: appName))
    }

    private func stability(_ soFar: CrashesSoFar, appName: String = "Parcel Pal") throws -> AnalyticsEmptyContent {
        try #require(AnalyticsEmptyContent.stability(soFar, appName: appName))
    }

    private func labels(_ content: AnalyticsEmptyContent) -> [String] {
        content.facts.map(\.label)
    }

    private func value(_ label: String, in content: AnalyticsEmptyContent) -> String? {
        content.facts.first { $0.label == label }?.value
    }

    // MARK: - Subscriptions

    @Test func nothingSoldSaysWhenReportsStart() throws {
        let content = try subscriptions(SubscriptionsSoFar(today: today))
        #expect(content.title == "No subscriptions sold yet")
        #expect(content.text == """
        Apple starts the subscription reports the day after the first auto-renewable subscription is sold, free trials included. \
        Until then there’s nothing to count.
        """)
        #expect(labels(content) == ["Reports start", "Free trials", "Time zone"])
        #expect(value("Reports start", in: content) == "The day after the first sale")
        #expect(value("Time zone", in: content) == "Pacific")
        #expect(content.note == "Atlas checks every morning. Trials, renewals and cancellations show here after the first sale.")
        #expect(content.action == .openPricing)
        #expect(AnalyticsEmptyAction.openPricing.title == "Open Pricing")
    }

    @Test func oneTrialSaysNobodyPaidYet() throws {
        let soFar = SubscriptionsSoFar(firstSale: today.adding(-3), trials: 1, people: 1, today: today)
        let content = try subscriptions(soFar)
        #expect(content.title == "No paid subscribers yet")
        #expect(content.text == "One free trial started, and nobody has paid yet. Renewals, cancellations and proceeds show here from the first payment.")
        #expect(labels(content) == ["Trials", "Paid", "First sale"])
        #expect(value("Trials", in: content) == "1")
        #expect(value("Paid", in: content) == "0")
        #expect(value("First sale", in: content) == AnalyticsText.day(today.adding(-3).date))
        #expect(content.note == "Apple leaves out rows with fewer than 5 people, so rates appear once there are more subscribers.")
        #expect(content.action == .openPricing)
    }

    @Test func severalTrialsAreCounted() {
        #expect(AnalyticsEmptyContent.noPaidText(trials: 3).hasPrefix("3 free trials started, and nobody has paid yet."))
    }

    @Test func aTrialStillRunningSaysWhenItEnds() throws {
        let soFar = SubscriptionsSoFar(firstSale: today.adding(-3), trials: 1, people: 1, firstTrialEnds: today.adding(4), today: today)
        let content = try subscriptions(soFar)
        #expect(labels(content) == ["Trials", "Paid", "First trial ends"])
        #expect(value("First trial ends", in: content) == AnalyticsText.day(today.adding(4).date))
    }

    @Test func aTrialThatEndedSaysItsPaymentShowsTheDayAfter() throws {
        let soFar = SubscriptionsSoFar(firstSale: today.adding(-7), trials: 1, people: 1, firstTrialEnds: today, today: today)
        let fact = try #require(AnalyticsEmptyContent.trialEndFact(soFar))
        #expect(fact.label == "First trial ended")
        #expect(fact.value == "\(AnalyticsText.day(today.date)) · a payment shows a day later")
    }

    @Test func tooFewSaysTheRuleAndKeepsTheCounts() throws {
        let soFar = SubscriptionsSoFar(firstSale: today.adding(-8), trials: 4, paidFromTrials: 1, paid: 1, hasPayments: true, people: 4, today: today)
        let content = try subscriptions(soFar)
        #expect(content.title == "Too few subscribers to show rates")
        #expect(content.text == """
        Parcel Pal has 4 subscribers so far. Apple leaves out rows with fewer than 5 people, so renewal and cancel rates show once there \
        are more. The counts below are complete.
        """)
        #expect(labels(content) == ["Trials", "Paid", "Trial → paid"])
        #expect(value("Trial → paid", in: content) == "1 of 4 · too few to tell")
        #expect(content.action == nil)
        #expect(content.note == nil)
    }

    @Test func oneSubscriberIsSingular() {
        #expect(AnalyticsEmptyContent.tooFewText(count: 1, appName: "Parcel Pal").hasPrefix("Parcel Pal has 1 subscriber so far."))
    }

    @Test func enoughSubscribersHaveNoEmptyState() {
        let soFar = SubscriptionsSoFar(firstSale: today.adding(-90), trials: 300, paid: 120, hasPayments: true, people: 330, today: today)
        #expect(AnalyticsEmptyContent.subscriptions(soFar, appName: "Lumen Journal") == nil)
        #expect(AnalyticsEmptyContent.stability(CrashesSoFar(), appName: "Lumen Journal") == nil)
    }

    // MARK: - Stability

    @Test func aVersionTooNewComparesWithTheOneBefore() throws {
        let soFar = CrashesSoFar(isReported: true, hasCrashRows: true, newest: "1.4", newestDevices: 2, previous: "1.3", previousRate: 2.1)
        let content = try stability(soFar)
        #expect(content.title == "1.4 is too new to tell")
        #expect(content.text == """
        Apple shows crashes for 1.4 once at least 5 people who share analytics with developers have used it, usually within a day or two.
        """)
        #expect(labels(content) == ["1.3", "1.4"])
        #expect(value("1.3", in: content) == "\(AnalyticsText.perThousand(2.1)) crashes per 1,000 sessions")
        #expect(value("1.4", in: content) == "Waiting for 5 people")
        #expect(content.note == "Atlas compares 1.4 with 1.3 as soon as the first numbers arrive.")
        #expect(content.action == .openVersion("1.4"))
        #expect(content.action?.title == "Open Version 1.4")
    }

    @Test func aVersionTooNewWithoutARateBeforeOnlyWaits() throws {
        let soFar = CrashesSoFar(isReported: true, newest: "1.4", previous: "1.3")
        #expect(try labels(stability(soFar)) == ["1.4"])
    }

    @Test func aNewAppSaysHowManyDownloadsSoFar() throws {
        let soFar = CrashesSoFar(isReported: true, newest: "1.0", isNewApp: true, downloads: 61, firstDay: today.adding(-8))
        let content = try stability(soFar)
        #expect(content.title == "Not enough people yet")
        #expect(content.text == """
        Apple counts crashes only from people who share analytics with developers, and shows a number once at least 5 of them have had \
        one. Parcel Pal has 61 downloads so far.
        """)
        #expect(labels(content) == ["Version", "Downloads"])
        #expect(value("Version", in: content) == "1.0 · live since \(AnalyticsText.day(today.adding(-8).date))")
        #expect(value("Downloads", in: content) == "61")
        #expect(content.note == "Crash logs with stack traces are in Xcode → Organizer.")
        #expect(content.action == nil)
    }

    @Test func aNewAppWithoutAVersionSaysSinceWhen() throws {
        let soFar = CrashesSoFar(isReported: true, isNewApp: true, downloads: 1, firstDay: today.adding(-2))
        let content = try stability(soFar)
        #expect(labels(content) == ["Live since", "Downloads"])
        #expect(content.text.hasSuffix("Parcel Pal has 1 download so far."))
    }

    @Test func noCrashesSaysWhyInAFullSentence() throws {
        let soFar = CrashesSoFar(isReported: true, newest: "1.4", newestDevices: 300, recentSessions: 8400)
        let content = try stability(soFar, appName: "Lumen Journal")
        #expect(content.title == "No crashes reported")
        #expect(content.text == """
        Fewer than 5 people who share analytics with developers had Lumen Journal crash, so Apple reports none. That usually means very \
        few crashes, or none.
        """)
        #expect(labels(content) == ["Version", "Sessions, 28 days"])
        #expect(value("Sessions, 28 days", in: content) == AnalyticsText.count(8400))
        #expect(content.action == nil)
    }

    // MARK: - Voice

    @Test func everyTextKeepsAtlassVoice() throws {
        let contents = try [
            subscriptions(SubscriptionsSoFar(today: today)),
            subscriptions(SubscriptionsSoFar(firstSale: today, trials: 2, people: 2, firstTrialEnds: today, today: today)),
            subscriptions(SubscriptionsSoFar(firstSale: today, trials: 4, paidFromTrials: 1, paid: 1, hasPayments: true, people: 4, today: today)),
            stability(CrashesSoFar(isReported: true, newest: "1.4", previous: "1.3", previousRate: 2.1)),
            stability(CrashesSoFar(isReported: true, newest: "1.0", isNewApp: true, downloads: 61, firstDay: today)),
            stability(CrashesSoFar(isReported: true, newest: "1.4", recentSessions: 10)),
        ]
        let banned = ["simply", "just ", "easily", "seamlessly", "powerful", "leverage", "magic", "please", "oops", "successfully", "!"]
        for content in contents {
            let words = ([content.title, content.text, content.note ?? "", content.action?.title ?? ""] + content.facts.flatMap { [$0.label, $0.value] })
                .joined(separator: " ")
                .lowercased()
            for word in banned {
                #expect(!words.contains(word), "“\(word)” in \(content.title)")
            }
            #expect((2...3).contains(content.facts.count), "2 or 3 facts in \(content.title)")
            #expect(content.title.split(separator: " ").count <= 8)
        }
    }
}
