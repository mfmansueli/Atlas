//
//  WhereShownTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Each Store Page field and App Information page says where it shows on
/// the App Store, or that it doesn't.
@Suite("Where it shows")
struct WhereShownTests {
    @Test func storePageFields() {
        #expect(ListingField.subtitle.whereShown(version: "1.4") == "Under the name, also in search")
        #expect(ListingField.keywords.whereShown(version: "1.4") == "Hidden. Only App Store search reads them")
        #expect(ListingField.whatsNew.whereShown(version: "1.4") == "Under “What’s New”, for version 1.4")
        #expect(ListingField.whatsNew.whereShown(version: nil) == "Under “What’s New”")
        #expect(ListingField.whatsNew.whereShown(version: "") == "Under “What’s New”")
    }

    @Test func appInformationPages() {
        #expect(AppInformationPage.appReview.whereShown(appName: "Lumen") == "Not on the App Store. Only App Review reads it.")
        #expect(AppInformationPage.accessibility.whereShown(appName: "Lumen") == "On the App Store: the Accessibility section lists what Lumen supports.")
        #expect(AppInformationPage.ageRating.whereShown(appName: "Lumen") == "On the App Store: the age under the name, such as 4+.")
    }

    /// "Not on the App Store." read as the app's state for a first version
    /// in Prepare for Submission: the version's state is said instead.
    @Test func exportComplianceSaysWhetherTheVersionIsOnTheAppStore() {
        let first = StorePageVersion(id: "v", listingVersion: ListingVersion("1.0", state: .prepareForSubmission, isFirstVersion: true))
        #expect(AppInformationPage.exportCompliance.whereShown(appName: "Lumen", version: first)
            == "Version 1.0 isn’t on the App Store yet. These answers never show there.")
        let inReview = StorePageVersion(id: "v", listingVersion: ListingVersion("1.1", state: .waitingForReview))
        #expect(AppInformationPage.exportCompliance.whereShown(appName: "Lumen", version: inReview).hasPrefix("Version 1.1 isn’t on the App Store yet."))
        let live = StorePageVersion(id: "v", listingVersion: ListingVersion("1.3", state: .readyForDistribution))
        let never = "Never shown on the App Store: App Store Connect asks it per build."
        #expect(AppInformationPage.exportCompliance.whereShown(appName: "Lumen", version: live) == never)
        #expect(AppInformationPage.exportCompliance.whereShown(appName: "Lumen") == never)
        // Other pages don't depend on the version.
        #expect(AppInformationPage.appReview.whereShown(appName: "Lumen", version: first) == "Not on the App Store. Only App Review reads it.")
    }
}
