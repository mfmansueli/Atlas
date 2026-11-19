//
//  PendingChangeGuidelineTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Review & Push warns about what App Review would reject in In-App Event
/// texts and retention messages too, whoever wrote them: the person can
/// still push.
@MainActor
@Suite("Review & Push · App Review warnings outside the Store Page")
struct PendingChangeGuidelineTests {
    typealias Data = InAppEventsTestData

    private let builder = InAppEventChangeBuilder(appID: Data.app.id)

    @Test func anEventTextWithAPriceIsWarnedAbout() throws {
        let german = try #require(Data.winter.localization("de-DE"))
        let priced = try #require(builder.fieldChange(.shortDescription, to: "Alles für 4,99 €", in: german, of: Data.winter, source: .you))
        #expect(priced.guidelineIssues.map(\.kind) == [.pricing])
        #expect(priced.guidelineIssues.first?.place == .eventText)
        // A free weekend is fine in an event.
        let free = try #require(builder.fieldChange(.name, to: "Gratis-Wochenende", in: german, of: Data.winter, source: .you))
        #expect(free.guidelineIssues.isEmpty)
    }

    @Test func aNewLanguagesTextsAreCheckedTogether() throws {
        let texts: [InAppEventField: String] = [.name: "SUPER WINTER EVENT", .shortDescription: "Join now!!", .longDescription: "Reflect daily."]
        let new = try #require(builder.newLanguageChange(texts, locale: "it", of: Data.winter, source: .you))
        #expect(new.guidelineIssues.map(\.kind) == [.emphasis])
        #expect(new.guidelineIssues.first?.phrases == ["SUPER WINTER EVENT", "!!"])
    }

    @Test func aNewEventsTextsAreChecked() throws {
        var event = NewInAppEvent(now: Data.now)
        event.referenceName = "Spring Reset 2027"
        event.texts["en-US"] = [.name: "Spring Reset", .shortDescription: "The #1 habit week", .longDescription: "Seven days of small habits."]
        let change = try #require(builder.newEventChange(event, token: "t1"))
        #expect(change.guidelineIssues.map(\.kind) == [.unverifiableClaim])
        // The reference name isn't shown on the App Store.
        event.texts["en-US"]?[.shortDescription] = "A fresh start"
        event.referenceName = "Spring Reset — $4.99 promo"
        #expect(try #require(builder.newEventChange(event, token: "t2")).guidelineIssues.isEmpty)
    }

    @Test func aRetentionMessageWithAnOfferIsWarnedAbout() {
        var message = RetentionTestFixtures.englishDraft()
        message.texts["en-US"] = RetentionText(header: "Wait, stay with us", body: "Stay and get 50% off your next three months.")
        let change = RetentionTestFixtures.builder(messages: [message]).change(for: message, messageCount: 1)
        #expect(change.guidelineIssues.map(\.kind) == [.pricing])
        #expect(change.guidelineIssues.first?.message.contains("retention message guidelines") == true)

        let honest = RetentionTestFixtures.englishDraft()
        #expect(RetentionTestFixtures.builder(messages: [honest]).change(for: honest, messageCount: 1).guidelineIssues.isEmpty)
    }
}
#endif
