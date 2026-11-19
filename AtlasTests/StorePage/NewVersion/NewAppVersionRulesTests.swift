//
//  NewAppVersionRulesTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What App Store Connect allows when creating a version: a well-formed
/// number higher than the platform's latest, and no other version in
/// progress on that platform.
@Suite("New app version rules")
struct NewAppVersionRulesTests {
    private static func version(_ number: String, _ state: ListingVersionState, platform: String = "IOS") -> StorePageVersion {
        StorePageVersion(id: "\(platform)-\(number)", listingVersion: ListingVersion(number, state: state), platform: platform)
    }

    private let liveOnly = [version("1.9", .readyForDistribution)]
    private let iOSAndMac = [
        version("2.0", .prepareForSubmission),
        version("1.9", .readyForDistribution),
        version("1.2", .readyForDistribution, platform: "MAC_OS"),
    ]

    @Test func theNextNumberIsTheLastPlusOne() {
        #expect(NewAppVersion.next(after: "1.3") == "1.4")
        #expect(NewAppVersion.next(after: "2.0.9") == "2.0.10")
        #expect(NewAppVersion.next(after: "1") == "2")
        #expect(NewAppVersionRules.suggestedNumber(on: "IOS", in: liveOnly) == "1.10")
        #expect(NewAppVersionRules.suggestedNumber(on: "TV_OS", in: liveOnly) == "1.0")
    }

    @Test(arguments: ["1", "1.4", "2.0.1", "10.12.300"])
    func wellFormedNumbers(_ number: String) {
        #expect(NewAppVersion.isWellFormed(number))
    }

    @Test(arguments: ["", "1.", ".1", "1.2.3.4", "1.4 beta", "v1.4", "1..4", "١.٤"])
    func malformedNumbers(_ number: String) {
        #expect(!NewAppVersion.isWellFormed(number))
    }

    @Test func numbersCompareNumberByNumber() {
        #expect(NewAppVersion.isHigher("1.10", than: "1.9"))
        #expect(NewAppVersion.isHigher("2", than: "1.9.9"))
        #expect(!NewAppVersion.isHigher("2.0", than: "2"))
        #expect(!NewAppVersion.isHigher("1.9", than: "1.10"))
    }

    @Test func platformsComeIOSFirst() {
        let macFirst = [Self.version("1.2", .readyForDistribution, platform: "MAC_OS"), Self.version("1.9", .readyForDistribution)]
        #expect(NewAppVersionRules.platforms(in: macFirst) == ["IOS", "MAC_OS"])
        #expect(NewAppVersionRules.latest(on: "MAC_OS", in: iOSAndMac)?.versionString == "1.2")
    }

    @Test func aVersionHigherThanTheLiveOneCanBeCreated() {
        #expect(NewAppVersionRules.problem(for: NewAppVersion(versionString: "1.10", platform: "IOS"), in: liveOnly) == nil)
        #expect(NewAppVersionRules.canCreate(in: liveOnly))
    }

    @Test func whatAppStoreConnectWouldRefuse() {
        let problem = { (number: String, platform: String) in
            NewAppVersionRules.problem(for: NewAppVersion(versionString: number, platform: platform), in: iOSAndMac)
        }
        #expect(problem("1.3 beta", "MAC_OS") == .malformed)
        #expect(problem("1.0", "TV_OS") == .unknownPlatform("tvOS"))
        #expect(problem("2.1", "IOS") == .inProgress(versionString: "2.0", state: .prepareForSubmission))
        #expect(problem("1.2", "MAC_OS") == .notHigher(latest: "1.2"))
        #expect(problem("1.1", "MAC_OS") == .notHigher(latest: "1.2"))
        #expect(problem("1.3", "MAC_OS") == nil)
        #expect(NewAppVersionRules.defaultPlatform(in: iOSAndMac) == "MAC_OS")
    }

    @Test func aVersionInReviewBlocksANewOneUntilReleased() {
        let inReview = [Self.version("2.0", .waitingForReview), Self.version("1.9", .readyForDistribution)]
        let problem = NewAppVersionRules.problem(for: NewAppVersion(versionString: "2.1", platform: "IOS"), in: inReview)
        #expect(problem == .inProgress(versionString: "2.0", state: .waitingForReview))
        #expect(problem?.message == "Version 2.0 is Waiting for Review. A new version can be created once it’s released.")
        #expect(!NewAppVersionRules.canCreate(in: inReview))
    }

    @Test func theNumberIsTrimmed() {
        #expect(NewAppVersion(versionString: " 1.10\n", platform: "IOS").versionString == "1.10")
    }
}
