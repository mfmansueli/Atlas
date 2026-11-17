//
//  ComplianceChangeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// App Compliance's one write: taking the app off sale in a country.
@Suite("AppInformationChangeBuilder compliance")
struct ComplianceChangeTests {
    private typealias Support = AppInformationTestSupport
    private let builder = AppInformationTestSupport.builder
    private let china = ComplianceTerritory(id: "eyJzIjoiNjQ1MCIsInQiOiJDSE4ifQ", territoryID: "CHN", isAvailable: true, statuses: ["ICP_NUMBER_MISSING"])

    @Test func stoppingSalesPatchesTheCountrysAvailability() throws {
        let change = try #require(builder.stopSellingChange(china))
        #expect(change.id == "appInformation.\(Support.appID).appCompliance.availability.CHN")
        #expect(change.section == .appInformation)
        #expect(change.group == "App Information · App Compliance")
        #expect(change.title == "Availability · China mainland")
        #expect(change.flagRegion == "CN")
        #expect(change.oldValue == "Available")
        #expect(change.newValue == "Not available")
        #expect(builder.page(of: change) == .appCompliance)

        let request = try #require(change.requests.first)
        #expect(change.requests.count == 1)
        #expect(request.method == .patch)
        #expect(request.path == "/v1/territoryAvailabilities/eyJzIjoiNjQ1MCIsInQiOiJDSE4ifQ")
        let data = Support.json(request)["data"] as? [String: Any]
        #expect(data?["type"] as? String == "territoryAvailabilities")
        #expect(data?["id"] as? String == "eyJzIjoiNjQ1MCIsInQiOiJDSE4ifQ")
        #expect(Support.attributes(request)["available"] as? Bool == false)
    }

    @Test func restoringMakesItAvailableAgain() throws {
        let change = try #require(builder.stopSellingChange(china))
        let restore = try #require(change.restoring())
        #expect(restore.newValue == "Available")
        #expect(Support.attributes(restore.requests.first)["available"] as? Bool == true)
        #expect(restore.requests.first?.path == change.requests.first?.path)
    }

    @Test func aCountryTheAppIsNotSoldInHasNothingToStop() {
        var notSold = china
        notSold.isAvailable = false
        #expect(builder.stopSellingChange(notSold) == nil)

        var leaving = china
        leaving.statuses.insert(ComplianceTerritory.leavingStatus)
        #expect(builder.stopSellingChange(leaving) == nil)
    }

    @Test func aTerritoryTheCatalogDoesNotKnowKeepsItsID() throws {
        let unknown = ComplianceTerritory(id: "availability-ZZZ", territoryID: "ZZZ", isAvailable: true)
        let change = try #require(builder.stopSellingChange(unknown))
        #expect(change.title == "Availability · ZZZ")
        #expect(change.flagRegion == nil)
    }

    @Test func theQueueSaysWhetherSalesStop() throws {
        let change = try #require(builder.stopSellingChange(china))
        #expect(builder.stopsSelling(in: "CHN", with: [change]))
        #expect(!builder.stopsSelling(in: "VNM", with: [change]))
        #expect(!builder.stopsSelling(in: "CHN", with: []))
    }
}
