//
//  ReviewRiskEULAReaderTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Whether the app has its own license agreement in App Store Connect.
@Suite("Review risks · License agreement")
struct ReviewRiskEULAReaderTests {
    @Test func anAgreementWithTextIsCustom() {
        let body = #"{"data":{"type":"endUserLicenseAgreements","id":"e1","attributes":{"agreementText":"Lumen's terms"}}}"#
        #expect(ReviewRiskEULAReader.hasAgreement(in: Data(body.utf8)) == true)
    }

    @Test func noAgreementMeansApplesStandardOne() {
        #expect(ReviewRiskEULAReader.hasAgreement(in: Data(#"{"data":null}"#.utf8)) == false)
    }

    @Test func aBodyThatIsntAppStoreConnectsIsUnknown() {
        #expect(ReviewRiskEULAReader.hasAgreement(in: Data("{}".utf8)) == nil)
        #expect(ReviewRiskEULAReader.hasAgreement(in: Data("not json".utf8)) == nil)
    }

    @Test func itReadsTheAppsAgreement() async {
        let path = ReviewRiskEULAReader.path(appID: "42")
        #expect(path.hasPrefix("/v1/apps/42/endUserLicenseAgreement"))
        let body = #"{"data":{"type":"endUserLicenseAgreements","id":"e1","attributes":{"agreementText":"Terms"}}}"#
        let transport = FakePushTransport(remote: [path: Data(body.utf8)])
        #expect(await ReviewRiskEULAReader(transport: transport).hasCustomEULA(appID: "42") == true)
    }
}
