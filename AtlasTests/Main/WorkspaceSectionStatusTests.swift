//
//  WorkspaceSectionStatusTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// The line under the section's title in the toolbar.
@Suite("WorkspaceSectionStatus")
struct WorkspaceSectionStatusTests {
    @Test func whatWaitsThenWhatIsntPushed() {
        let status = WorkspaceSectionStatus(section: .storePage, waiting: 32, notPushed: 3)
        #expect(status.leadingText == "32 suggestions")
        #expect(status.notPushedText == "3 not pushed")
        #expect(status.text == "32 suggestions · 3 not pushed")
    }

    @Test func eachSectionNamesWhatWaitsInIt() {
        #expect(WorkspaceSectionStatus(section: .screenshots, waiting: 12).waitingText == "12 captions suggested")
        #expect(WorkspaceSectionStatus(section: .reviews, waiting: 1).waitingText == "1 reply suggested")
        #expect(WorkspaceSectionStatus(section: .analytics, waiting: 2).waitingText == "2 new findings")
        #expect(WorkspaceSectionStatus(section: .productPages, waiting: 2).waitingText == "2 pages suggested")
        #expect(WorkspaceSectionStatus(section: .appInformation, waiting: 1).waitingText == "1 suggestion")
    }

    @Test func overviewLeadsWithTheAppAndItsVersion() {
        let status = WorkspaceSectionStatus(section: .overview, waiting: 0, notPushed: 46, lead: "Lumen Journal · Version 1.4")
        #expect(status.leadingText == "Lumen Journal · Version 1.4")
        #expect(status.text == "Lumen Journal · Version 1.4 · 46 not pushed")
    }

    @Test func onlyNotPushedHasNoLead() {
        let status = WorkspaceSectionStatus(section: .subscriptionPricing, notPushed: 2)
        #expect(status.leadingText == nil)
        #expect(status.text == "2 not pushed")
    }

    @Test func nothingWaitingSaysSo() {
        let status = WorkspaceSectionStatus(section: .storePage)
        #expect(status.leadingText == nil)
        #expect(status.notPushedText == nil)
        #expect(status.text == "Nothing waiting")
    }
}
