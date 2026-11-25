//
//  WorkspacePageActionTests.swift
//  AtlasTests
//

import Testing
@testable import Atlas

/// Board 80's page action at the top: one create button per section in
/// the toolbar, from one source (`AppWorkspaceSection.pageAction`), how
/// the sections report it, and what running it asks of the section.
@MainActor
@Suite("Workspace page action")
struct WorkspacePageActionTests {
    @Test func fiveSectionsCreateSomething() {
        let sections = AppWorkspaceSection.allCases.filter { $0.pageAction != nil }
        #expect(sections == [.screenshots, .productPages, .inAppEvents, .nominations, .subscriptionPricing])
    }

    @Test(arguments: [AppWorkspaceSection.overview, .storePage, .appInformation, .reviews, .analytics])
    func titleOnlySectionsHaveNone(_ section: AppWorkspaceSection) {
        #expect(section.pageAction == nil)
        #expect(WorkspaceNavigator(section: section).pageActionState(for: section) == nil)
    }

    @Test(arguments: [AppWorkspaceSection.screenshots, .productPages, .inAppEvents, .nominations, .subscriptionPricing])
    func eachOpensASheetSoItsTitleEndsWithAnEllipsis(_ section: AppWorkspaceSection) throws {
        let action = try #require(section.pageAction)
        #expect(action.title.hasSuffix("…"))
        #expect(action.section == section)
        #expect(action.systemImage == "plus")
        #expect(!action.help.isEmpty)
        #expect(!action.help.hasSuffix("…"))
    }

    @Test func theTitlesAreTheBoards() {
        #expect(AppWorkspaceSection.productPages.pageAction?.title == "New Page…")
        #expect(AppWorkspaceSection.inAppEvents.pageAction?.title == "New Event…")
        #expect(AppWorkspaceSection.nominations.pageAction?.title == "New Nomination…")
        #expect(AppWorkspaceSection.subscriptionPricing.pageAction?.title == "Add Subscription…")
        #expect(AppWorkspaceSection.screenshots.pageAction?.title == "Add Screenshots…")
    }

    /// The identifiers the pages' own buttons had, which the UI tests use.
    @Test func identifiersAreThePagesOldOnesAndUnique() {
        let identifiers = AppWorkspaceSection.allCases.compactMap { $0.pageAction?.identifier }
        #expect(identifiers == ["screenshots.add", "pages.new", "events.new", "nominations.new", "pricing.addSubscription"])
        #expect(Set(identifiers).count == identifiers.count)
    }

    @Test func itTakesRoomOfItsOwnAndNeverFolds() {
        #expect(ToolbarRoomItem.pageAction.isItem)
        #expect(!ToolbarRoomItem.pageAction.isLabel)
        #expect(!ToolbarRoomItem.pageAction.isLead)
    }

    // MARK: - What the sections report

    @Test func aSectionThatHasntReportedHasItOn() {
        let navigator = WorkspaceNavigator(section: .productPages)
        #expect(navigator.pageActionState(for: .productPages) == .enabled)
    }

    @Test func reportsAreKeptPerSectionUntilForgotten() {
        let navigator = WorkspaceNavigator(section: .productPages)
        navigator.setPageActionState(.hidden, for: .productPages)
        navigator.setPageActionState(.disabled(reason: "No"), for: .nominations)
        #expect(navigator.pageActionState(for: .productPages) == .hidden)
        #expect(navigator.pageActionState(for: .nominations) == .disabled(reason: "No"))
        #expect(navigator.pageActionState(for: .inAppEvents) == .enabled)
        navigator.setPageActionState(nil, for: .productPages)
        #expect(navigator.pageActionState(for: .productPages) == .enabled)
    }

    @Test func theStateSaysWhetherItShowsAndRuns() {
        #expect(WorkspacePageActionState.enabled.isShown)
        #expect(WorkspacePageActionState.enabled.isEnabled)
        #expect(WorkspacePageActionState.disabled(reason: nil).isShown)
        #expect(!WorkspacePageActionState.disabled(reason: nil).isEnabled)
        #expect(WorkspacePageActionState.disabled(reason: "Full").reason == "Full")
        #expect(!WorkspacePageActionState.hidden.isShown)
        #expect(WorkspacePageActionState.hidden.reason == nil)
    }

    // MARK: - Running it

    @Test func runningAsksTheSectionForItsSheet() {
        let navigator = WorkspaceNavigator(section: .inAppEvents)
        navigator.runPageAction(appID: DebugFixtures.AppID.lumen)
        #expect(navigator.section == .inAppEvents)
        #expect(navigator.intent == .pageAction)
        #expect(navigator.requestedAppID == DebugFixtures.AppID.lumen)
    }

    @Test(arguments: [WorkspacePageActionState.disabled(reason: nil), .hidden])
    func offOrGoneItDoesNothing(_ state: WorkspacePageActionState) {
        let navigator = WorkspaceNavigator(section: .productPages)
        navigator.setPageActionState(state, for: .productPages)
        navigator.runPageAction()
        #expect(navigator.intent == nil)
    }

    @Test func aTitleOnlySectionHasNothingToRun() {
        let navigator = WorkspaceNavigator(section: .storePage)
        navigator.runPageAction()
        #expect(navigator.intent == nil)
    }
}
