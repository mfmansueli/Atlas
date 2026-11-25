//
//  WorkspaceSectionStatusTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The line under the section's title in the toolbar (README — toolbar,
/// "Section by section").
@Suite("WorkspaceSectionStatus")
struct WorkspaceSectionStatusTests {
    @Test func storePageSaysHowManyLanguagesThenWhatIsntPushed() {
        let status = WorkspaceSectionStatus(section: .storePage, waiting: 32, notPushed: 3, facts: .init(languages: 6))
        #expect(status.leadingText == "32 suggestions in 6 languages")
        #expect(status.notPushedText == "3 not pushed")
        #expect(status.text == "32 suggestions in 6 languages · 3 not pushed")
        #expect(WorkspaceSectionStatus(section: .storePage, waiting: 1, facts: .init(languages: 1)).stateText == "1 suggestion in 1 language")
    }

    @Test func eachSectionNamesWhatWaitsInIt() {
        #expect(WorkspaceSectionStatus(section: .screenshots, waiting: 12).stateText == "12 captions suggested")
        #expect(WorkspaceSectionStatus(section: .appInformation, waiting: 7).stateText == "7 answers suggested")
        #expect(WorkspaceSectionStatus(section: .appInformation, waiting: 1).stateText == "1 answer suggested")
        #expect(WorkspaceSectionStatus(section: .subscriptionPricing, waiting: 3, notPushed: 2).text == "3 suggestions · 2 not pushed")
        #expect(WorkspaceSectionStatus(section: .nominations, waiting: 2).stateText == "2 suggestions")
    }

    @Test func nothingWaitingSaysWhatIsReviewed() {
        #expect(WorkspaceSectionStatus(section: .storePage).stateText == "Every language reviewed")
        #expect(WorkspaceSectionStatus(section: .screenshots).stateText == "Every caption reviewed")
        #expect(WorkspaceSectionStatus(section: .appInformation).stateText == "Every page reviewed")
        #expect(WorkspaceSectionStatus(section: .subscriptionPricing, notPushed: 2).text == "Every price reviewed · 2 not pushed")
        #expect(WorkspaceSectionStatus(section: .nominations).stateText == nil)
    }

    @Test func productPagesCountPagesAndIdeas() {
        #expect(WorkspaceSectionStatus(section: .productPages, waiting: 2, facts: .init(pages: 3)).stateText == "3 pages · 2 ideas")
        #expect(WorkspaceSectionStatus(section: .productPages, waiting: 1, facts: .init(pages: 1)).stateText == "1 page · 1 idea")
        #expect(WorkspaceSectionStatus(section: .productPages, facts: .init(pages: 0)).stateText == "No pages yet")
        // Before the section read its pages, only the ideas.
        #expect(WorkspaceSectionStatus(section: .productPages, waiting: 2).stateText == "2 ideas")
    }

    @Test func eventsCountEventsAndTheOnesWithoutArtwork() {
        let status = WorkspaceSectionStatus(section: .inAppEvents, facts: .init(events: 3, eventsNeedingArtwork: 1))
        #expect(status.stateText == "3 events · 1 needs artwork")
        #expect(WorkspaceSectionStatus(section: .inAppEvents, waiting: 2, facts: .init(events: 1, eventsNeedingArtwork: 2)).stateText
            == "1 event · 2 need artwork · 2 languages suggested")
        #expect(WorkspaceSectionStatus(section: .inAppEvents, facts: .init(events: 0)).stateText == "No events yet")
    }

    @Test func reviewsLeadWithTheRating() {
        let status = WorkspaceSectionStatus(section: .reviews, note: "auto-reply on", facts: .init(rating: 4.66, withoutReply: 4))
        #expect(status.leadingText == "4.7 ★ · 4 reviews without a reply · auto-reply on")
        #expect(WorkspaceSectionStatus(section: .reviews, facts: .init(withoutReply: 1)).stateText == "1 review without a reply")
        #expect(WorkspaceSectionStatus(section: .reviews, facts: .init(withoutReply: 0)).stateText == "No review waits for a reply")
        #expect(WorkspaceSectionStatus(section: .reviews).stateText == nil)
    }

    @Test func analyticsSaysItsPeriodAndNewFindings() {
        #expect(WorkspaceSectionStatus(section: .analytics, waiting: 2, facts: .init(days: 28)).stateText == "Last 28 days · 2 new findings")
        #expect(WorkspaceSectionStatus(section: .analytics, waiting: 1).stateText == "1 new finding")
    }

    @Test func overviewLeadsWithTheAppAndItsVersionOnly() {
        let status = WorkspaceSectionStatus(section: .overview, waiting: 12, notPushed: 46, lead: "Lumen Journal · Version 1.4")
        #expect(status.leadingText == "Lumen Journal · Version 1.4")
        #expect(status.text == "Lumen Journal · Version 1.4 · 46 not pushed")
    }

    @Test func nothingToSaySaysSo() {
        let status = WorkspaceSectionStatus(section: .overview)
        #expect(status.leadingText == nil)
        #expect(status.notPushedText == nil)
        #expect(status.text == "Nothing waiting")
    }

    @Test func draftsWithoutAnImageNeedArtwork() {
        let draft = InAppEvent(id: "1", referenceName: "Winter", state: .draft)
        let rejected = InAppEvent(id: "2", referenceName: "Spring", state: .rejected)
        let live = InAppEvent(id: "3", referenceName: "Summer", state: .live)
        #expect(WorkspaceSectionStatus.Facts.eventsNeedingArtwork([draft, rejected, live]) == 2)
        #expect(!WorkspaceSectionStatus.Facts.waitsForArtwork(live))
    }
}
