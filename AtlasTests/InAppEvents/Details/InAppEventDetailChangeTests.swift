//
//  InAppEventDetailChangeTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// An existing event's deep link, purpose, priority and primary language
/// as Review & Push changes: each a `PATCH /v1/appEvents/{id}` with that
/// attribute alone, restorable, checked for conflicts, and checked the way
/// App Store Connect takes it (Alba 1.2.0's events went without a deep
/// link, and App Store Connect refused the submission).
@MainActor
@Suite("In-App Events · details")
struct InAppEventDetailChangeTests {
    typealias Data = InAppEventsTestData

    private let builder = InAppEventChangeBuilder(appID: Data.app.id)

    private func attributes(_ request: PushRequest?) throws -> [String: Any] {
        let body = try #require(request?.body)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        let document = try #require(object["data"] as? [String: Any])
        #expect(document["type"] as? String == "appEvents")
        #expect(document["id"] as? String == "winter")
        return try #require(document["attributes"] as? [String: Any])
    }

    // MARK: - The deep link

    @Test(arguments: [
        ("alba://events/new-year-2027", nil),
        ("https://alba.app/events/holidays-2026", nil),
        ("  alba://events  ", nil),
        ("", nil),
        ("alba events", "The deep link isn’t a valid URL. Use a universal link (https://alba.app/event) or the app’s own scheme (alba://event)."),
        ("https://", "The deep link isn’t a valid URL. Use a universal link (https://alba.app/event) or the app’s own scheme (alba://event)."),
        ("1alba://x", "The deep link isn’t a valid URL. Use a universal link (https://alba.app/event) or the app’s own scheme (alba://event)."),
        ("http://alba.app/events", "http:// links open in Safari, not the app. Use https:// (a universal link) or the app’s own scheme."),
    ] as [(String, String?)])
    func aDeepLinkIsCheckedLikeAppStoreConnect(link: String, problem: String?) {
        #expect(InAppEventDeepLink.problem(link, appName: "Alba") == problem)
    }

    @Test func aLongDeepLinkAndExamplesNameTheApp() {
        let long = "alba://" + String(repeating: "a", count: 1100)
        // Numbers as the person's region writes them.
        #expect(InAppEventDeepLink.problem(long) == "The deep link is \(1107.formatted()) characters; the limit is \(1024.formatted()).")
        #expect(InAppEventDeepLink.slug("Lumen Journal") == "lumen")
        #expect(InAppEventDeepLink.slug("Café: Daily") == "cafe")
        #expect(InAppEventDeepLink.slug("!!!") == "myapp")
        #expect(InAppEventDeepLink.webHost(of: "https://Alba.App/x") == "alba.app")
        #expect(InAppEventDeepLink.webHost(of: "alba://x") == nil)
        #expect(InAppEventDeepLink.scheme(of: "ALBA://x") == "alba")
    }

    // MARK: - Changes

