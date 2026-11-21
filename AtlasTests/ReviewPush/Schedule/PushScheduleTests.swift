//
//  PushScheduleTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Which changes of a push go out side by side and which wait: plain text
/// edits run together unless they write the same resource, the rest keep
/// their app's order, and an event's art for a language the push creates
/// waits for it.
@MainActor
@Suite("Push schedule")
struct PushScheduleTests {
    private func change(
        _ id: String, app: StoreApp.ID = "lumen", section: AppWorkspaceSection = .storePage, method: PushRequest.Method = .patch,
        path: String, body: String? = nil
    ) -> PendingChange {
        PendingChange(
            id: id, appID: app, section: section, group: "G", title: id, oldValue: "", newValue: "new",
            requests: [PushRequest(method: method, path: path, body: body.map { Data($0.utf8) })]
        )
    }

    private func art(_ id: String, localizationID: String) -> PendingChange {
        let push = InAppEventArtworkPush(
            localizationID: localizationID, kind: .card, isVideo: false, fileName: "card.png", fileSize: 10, path: "/tmp/card.png"
        )
        return PendingChange(
            id: id, appID: "lumen", section: .inAppEvents, group: "G", title: id, oldValue: "", newValue: "art", requests: [push.request]
        )
    }

    @Test func textEditsOnDifferentResourcesWaitForNothing() {
        let waits = PushSchedule.waits(for: [
            change("en.whatsNew", path: "/v1/appStoreVersionLocalizations/en"),
            change("de.whatsNew", path: "/v1/appStoreVersionLocalizations/de"),
            change("event.de.name", section: .inAppEvents, path: "/v1/appEventLocalizations/de"),
            change("info.de.subtitle", section: .appInformation, path: "/v1/appInfoLocalizations/de"),
        ])
        #expect(waits == [[], [], [], []])
    }

    /// A new version doesn't wait for the app's custom product pages, and
    /// its texts wait only for it: its languages go side by side, and its
    /// App Review fields one after the other (the first makes them).
    @Test func aNewVersionAndItsTextsSkipTheAppsOrder() {
        let page = change("page.new", section: .productPages, method: .post, path: "/v1/appCustomProductPages")
        let version = PendingChange(
            id: "appStoreVersion.lumen.IOS", appID: "lumen", section: .storePage, group: "G", title: "v", oldValue: "", newValue: "1.2",
            requests: [PushRequest(method: .post, path: "/v1/appStoreVersions", body: nil)]
        )
        func tied(_ id: String, path: String) -> PendingChange {
            var text = change(id, path: path)
            text.dependsOn = version.id
            return text
        }
        let waits = PushSchedule.waits(for: [
            page,
            change("page2.new", section: .productPages, method: .post, path: "/v1/appCustomProductPages/x"),
            version,
            tied("en", path: "/v1/appStoreVersionLocalizations/{queuedVersion:IOS:1.2:localization:en-US}"),
            tied("de", path: "/v1/appStoreVersionLocalizations/{queuedVersion:IOS:1.2:localization:de-DE}"),
            tied("notes", path: "/v1/appStoreReviewDetails/{queuedVersion:IOS:1.2:reviewDetail}"),
            tied("email", path: "/v1/appStoreReviewDetails/{queuedVersion:IOS:1.2:reviewDetail}"),
        ])
        #expect(waits == [[], [0], [], [2], [2], [2], [2, 5]])
    }

    @Test func twoEditsOfOneResourceGoOneAfterTheOther() {
        let waits = PushSchedule.waits(for: [
            change("en.whatsNew", path: "/v1/appStoreVersionLocalizations/en"),
            change("de.whatsNew", path: "/v1/appStoreVersionLocalizations/de"),
            change("en.description", path: "/v1/appStoreVersionLocalizations/en"),
        ])
        #expect(waits[2] == [0])
    }

    @Test func everythingElseKeepsItsAppsOrderButNotOtherApps() {
        let waits = PushSchedule.waits(for: [
            change("price.BRA", section: .subscriptionPricing, method: .post, path: "/v1/subscriptionPrices/BRA"),
            change("en.whatsNew", path: "/v1/appStoreVersionLocalizations/en"),
            change("fr.new", method: .post, path: "/v1/appStoreVersionLocalizations"),
            change("habitat.price", app: "habitat", section: .subscriptionPricing, method: .post, path: "/v1/subscriptionPrices/MEX"),
            change("price.CHL", section: .subscriptionPricing, method: .post, path: "/v1/subscriptionPrices/CHL"),
        ])
        #expect(waits[1] == [])
        #expect(waits[2] == [0])
        #expect(waits[3] == [])
        #expect(waits[4] == [0, 2])
    }

    @Test func aWriteWithSomethingToFillInOrAMergedOneKeepsTheOrder() {
        let waits = PushSchedule.waits(for: [
            change("version", method: .post, path: "/v1/appStoreVersions"),
            change("en.whatsNew", path: "/v1/appStoreVersionLocalizations/{createdID}"),
            change("de.whatsNew", path: "/v1/appStoreVersionLocalizations/de", body: #"{"data":{"id":"{secret:x}"}}"#),
            change("rating.violence", section: .appInformation, path: "/v1/ageRatingDeclarations/1"),
        ])
        #expect(waits[1] == [0])
        #expect(waits[2] == [0, 1])
        // Age rating answers go out merged into one write: they keep the order too.
        #expect(waits[3] == [0, 1, 2])
    }

    @Test func artGoesSideBySideButWaitsForTheLanguageThePushCreates() {
        let placeholder = EventLocalizationPlaceholder(eventID: "winter", locale: "fr-FR").token
        let waits = PushSchedule.waits(for: [
            change("winter.fr-FR.new", section: .inAppEvents, method: .post, path: "/v1/appEventLocalizations"),
            art("art.card.en", localizationID: "loc-en"),
            art("art.details.en", localizationID: "loc-en"),
            art("art.card.de", localizationID: "loc-de"),
            art("art.card.fr", localizationID: placeholder),
        ])
        #expect(waits[1] == [])
        #expect(waits[2] == [1])
        #expect(waits[3] == [])
        #expect(waits[4] == [0])
    }
}
