//
//  InAppEventDetailsViewModelTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The event page's details and "Before App Review": editing an existing
/// event's deep link, purpose, priority and primary language (each a
/// change in Review & Push, undone like a text), accepting an assistant's,
/// and what the footer and Submit Event… say when the app doesn't open
/// the deep link.
@MainActor
@Suite("InAppEventsViewModel · details")
struct InAppEventDetailsViewModelTests {
    typealias Data = InAppEventsTestData

    private let queue = ChangeQueue()
    private let store = InAppEventsStore()
    private let claims = ProjectLinkClaimsCenter()

    /// Winter with every language written, so only its details are left.
    private static var ready: InAppEvent {
        var event = Data.winter
        event.localizations.removeLast()
        return event
    }

    private func makeModel(_ events: [InAppEvent] = [ready]) async -> InAppEventsViewModel {
        let model = InAppEventsViewModel(app: Data.app, services: FakeInAppEventsServices(events), store: store, queue: queue)
        model.now = { Data.now }
        model.pageLocales = ["en-US"]
        model.linkClaims = claims
        await model.load()
        return model
    }

    private static func report(_ link: String, opens: Bool = true) -> InAppEventDeepLinkReport {
        InAppEventDeepLinkReport(
            eventID: "winter", deepLink: link, opens: opens, shows: "The Winter challenge", beforeStart: "Starts Dec 1",
            needsPremium: false, location: "Lumen/LumenApp.swift:40", build: "1.4 (212)", testedInSimulator: true, problems: [],
            client: "Claude Code", date: Data.now
        )
    }

    @Test func aDraftWithoutADeepLinkCantBeSubmittedUntilOneIsSet() async throws {
        var event = Self.ready
        event.deepLink = nil
        let model = await makeModel([event])
        #expect(model.reviewItems(of: event).map(\.id) == ["deepLink"])
        #expect(model.footerText == "To submit: add a deep link. Events can go to App Review on their own.")
        #expect(model.footerButton?.isEnabled == false)

        model.setDetail(.deepLink, to: "lumen://challenge/winter", of: event)
        let change = try #require(model.queuedDetail(.deepLink, of: event))
        #expect(change.source == .you)
        #expect(model.detailValue(.deepLink, of: event) == "lumen://challenge/winter")
        #expect(model.reviewItems(of: event).map(\.state) == [.queued])
        // It's there once pushed.
        #expect(model.footerText == "To submit: push its changes. Events can go to App Review on their own.")

        // Back to App Store Connect's value: nothing waits.
        model.setDetail(.deepLink, to: "", of: event)
        #expect(model.queuedDetail(.deepLink, of: event) == nil)
        model.setDetail(.deepLink, to: "lumen://x", of: event)
        model.revertDetail(.deepLink, of: event)
        #expect(queue.changes(for: Data.app.id, section: .inAppEvents).isEmpty)
    }

    @Test func purposeAndPrimaryLanguageAreEditedTheSameWay() async {
        let model = await makeModel()
        model.setDetail(.purpose, to: InAppEventPurpose.bringBackLapsedUsers.rawValue, of: Self.ready)
        model.setDetail(.priority, to: InAppEventPriority.high.rawValue, of: Self.ready)
        #expect(model.detailValue(.purpose, of: Self.ready) == "BRING_BACK_LAPSED_USERS")
        #expect(model.detailValue(.priority, of: Self.ready) == "HIGH")
        #expect(model.pendingCount == 2)
        // A published event's details can't change here.
        model.setDetail(.purpose, to: "ATTRACT_NEW_USERS", of: Data.update)
        #expect(model.queuedDetail(.purpose, of: Data.update) == nil)
    }

    @Test func anAssistantsDeepLinkWaitsForAccept() async throws {
        var event = Self.ready
        event.deepLink = nil
        let model = await makeModel([event])
        let builder = InAppEventChangeBuilder(appID: Data.app.id)
        let suggested = try #require(builder.detailChange(
            .deepLink, to: "lumen://challenge/winter", of: event, source: .assistant(client: "Claude Code")
        ))
        queue.upsert(suggested)
        #expect(model.reviewItems(of: event).map(\.state) == [.suggested])
        #expect(model.footerText.hasPrefix("To submit: accept or add a deep link"))
        model.acceptDetail(.deepLink, of: event)
        #expect(model.queuedDetail(.deepLink, of: event)?.awaitingAcceptance == nil)
        #expect(model.reviewItems(of: event).map(\.state) == [.queued])
    }

    /// Alba: its project declares no alba:// scheme, so App Review would
    /// tap Open and nothing would open.
    @Test func aLinkTheProjectDoesntClaimBlocksSubmitEvent() async {
        let model = await makeModel()
        claims.pin(.read(folder: "/Lumen", claims: ProjectLinkClaims(schemes: [], targets: ["Lumen"])), for: Data.app.id)
        #expect(model.linkClaim(of: Self.ready) == .notClaimed("lumen://"))
        #expect(model.reviewItems(of: Self.ready).map(\.id) == ["linkNotClaimed"])
        #expect(model.footerText == "To submit: make Lumen Journal open its deep link. Events can go to App Review on their own.")
        #expect(model.footerButton?.isEnabled == false)

        claims.pin(.read(folder: "/Lumen", claims: ProjectLinkClaims(schemes: ["lumen"], targets: ["Lumen"])), for: Data.app.id)
        #expect(model.linkClaim(of: Self.ready) == .claimed("lumen://"))
        #expect(model.footerButton?.isEnabled == true)
        // Without a project folder Atlas can't tell, and doesn't block.
        claims.pin(.noFolder, for: Data.app.id)
        #expect(model.footerButton?.isEnabled == true)
    }

    @Test func aCheckIsForTheDeepLinkItCheckedOnly() async {
        let model = await makeModel()
        store.setDeepLinkReport(Self.report("lumen://challenge/winter"), for: Data.app.id)
        #expect(model.deepLinkReport(of: Self.ready)?.statusLine == "Opens the event · checked by Claude Code in build 1.4 (212), tried in Simulator")
        model.setDetail(.deepLink, to: "lumen://challenges/winter-2026", of: Self.ready)
        #expect(model.deepLinkReport(of: Self.ready) == nil)
        // Dropped for good: undo doesn't bring it back.
        model.revertDetail(.deepLink, of: Self.ready)
        #expect(model.deepLinkReport(of: Self.ready) == nil)
    }

    @Test func aFixForTextsGoesToTheLanguageToWrite() async {
        let model = await makeModel([Data.winter])
        let item = model.reviewItems(of: Data.winter).first
        #expect(item?.need == .languageTexts)
        model.showLanguage(for: .languageTexts, of: Data.winter)
        #expect(model.localeCode == "de-DE")
    }
}
