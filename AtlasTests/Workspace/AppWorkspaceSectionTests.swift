//
//  AppWorkspaceSectionTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The workspace's ten sections, in the sidebar's order: Overview, the
/// Store Listing's seven, then Reviews and Analytics after release.
@Suite("AppWorkspaceSection")
struct AppWorkspaceSectionTests {
    @Test func theSectionsAreInTheSidebarsOrder() {
        #expect(AppWorkspaceSection.allCases == [
            .overview, .storePage, .screenshots, .productPages, .inAppEvents, .nominations, .appInformation, .subscriptionPricing, .reviews, .analytics,
        ])
        #expect(AppWorkspaceSection.allCases.map(\.shortcutDigit) == ["1", "2", "3", "4", "5", "F", "6", "7", "8", "9"])
        // ⌘F is Find, so Nominations is ⇧⌘F.
        #expect(AppWorkspaceSection.nominations.shortcutText == "⇧⌘F")
        #expect(AppWorkspaceSection.inAppEvents.shortcutText == "⌘5")
    }

    @Test func theSidebarGroupsThemByWhatYouAreDoing() {
        #expect(AppWorkspaceSectionGroup.allCases.map(\.title) == [nil, "Store Listing", "After Release"])
        #expect(AppWorkspaceSectionGroup.overview.sections == [.overview])
        #expect(AppWorkspaceSectionGroup.storeListing.sections == [
            .storePage, .screenshots, .productPages, .inAppEvents, .nominations, .appInformation, .subscriptionPricing,
        ])
        #expect(AppWorkspaceSectionGroup.afterRelease.sections == [.reviews, .analytics])
        // Every section is in exactly one group.
        #expect(AppWorkspaceSectionGroup.allCases.flatMap(\.sections) == AppWorkspaceSection.allCases)
    }

    @Test func pricingReviewsAndPagesAreShortenedOnlyInTheSidebar() {
        #expect(AppWorkspaceSection.subscriptionPricing.title == "Pricing")
        #expect(AppWorkspaceSection.subscriptionPricing.fullTitle == "Subscription Pricing")
        #expect(AppWorkspaceSection.reviews.title == "Reviews")
        #expect(AppWorkspaceSection.reviews.fullTitle == "Ratings & Reviews")
        // Canvas 24 Nov: "Custom Product Pages" in the sidebar and toolbar too.
        #expect(AppWorkspaceSection.productPages.title == "Custom Product Pages")
        #expect(AppWorkspaceSection.productPages.fullTitle == "Custom Product Pages")
    }

    /// The toolbar names the section as the design does.
    @Test func theToolbarUsesTheDesignsNames() {
        #expect(AppWorkspaceSection.subscriptionPricing.toolbarTitle == "Pricing")
        #expect(AppWorkspaceSection.productPages.toolbarTitle == "Custom Product Pages")
        #expect(AppWorkspaceSection.reviews.toolbarTitle == "Ratings & Reviews")
        #expect(AppWorkspaceSection.storePage.toolbarTitle == "Store Page")
    }

    @Test(arguments: [
        (AppWorkspaceSection.overview, "Overview"),
        (.storePage, "Store Page"),
        (.screenshots, "Screenshots"),
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
        // Board 72: outline symbols; Custom Product Pages is a stack.
        #expect(AppWorkspaceSection.productPages.systemImage == "rectangle.stack")
        #expect(AppWorkspaceSection.storePage.systemImage == "doc.text")
    }

    /// README-DS §13: a system colour per section, Nominations brown; the
    /// two neutral places gray.
    @Test(arguments: [
        (AppWorkspaceSection.overview, SymbolTint.systemGray), (.storePage, .systemBlue), (.screenshots, .systemOrange),
        (.productPages, .systemTeal), (.inAppEvents, .systemPink), (.nominations, .systemBrown), (.appInformation, .systemGray),
        (.subscriptionPricing, .systemGreen), (.reviews, .systemYellow), (.analytics, .systemIndigo),
    ])
    func eachSectionHasItsSystemColour(section: AppWorkspaceSection, tint: SymbolTint) {
        #expect(section.style.tint == tint)
    }

    @Test func theRawValuesStayAsTheyWereSaved() {
        // Pending changes and push history are saved with them.
        #expect(AppWorkspaceSection.subscriptionPricing.rawValue == "subscriptionPricing")
        #expect(AppWorkspaceSection(rawValue: "storePage") == .storePage)
        #expect(AppWorkspaceSection(rawValue: "appInformation") == .appInformation)
    }
}
