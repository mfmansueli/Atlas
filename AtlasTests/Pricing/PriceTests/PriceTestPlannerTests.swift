//
//  PriceTestPlannerTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The sheet's plan: test prices on Apple's points, the sample first,
/// the comparison, and the refusals.
@Suite("PriceTestPlanner")
struct PriceTestPlannerTests {
    private typealias Fixtures = PriceTestFixtures

    private func planner(_ candidates: [PriceTestCandidate], tests: [PriceTest] = []) -> PriceTestPlanner {
        PriceTestPlanner(productID: "annual", productName: "Lumen Plus Annual", candidates: candidates, tests: tests, today: Fixtures.today)
    }

    private func world() throws -> [PriceTestCandidate] {
        try [
            Fixtures.candidate("DEU", suggested: "34.00", recent: Fixtures.signal(1200, 60)),
            Fixtures.candidate("FRA", recent: Fixtures.signal(940, 36)),
            Fixtures.candidate("JPN", suggested: "30.00", recent: Fixtures.signal(2200, 88)),
            Fixtures.candidate("ZAF", recent: Fixtures.signal(400, 12)),
        ]
    }

    @Test func twentyPercentLowerRoundsToApplesPoints() throws {
        let plan = try #require(planner(world()).plan(PriceTestSetup(productID: "annual", region: .europe, step: .percent(-20))))
        #expect(plan.countries.map(\.territoryID) == ["DEU", "FRA"])
        #expect(plan.countries.allSatisfy { $0.testPrice == 32 && $0.oldPrice == 40 })
        #expect(plan.sample == Fixtures.signal(2140, 96))
        #expect(plan.refusal == nil)
        #expect(plan.canContinue)
    }

    @Test func suggestedCountsOnlyTheCountriesThatMove() throws {
        let plan = try #require(planner(world()).plan(PriceTestSetup(productID: "annual", region: .europe, step: .suggested)))
        #expect(plan.countries.map(\.territoryID) == ["DEU"])
        #expect(plan.sample == Fixtures.signal(1200, 60))
    }

    @Test func tooFewPeopleDisablesContinue() throws {
        let plan = try #require(planner(world()).plan(PriceTestSetup(productID: "annual", region: .africaMiddleEast, step: .percent(-20))))
        #expect(plan.refusal?.hasPrefix("Too few people to tell") == true)
        #expect(!plan.canContinue)
    }

    @Test func aRegionInATestIsRefused() throws {
        let running = Fixtures.test(region: .europe)
        let plan = try #require(planner(world(), tests: [running]).plan(PriceTestSetup(productID: "annual", region: .europe)))
        #expect(plan.refusal == "Europe is already in the Lumen Plus Annual price test. One test per region at a time.")
        #expect(!plan.canContinue)
    }

    @Test func automaticComparesWithEnoughStartsAndNoComparisonIsNil() throws {
        let planner = try planner(world())
        #expect(planner.plan(PriceTestSetup(productID: "annual", region: .europe))?.control == .asiaPacific)
        #expect(planner.plan(PriceTestSetup(productID: "annual", region: .europe, control: .none))?.control == nil)
        // Too few starts there: Automatic instead.
        let chosen = planner.plan(PriceTestSetup(productID: "annual", region: .europe, control: .region(.africaMiddleEast)))
        #expect(chosen?.control == .asiaPacific)
    }

    @Test func aRaiseNeverKeepsTheTestPrice() throws {
        let plan = try #require(planner(world()).plan(PriceTestSetup(productID: "annual", region: .europe, step: .percent(10))))
        #expect(plan.hasRaises)
        #expect(plan.test(id: "pt", createdAt: Fixtures.today, suggestedBy: nil).keepsTestPrice == false)
    }

    @Test func roundingNeverFlipsTheDirection() throws {
        let tiny = try Fixtures.candidate("DEU", price: "20.00", recent: Fixtures.signal(1200, 60))
        // −10% of €20 is €18, under the ladder's lowest point: nothing changes.
        #expect(planner([tiny]).testPrice(for: tiny, step: .percent(-10)) == nil)
    }

    @Test(arguments: [
        (PriceTestStep.percent(-30), PriceTestStep.percent(-20)),
        (.percent(-20), .percent(-10)),
        (.percent(20), .percent(10)),
        (.percent(-10), .percent(-10)),
        (.suggested, .percent(-10)),
    ])
    func againTriesASmallerStep(step: PriceTestStep, smaller: PriceTestStep) {
        #expect(step.smaller == smaller)
    }

    @Test func stepsReadFromTheAssistant() {
        #expect(PriceTestStep(argument: "-20") == .percent(-20))
        #expect(PriceTestStep(argument: "+10%") == .percent(10))
        #expect(PriceTestStep(argument: "Suggested") == .suggested)
        #expect(PriceTestStep(argument: "-15") == nil)
    }
}