    @Test func aDeepLinkIsOnePatchWithOnlyThatAttribute() throws {
        var event = Data.winter
        event.deepLink = nil
        let change = try #require(builder.detailChange(.deepLink, to: " alba://events/winter ", of: event, appName: "Lumen", source: .you))
        #expect(change.id == "inAppEvents.\(Data.app.id).winter.details.deepLink")
        #expect(change.section == .inAppEvents)
        #expect(change.groupID == "winter")
        #expect(change.title == "Deep link")
        #expect(change.oldValue == "")
        #expect(change.newValue == "alba://events/winter")
        #expect(change.blockedReason == nil)
        #expect(change.awaitingAcceptance == nil)
        let request = try #require(change.requests.first)
        #expect(change.requests.count == 1)
        #expect(request.method == .patch)
        #expect(request.path == "/v1/appEvents/winter")
        let written = try attributes(request)
        #expect(written.count == 1)
        #expect(written["deepLink"] as? String == "alba://events/winter")
        // Slashes stay as they are.
        #expect(request.body.flatMap { String(bytes: $0, encoding: .utf8) }?.contains("alba://events/winter") == true)
        // Undo writes back that there was none.
        let restore = try attributes(change.restoreRequests.first)
        #expect(restore["deepLink"] is NSNull)
        #expect(change.conflictCheck == ConflictCheck(
            path: "/v1/appEvents/winter?fields[appEvents]=deepLink", keyPath: ["data", "attributes", "deepLink"], expected: nil
        ))
        #expect(InAppEventChangeBuilder.detailValue(in: change)?.detail == .deepLink)
        #expect(InAppEventChangeBuilder.detailValue(in: change)?.value == "alba://events/winter")
    }

    @Test func purposePriorityAndPrimaryLanguageAreTheirOwnChanges() throws {
        let purpose = try #require(builder.detailChange(.purpose, to: "ATTRACT_NEW_USERS", of: Data.winter, appName: "Lumen", source: .you))
        #expect(try attributes(purpose.requests.first)["purpose"] as? String == "ATTRACT_NEW_USERS")
        #expect(try attributes(purpose.restoreRequests.first)["purpose"] as? String == "APPROPRIATE_FOR_ALL_USERS")
        #expect(purpose.conflictCheck?.expected == "APPROPRIATE_FOR_ALL_USERS")

        let priority = try #require(builder.detailChange(.priority, to: "HIGH", of: Data.winter, source: .you))
        #expect(try attributes(priority.requests.first) as? [String: String] == ["priority": "HIGH"])

        // A primary language is written as App Store Connect's code.
        let locale = try #require(builder.detailChange(.primaryLocale, to: "de-de", of: Data.winter, source: .you))
        #expect(try attributes(locale.requests.first)["primaryLocale"] as? String == "de-DE")
        #expect(locale.newValue == "German")
        #expect(locale.oldValue == "English (U.S.)")

        let changes = [purpose, priority, locale]
        let queued = builder.queuedDetails(for: "winter", in: changes)
        #expect(Set(queued.keys) == [.purpose, .priority, .primaryLocale])
        #expect(builder.value(.purpose, of: Data.winter, in: changes) == "ATTRACT_NEW_USERS")
        #expect(builder.value(.deepLink, of: Data.winter, in: changes) == "lumen://challenge/winter")
    }

    @Test func whatAppStoreConnectHasAlreadyIsNoChange() {
        #expect(builder.detailChange(.deepLink, to: "lumen://challenge/winter", of: Data.winter, source: .you) == nil)
        #expect(builder.detailChange(.primaryLocale, to: "en-us", of: Data.winter, source: .you) == nil)
        #expect(builder.detailChange(.purpose, to: " APPROPRIATE_FOR_ALL_USERS ", of: Data.winter, source: .you) == nil)
    }

    @Test func aValueAppStoreConnectWouldRefuseIsBlocked() throws {
        let link = try #require(builder.detailChange(.deepLink, to: "lumen challenge", of: Data.winter, source: .you))
        #expect(link.blockedReason?.hasPrefix("The deep link isn’t a valid URL.") == true)
        let purpose = try #require(builder.detailChange(.purpose, to: "EVERYONE", of: Data.winter, source: .you))
        #expect(purpose.blockedReason?.hasPrefix("“EVERYONE” isn’t a purpose.") == true)
        let cleared = try #require(builder.detailChange(.purpose, to: "", of: Data.winter, source: .you))
        #expect(cleared.blockedReason == "Choose a purpose.")
        // Clearing the deep link is allowed: the event stays a draft.
        let noLink = try #require(builder.detailChange(.deepLink, to: nil, of: Data.winter, source: .you))
        #expect(noLink.blockedReason == nil)
        #expect(try attributes(noLink.requests.first)["deepLink"] is NSNull)
    }

    @Test func anAssistantsDetailWaitsForThePerson() throws {
        let change = try #require(builder.detailChange(
            .deepLink, to: "lumen://challenge/winter-2026", of: Data.winter, source: .assistant(client: "Claude Code"),
            reason: "LumenApp handles lumen://challenge/<id>."
        ))
        #expect(change.awaitingAcceptance == "Look at it, then accept it here or on the event’s page.")
        #expect(change.groupNote == "LumenApp handles lumen://challenge/<id>.")
    }

    /// Plain attribute PATCHes go beside the others; two of one event
    /// write the same resource, so the second waits.
    @Test func detailsGoSideBySideButNotOverTheSameEvent() throws {
        let link = try #require(builder.detailChange(.deepLink, to: "lumen://a", of: Data.winter, source: .you))
        let other = try #require(builder.detailChange(.priority, to: "HIGH", of: Data.update, source: .you))
        let purpose = try #require(builder.detailChange(.purpose, to: "ATTRACT_NEW_USERS", of: Data.winter, source: .you))
        #expect(PushSchedule.waits(for: [link, other, purpose]) == [[], [], [0]])
    }

    // MARK: - Before App Review

    @Test func theReviewListCountsWhatWaitsAndWhatsSuggested() throws {
        var event = Data.winter
        event.deepLink = nil
        event.purpose = nil
        event.localizations[0].media = []
        let purpose = try #require(builder.detailChange(.purpose, to: "ATTRACT_NEW_USERS", of: event, source: .assistant(client: "Claude Code")))
        let waiting = InAppEventReviewItem.Waiting(details: [.purpose: purpose], missingArt: [.details], draftedLocales: ["de-DE"])
        let items = InAppEventReviewItem.items(for: event, waiting: waiting, claim: .noDeepLink, appName: "Lumen", now: Data.now)
        #expect(items.map(\.id) == ["deepLink", "purpose", "languageTexts", "card", "details"])
        #expect(items.map(\.state) == [.missing, .suggested, .queued, .queued, .missing])
        #expect(items[0].text == "No deep link: Open on the card has nowhere to go.")
        #expect(items[0].detail == "Use a universal link (https://lumen.app/event) or the app’s own scheme (lumen://event).")
        #expect(items[1].stateText == "Suggested · accept it below")
        #expect(items[2].stateText == "Waits in Review & Push")
    }

    @Test func aLinkTheAppDoesntClaimIsOnTheList() {
        var ready = Data.winter
        ready.localizations.removeLast()
        let items = InAppEventReviewItem.items(
            for: ready, waiting: .init(), claim: .notClaimed("lumen://"), appName: "Lumen Journal", now: Data.now
        )
        #expect(items.map(\.id) == ["linkNotClaimed"])
        #expect(items[0].text == "Lumen Journal doesn’t open lumen:// links yet")
        #expect(items[0].state == .missing)
    }
}
