//
//  PriceTestChangesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// One Review & Push item starts a test and schedules its return; ending
/// it brings the old prices back, and End Test and Set keeps the new one.
@Suite("PriceTestChanges")
struct PriceTestChangesTests {
    private typealias Fixtures = PriceTestFixtures

    @Test func aLowerTestPriceAndItsReturnAreOneItem() throws {
        let test = Fixtures.test(state: .queued, startedOn: nil)
        let change = PriceTestChanges.start(test, appID: "app", source: .you, at: Fixtures.today)
        #expect(change.id == "pricetest.start.pt-1")
        #expect(PriceTestChanges.reading(change.id)?.kind == .start)
        #expect(change.blockedReason == nil)
        let bodies = try Fixtures.bodies(change.requests)
        #expect(bodies.count == 2)
        let into = Fixtures.attributes(bodies[0])
        let back = Fixtures.attributes(bodies[1])
        // Subscribers who renew pay the lower price…
        #expect(into["preserveCurrentPrice"] as? Bool == false)
        #expect(into["startDate"] == nil)
        // …and keep it after day 28, when the old price comes back.
        #expect(back["preserveCurrentPrice"] as? Bool == true)
        #expect(back["startDate"] as? String == PriceTestReturnDay.token)
        #expect(change.creation?.fields.count == 1)
    }

    @Test func aRaiseKeepsExistingSubscribersOnTheirPrice() throws {
        let test = Fixtures.test(state: .queued, startedOn: nil, countries: [Fixtures.germany(old: "39.99", test: "43.99")])
        let bodies = try Fixtures.bodies(PriceTestChanges.start(test, appID: "app", source: .you).requests)
        #expect(Fixtures.attributes(bodies[0])["preserveCurrentPrice"] as? Bool == true)
        #expect(Fixtures.attributes(bodies[1])["preserveCurrentPrice"] as? Bool == false)
    }

    @Test func aMissingPricePointBlocksThePush() {
        var germany = Fixtures.germany()
        germany.testPricePointID = nil
        let change = PriceTestChanges.start(Fixtures.test(state: .queued, startedOn: nil, countries: [germany]), appID: "app", source: .you)
        #expect(change.blockedReason != nil)
        #expect(change.requests.isEmpty)
    }

    @Test func theReturnDayIsFilledInAtPushTime() throws {
        let test = Fixtures.test(state: .queued, startedOn: nil)
        let change = PriceTestChanges.start(test, appID: "app", source: .you)
        let resolved = PriceTestReturnDay.resolving(change.requests[1], today: PricingSampleData.date("2026-11-25"))
        let body = try #require(try Fixtures.bodies([resolved]).first)
        #expect(Fixtures.attributes(body)["startDate"] as? String == "2026-12-23")
        #expect(PriceTestReturnDay.resolving(change.requests[0]) == change.requests[0])
    }

    @Test func endingEarlyBringsTheOldPricesBack() throws {
        let france = PriceTestCountry(
            territoryID: "FRA", currencyCode: "EUR", oldPrice: 39.99, testPrice: 31.99, oldPricePointID: "pp-old-FRA", testPricePointID: "pp-test-FRA"
        )
        let test = Fixtures.test(countries: [Fixtures.germany(), france])
        let change = PriceTestChanges.end(test, ending: PriceTestEnding(testID: test.id), pricePointID: nil, appID: "app")
        #expect(change.id == "pricetest.end.pt-1")
        let bodies = try Fixtures.bodies(change.requests)
        #expect(bodies.count == 2)
        #expect(bodies.allSatisfy { Fixtures.attributes($0)["preserveCurrentPrice"] as? Bool == true })
        #expect(bodies.allSatisfy { Fixtures.attributes($0)["startDate"] == nil })
    }

    @Test func endTestAndSetKeepsTheNewPriceAfterDay28() throws {
        let france = PriceTestCountry(
            territoryID: "FRA", currencyCode: "EUR", oldPrice: 39.99, testPrice: 31.99, oldPricePointID: "pp-old-FRA", testPricePointID: "pp-test-FRA"
        )
        let test = Fixtures.test(countries: [Fixtures.germany(), france])
        let ending = PriceTestEnding(testID: test.id, territoryID: "DEU", price: 34.99)
        #expect(ending.setsPrice)
        let change = PriceTestChanges.end(test, ending: ending, pricePointID: "pp-new-DEU", appID: "app")
        #expect(change.blockedReason == nil)
        let bodies = try Fixtures.bodies(change.requests)
        // France back to its old price; Germany's new price now and on the return day.
        #expect(bodies.count == 3)
        let germany = bodies.filter { ($0["relationships"] as? [String: Any]).map { "\($0)" }?.contains("DEU") == true }
        #expect(germany.count == 2)
        #expect(germany.contains { Fixtures.attributes($0)["startDate"] as? String == test.returnDay })
        #expect(change.creation?.fields.first?.title == "Germany")
    }

    @Test func endTestAndSetWithoutApplesPointIsBlocked() {
        let test = Fixtures.test()
        let ending = PriceTestEnding(testID: test.id, territoryID: "DEU", price: 34.99)
        #expect(PriceTestChanges.end(test, ending: ending, pricePointID: nil, appID: "app").blockedReason != nil)
    }
}
