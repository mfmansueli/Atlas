//
//  InAppEventsViewModelTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The In-App Events section: an event's languages, editing its texts,
/// accepting what an assistant suggested, and new events, all waiting in
/// Review & Push.
@MainActor
@Suite("InAppEventsViewModel")
struct InAppEventsViewModelTests {
    typealias Data = InAppEventsTestData

    private let queue = ChangeQueue()
    private let store = InAppEventsStore()

    private func makeModel(_ services: FakeInAppEventsServices = FakeInAppEventsServices()) async -> InAppEventsViewModel {
        let model = InAppEventsViewModel(app: Data.app, services: services, store: store, queue: queue)
        model.now = { Data.now }
        model.pageLocales = ["en-US", "de-DE", "ja", "pt-BR"]
        // What another test's project claims stays out of these.
        model.linkClaims = ProjectLinkClaimsCenter()
        await model.load()
        return model
    }

    @Test func loadingSelectsTheFirstEventOnItsPrimaryLanguage() async {
        let model = await makeModel()
        #expect(model.events.map(\.id) == ["winter", "update", "gratitude"])
        #expect(model.selectedEvent?.id == "winter")
        #expect(model.localeCode == "en-US")
        #expect(model.status(of: Data.winter) == .draft)
        #expect(model.status(of: Data.gratitude) == .ended)
    }

    @Test func aFailedReadSaysSoAndLaterKeepsWhatWasRead() async {
        let services = FakeInAppEventsServices()
        services.error = .server(statusCode: 500, detail: "Later.")
        let model = await makeModel(services)
        #expect(model.state.errorMessage != nil)
        services.error = nil
        await model.load(force: true)
        #expect(model.events.count == 3)
        services.error = .server(statusCode: 500, detail: "Later.")
        await model.load(force: true)
        #expect(model.events.count == 3)
    }

    @Test func anEventsLanguagesAreItsOwnThePagesAndTheSuggestedOnes() async {
        store.add([Data.suggestion("ja"), Data.suggestion("ko")], for: Data.app.id)
        let model = await makeModel()
        let languages = model.languages(of: Data.winter)
        // The primary first, then by name.
        #expect(languages.map(\.code) == ["en-US", "de-DE", "ja", "ko", "pt-BR"])
        #expect(languages.map(\.state) == [.written, .written, .suggested, .suggested, .missing])
        #expect(model.suggestedCount == 2)
        #expect(model.suggestionsTitle == "2 languages suggested by Claude Code")
        // A live event isn't offered the page's other languages.
        #expect(model.languages(of: Data.update).map(\.code) == ["en-US"])
    }

    @Test func editingAWrittenLanguageQueuesOneChangePerField() async throws {
        let model = await makeModel()
        model.localeCode = "de-DE"
        model.edit(.shortDescription, to: "Mit 31 Impulsen sanft ins neue Jahr")
        let change = try #require(queue.change(id: "inAppEvents.\(Data.app.id).winter.de-DE.shortDescription"))
        #expect(change.section == .inAppEvents)
        #expect(change.oldValue == "")
        #expect(change.newValue == "Mit 31 Impulsen sanft ins neue Jahr")
        #expect(change.title == "German · Short Description")
        #expect(change.requests.first?.method == .patch)
        #expect(change.requests.first?.path == "/v1/appEventLocalizations/loc-de")
        #expect(model.text(.shortDescription) == "Mit 31 Impulsen sanft ins neue Jahr")
        #expect(model.isPending(.shortDescription))
        #expect(model.languages(of: Data.winter).first { $0.code == "de-DE" }?.state == .notPushed)
        // Typing the App Store's text back takes the change out.
        model.edit(.shortDescription, to: "")
        #expect(queue.changes(for: Data.app.id).isEmpty)
    }

    @Test func textOverTheLimitWaitsButCantBePushed() async throws {
        let model = await makeModel()
        model.edit(.name, to: String(repeating: "a", count: 31))
        let change = try #require(queue.changes(for: Data.app.id).first)
        #expect(change.isBlocked)
        #expect(change.blockedReason == "Event Name is 31 characters; the limit is 30.")
    }

    @Test func aNewLanguageIsCreatedWithEverythingWrittenForIt() async throws {
        let model = await makeModel()
        model.localeCode = "ja"
        model.edit(.name, to: "冬のふりかえり")
        model.edit(.shortDescription, to: "31の問い")
        #expect(queue.changes(for: Data.app.id).count == 1)
        let change = try #require(queue.change(id: "inAppEvents.\(Data.app.id).winter.ja.new"))
        let request = try #require(change.requests.first)
        #expect(request.method == .post)
        #expect(request.path == "/v1/appEventLocalizations")
        let document = try #require(InAppEventWriteDocument.decode(request.body))
        #expect(document.data.attributes == ["locale": "ja", "name": "冬のふりかえり", "shortDescription": "31の問い"])
        #expect(document.data.relationships?["appEvent"]?.data.id == "winter")
        #expect(model.text(.name) == "冬のふりかえり")
    }

