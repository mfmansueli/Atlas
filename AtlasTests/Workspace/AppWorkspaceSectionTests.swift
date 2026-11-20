//
//  AppWorkspaceSectionTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The workspace's eight sections, in the sidebar's order: Overview, the
/// Store Listing's five, then Reviews and Analytics after release.
@Suite("AppWorkspaceSection")
struct AppWorkspaceSectionTests {
    @Test func theSectionsAreInTheSidebarsOrder() {
        #expect(AppWorkspaceSection.allCases == [
            .overview, .storePage, .screenshots, .productPages, .inAppEvents, .appInformation, .subscriptionPricing, .reviews, .analytics,
        ])
        #expect(AppWorkspaceSection.allCases.map(\.shortcutDigit) == ["1", "2", "3", "4", "5", "6", "7", "8", "9"])
    }

    @Test func theSidebarGroupsThemByWhatYouAreDoing() {
        #expect(AppWorkspaceSectionGroup.allCases.map(\.title) == [nil, "Store Listing", "After Release"])
        #expect(AppWorkspaceSectionGroup.overview.sections == [.overview])
        #expect(AppWorkspaceSectionGroup.storeListing.sections == [
            .storePage, .screenshots, .productPages, .inAppEvents, .appInformation, .subscriptionPricing,
        ])
        #expect(AppWorkspaceSectionGroup.afterRelease.sections == [.reviews, .analytics])
        // Every section is in exactly one group.
        #expect(AppWorkspaceSectionGroup.allCases.flatMap(\.sections) == AppWorkspaceSection.allCases)
    }

    @Test func pricingAndReviewsAreShortenedOnlyInTheSidebar() {
        #expect(AppWorkspaceSection.subscriptionPricing.title == "Pricing")
        #expect(AppWorkspaceSection.subscriptionPricing.fullTitle == "Subscription Pricing")
        #expect(AppWorkspaceSection.reviews.title == "Reviews")
        #expect(AppWorkspaceSection.reviews.fullTitle == "Ratings & Reviews")
    }

    @Test(arguments: [
        (AppWorkspaceSection.overview, "Overview"),
        (.storePage, "Store Page"),
        (.screenshots, "Screenshots"),
        (.productPages, "Custom Product Pages"),
        (.inAppEvents, "In-App Events"),
        (.appInformation, "App Information"),
        (.analytics, "Analytics"),
    ])
    func theOtherSectionsUseOneName(section: AppWorkspaceSection, title: String) {
        #expect(section.title == title)
        #expect(section.fullTitle == title)
    }

    @Test func everySectionHasItsOwnSymbol() {
        let symbols = AppWorkspaceSection.allCases.map(\.systemImage)
        #expect(Set(symbols).count == symbols.count)
        #expect(AppWorkspaceSection.screenshots.systemImage == "iphone")
        #expect(AppWorkspaceSection.inAppEvents.systemImage == "calendar")
    }

    @Test func theRawValuesStayAsTheyWereSaved() {
        // Pending changes and push history are saved with them.
        #expect(AppWorkspaceSection.subscriptionPricing.rawValue == "subscriptionPricing")
        #expect(AppWorkspaceSection(rawValue: "storePage") == .storePage)
        #expect(AppWorkspaceSection(rawValue: "appInformation") == .appInformation)
    }
}