    @Test func acceptingASuggestionWritesItsThreeTextsAndUndoTakesThemBack() async {
        store.add([Data.suggestion("ja", name: "冬")], for: Data.app.id)
        let model = await makeModel()
        model.localeCode = "ja"
        #expect(model.suggestion?.name == "冬")
        #expect(model.fallbackNote == "Not localized yet: people who read Japanese see the event in English (U.S.).")
        model.acceptSuggestion()
        #expect(model.text(.name) == "冬")
        #expect(model.text(.longDescription) == "Long ja")
        #expect(model.suggestion == nil)
        #expect(store.count(for: Data.app.id) == 0)
        #expect(model.toast?.canUndo == true)
        #expect(queue.changes(for: Data.app.id).first?.source == .assistant(client: "Claude Code"))
        model.undoAccept()
        #expect(queue.changes(for: Data.app.id).isEmpty)
        #expect(model.suggestion?.name == "冬")
        #expect(model.toast == nil)
    }

    @Test func acceptAllLanguagesAcceptsEverySuggestionOfTheEvent() async {
        store.add([Data.suggestion("ja"), Data.suggestion("ko"), Data.suggestion("de-DE"), Data.suggestion("fr-FR", event: "update")], for: Data.app.id)
        let model = await makeModel()
        // German is only partly written, so its suggestion counts. The live event can't
        // change any more: reading the events dropped the suggestion for it.
        #expect(store.open(for: Data.app.id).map(\.eventID) == ["winter", "winter", "winter"])
        #expect(model.suggestedCount == 3)
        model.acceptAllLanguages()
        #expect(model.toast?.text == "Accepted 3 languages for Winter Reflection Challenge. They’re waiting in Review & Push, top right.")
        let prefix = "inAppEvents.\(Data.app.id).winter."
        #expect(queue.changes(for: Data.app.id).map { String($0.id.dropFirst(prefix.count)) }.sorted() == [
            "de-DE.longDescription", "de-DE.name", "de-DE.shortDescription", "ja.new", "ko.new",
        ])
        #expect(model.suggestedCount == 0)
        #expect(store.count(for: Data.app.id) == 0)
        model.undoAccept()
        #expect(queue.changes(for: Data.app.id).isEmpty)
        #expect(model.suggestedCount == 3)
    }

    @Test func dismissingLeavesTheLanguageMissing() async {
        store.add([Data.suggestion("ja")], for: Data.app.id)
        let model = await makeModel()
        model.localeCode = "ja"
        model.dismissSuggestion()
        #expect(model.suggestion == nil)
        #expect(model.selectedLanguage?.state == .missing)
    }

    @Test func anEndedEventCantBeEditedAndIsDuplicatedForNextYear() async throws {
        let model = await makeModel()
        model.select("gratitude")
        #expect(!model.canEdit)
        model.edit(.name, to: "Changed")
        #expect(queue.changes(for: Data.app.id).isEmpty)
        #expect(model.footerButton?.title == "Duplicate Event")
        #expect(model.footerText == "Duplicate it to run it again next year.")
        model.duplicateSelectedEvent()
        let change = try #require(model.queuedNewEvents.first)
        #expect(change.title == "Create “Gratitude Week copy”")
        #expect(change.requests.map(\.path) == ["/v1/appEvents", "/v1/appEventLocalizations"])
        let created = try #require(InAppEventWriteDocument.decode(change.requests.last?.body))
        #expect(created.data.relationships?["appEvent"]?.data.id == PushRequest.createdIDPlaceholder)
    }

    @Test func aNewEventNeedsANameAndDatesThatMakeSense() async throws {
        let model = await makeModel()
        var event = NewInAppEvent(now: Data.now)
        #expect(event.problem == "Give the event a reference name. People never see it.")
        #expect(!model.add(event))
        event.referenceName = "Spring Reset 2027"
        event.eventEnd = event.eventStart
        #expect(event.problem == "The event has to end after it starts.")
        event.eventEnd = event.eventStart.addingTimeInterval(86400)
        event.publishStart = event.eventStart.addingTimeInterval(60)
        #expect(event.problem == "The card can’t start showing after the event has started.")
        event.publishStart = event.eventStart.addingTimeInterval(-86400)
        #expect(event.problem == nil)
        #expect(model.add(event))
        let change = try #require(model.queuedNewEvents.first)
        let body = try #require(change.requests.first?.body.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any])
        let attributes = try #require((body["data"] as? [String: Any])?["attributes"] as? [String: Any])
        #expect(attributes["referenceName"] as? String == "Spring Reset 2027")
        #expect(attributes["badge"] as? String == "SPECIAL_EVENT")
        #expect(attributes["purchaseRequirement"] as? String == "NO_COST_ASSOCIATED")
        #expect(attributes["deepLink"] == nil)
        #expect((attributes["territorySchedules"] as? [[String: Any]])?.count == 1)
    }

    @Test func aNewEventCantTakeAnotherEventsNameOrStartInThePast() async throws {
        let model = await makeModel()
        var event = NewInAppEvent(now: Data.now)
        event.referenceName = "Winter Reflection 2026"
        #expect(model.problem(for: event)?.hasPrefix("Another event already has the reference name “Winter Reflection 2026”") == true)
        #expect(!model.add(event))
        event.referenceName = "Spring Reset 2027"
        event.purchaseRequirement = .inAppPurchase
        event.deepLink = "lumen://spring"
        #expect(model.add(event))
        // Queued, the name is taken too.
        #expect(model.problem(for: event)?.hasPrefix("Another event already has the reference name") == true)
        event.referenceName = "Summer 2027"
        event.eventStart = Data.day(-1)
        event.eventEnd = Data.day(3)
        event.publishStart = Data.day(-2)
        #expect(model.problem(for: event) == "The event has to start in the future. Move its dates later.")
        event.deepLink = "lumen spring"
        event.eventStart = Data.day(20)
        event.eventEnd = Data.day(23)
        event.publishStart = Data.day(15)
        #expect(model.problem(for: event)?.hasPrefix("The deep link isn’t a valid URL.") == true)

        let change = try #require(model.queuedNewEvents.first)
        let queued = try #require(InAppEventChangeBuilder.newEvent(in: change))
        #expect(queued.purchaseRequirement == .inAppPurchase)
        #expect(queued.deepLink == "lumen://spring")
    }

    @Test func duplicatingTwiceNamesTheSecondCopyAndKeepsTheDeepLink() async throws {
        var gratitude = Data.gratitude
        gratitude.deepLink = "lumen://gratitude"
        gratitude.purchaseRequirement = .inAppPurchase
        let model = await makeModel(FakeInAppEventsServices([Data.winter, Data.update, gratitude]))
        model.select("gratitude")
        model.duplicateSelectedEvent()
        model.duplicateSelectedEvent()
        #expect(model.queuedNewEvents.map(\.title) == ["Create “Gratitude Week copy”", "Create “Gratitude Week copy 2”"])
        let copy = try #require(model.queuedNewEvents.first.flatMap(InAppEventChangeBuilder.newEvent(in:)))
        #expect(copy.deepLink == "lumen://gratitude")
        #expect(copy.purchaseRequirement == .inAppPurchase)
        #expect(copy.eventStart > Data.now)
    }

    @Test func theFooterSaysWhatADraftStillNeeds() async {
        store.add([Data.suggestion("ja")], for: Data.app.id)
        let model = await makeModel()
        #expect(model.footerText == "To submit: accept or write every language. Events can go to App Review on their own.")
        #expect(model.footerButton?.title == "Submit Event…")
        #expect(model.footerButton?.isEnabled == false)
        model.versionString = "1.4"
        model.versionEventIDs = ["winter"]
        #expect(model.status(of: Data.winter) == .goesWithVersion("1.4"))
        #expect(model.footerText == "Goes to App Review with 1.4.")
        #expect(model.footerButton?.title == "Open Submission")
    }

    @Test func aCompleteDraftCanGoToAppReviewOnItsOwn() async {
        var ready = Data.winter
        ready.localizations.removeLast()
        let services = FakeInAppEventsServices([ready])
        let model = await makeModel(services)
        model.pageLocales = ["en-US"]
        #expect(model.footerText == "Ready. Events can go to App Review on their own, without a new version.")
        #expect(model.footerButton?.isEnabled == true)
        let release = FakeReleaseServices()
        await model.submitSelectedEvent(using: release, platform: "IOS")
        #expect(release.submittedEvents == [["winter"]])
        #expect(model.toast?.text == "“Winter Reflection Challenge” is submitted. App Review usually takes about a day.")
        #expect(services.readCount == 2)

        release.refuses = true
        await model.submitSelectedEvent(using: release, platform: "IOS")
        #expect(model.actionError != nil)
    }
}
