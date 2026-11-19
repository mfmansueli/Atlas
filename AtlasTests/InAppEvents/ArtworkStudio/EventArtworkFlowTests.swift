//
//  EventArtworkFlowTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// Event artwork (board 47): the Brief and its defaults, Make the Artwork
/// starting Claude Code (or copying its prompt) and closing the Brief,
/// Stop, the concept the event's preview shows, Change… and Keep Current,
/// Ask for Changes, Use This Artwork (into the primary language, and the
/// other languages that need their own) with Undo, and Choose Files….
@MainActor
@Suite("Event artwork flow")
struct EventArtworkFlowTests {
    typealias Test = EventArtworkStudioTestData
    typealias Events = InAppEventsTestData

    private let directory = EventArtworkTestFiles.directory()
    private let studio = EventArtworkStudio()
    private let queue = ChangeQueue()

    private func flow(hasDesignSystem: Bool = true, event: InAppEvent = Events.winter) -> EventArtworkFlow {
        let flow = EventArtworkFlow(app: Events.app, event: event, studio: studio, queue: queue, hasDesignSystem: hasDesignSystem)
        flow.directory = directory
        flow.now = { Events.now }
        return flow
    }

    private func chosen(_: EventArtworkFlow, step: EventArtworkStep = .check) throws {
        var run = try Test.run(step: step, concepts: [Test.concept("a", isPick: true, in: directory), Test.concept("b", in: directory)])
        run.pickedID = "a"
        studio.begin(run)
    }

    // MARK: - Brief

    @Test func theBriefIsWrittenFromTheEvent() {
        let flow = flow()
        #expect(flow.step == .brief)
        #expect(!flow.isStarted)
        #expect(flow.run.brief.hasPrefix("Art for “Winter Reflection Challenge”. 31 prompts to close the year gently."))
        #expect(flow.run.brief.contains("nothing busy in the lower third"))
        #expect(flow.run.locales == ["en-US", "de-DE"])
        #expect(flow.run.style == .newLook)
        #expect(flow.minutes == 10)
        #expect(flow.summary == "3 concepts, each a matching pair · about 10 min · nothing reaches the App Store until you push")
    }

    @Test func withoutADesignProjectTemplatesComeFirst() {
        let flow = flow(hasDesignSystem: false)
        #expect(flow.run.style == .template)
        #expect(!flow.isOffered(.newLook))
        #expect(flow.isOffered(.extendCard))
        let noCard = InAppEvent(id: "x", referenceName: "X", state: .draft, localizations: [InAppEventLocalization(id: "l", locale: "en-US")])
        #expect(!self.flow(event: noCard).isOffered(.extendCard))
    }

    @Test func theOptionsChangeTheTimeAndWhatComesBack() {
        let flow = flow()
        flow.edit { run in
            run.wordsInArt = true
            run.makesMotion = true
        }
        #expect(!flow.isStarted)
        #expect(flow.minutes == 17)
        #expect(EventArtworkBrief.result(style: .newLook, wordsInArt: true, makesMotion: true, languages: 2)
            == "One pair for each of the 2 languages, plus a moving version of each.")
        #expect(EventArtworkBrief.result(style: .extendCard, wordsInArt: false, makesMotion: false, languages: 2)
            == "Your event card stays as it is. Only the details image is new.")
        #expect(EventArtworkBrief.summary(style: .template, wordsInArt: false, makesMotion: true, appName: "Lumen")
            == "3 concepts from Atlas’s event layouts, in Lumen’s colors · about 11 min · nothing reaches the App Store until you push")
        #expect(EventArtworkBrief.wordsDetail(isOn: false, languages: 2).hasPrefix("Off: the App Store writes the name"))
    }

    // MARK: - Making

    @Test func makeTheArtworkStartsClaudeCode() async throws {
        let flow = flow()
        let id = UUID()
        var started: (ClaudeCodeRunPurpose, String)?
        flow.launch = { purpose, prompt in
            started = (purpose, prompt)
            return id
        }
        await flow.make()
        let run = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(run.step == .making)
        #expect(run.claudeRunID == id)
        // The Brief closes: the concepts fill in on the event's page.
        #expect(studio.presentedKey == nil)
        #expect(started?.0 == .eventArtworkConcepts(eventID: "winter"))
        #expect(started?.1.contains("get_event_artwork_brief") == true)
        #expect(started?.1.contains("propose_event_artwork_concept") == true)
        #expect(flow.copiedPrompt == nil)
        #expect(flow.progressText == "0 of 3 concepts ready · about 10 min left")
    }

    @Test func withoutClaudeCodeHereThePromptIsCopied() async {
        let flow = flow()
        var copied: String?
        flow.copy = { copied = $0 }
        await flow.make()
        #expect(copied?.contains("Winter Reflection 2026") == true)
        #expect(flow.copiedPrompt == copied)
        #expect(flow.step == .making)
    }

    @Test func stopEndsClaudeCodeAndAddsNothing() async {
        let flow = flow()
        let id = UUID()
        var stopped: UUID?
        var toast: ToastMessage?
        flow.launch = { _, _ in id }
        flow.stopClaude = { stopped = $0 }
        flow.onToast = { message, _ in toast = message }
        await flow.make()
        flow.stop()
        #expect(stopped == id)
        #expect(!flow.isStarted)
        #expect(studio.presentedKey == nil)
        #expect(toast?.text == "Stopped. Nothing was added to the event.")
        #expect(queue.changes.isEmpty)
    }

    @Test func aRunMadeAwayFromItsPageWaitsToBeSeen() async {
        let away = flow()
        await away.make()
        #expect(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.isHidden == true)
        studio.remove(Test.key)
        studio.watch(Test.key)
        let here = flow()
        await here.make()
        #expect(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.isHidden == false)
        #expect(studio.readyRuns.isEmpty)
    }

    @Test func closingAnUntouchedBriefLeavesNothing() {
        let flow = flow()
        studio.presentedKey = Test.key
        flow.edit { $0.brief = "Snow." }
        flow.close()
        #expect(!flow.isStarted)
        #expect(studio.presentedKey == nil)
    }

    // MARK: - The preview

    @Test func thePreviewShowsThePickThenTheOneClicked() throws {
        let flow = flow()
        var run = try Test.run(step: .choose, concepts: [Test.concept("a", in: directory), Test.concept("b", isPick: true, in: directory)])
        run.pickedID = nil
        studio.begin(run)
        #expect(flow.previewConcept?.id == "b")
        flow.preview("a")
        #expect(flow.previewConcept?.id == "a")
    }

    @Test func onceOneIsUsedThePreviewStaysOnItUntilChange() async throws {
        let flow = flow()
        var run = try Test.run(step: .choose, concepts: [
            Test.concept("a", isPick: true, in: directory), Test.concept("b", in: directory), Test.concept("c", in: directory),
        ])
        run.pickedID = "a"
        studio.begin(run)
        #expect(await flow.use())
        flow.preview("c")
        #expect(flow.previewConcept?.id == "a")
        flow.change()
        #expect(flow.isChanging)
        #expect(flow.previewConcept?.id == "a")
        flow.preview("c")
        #expect(flow.previewConcept?.id == "c")
        flow.keepCurrent()
        #expect(!flow.isChanging)
        #expect(flow.previewConcept?.id == "a")
    }

    @Test func theUsedConceptCanBeUsedAgainOnlyOnceChanged() throws {
        var run = try Test.run(step: .check, concepts: [Test.concept("a", in: directory), Test.concept("b", in: directory)])
        run.usedConceptID = "a"
        run.usedAt = Events.now
        #expect(!run.canUse(run.concepts[0]))
        #expect(run.canUse(run.concepts[1]))
        run.concepts[0].revisedAt = Events.now.addingTimeInterval(60)
        #expect(run.canUse(run.concepts[0]))
        run.revisingID = "b"
        #expect(!run.canUse(run.concepts[1]))
    }

    @Test func checkLocalesAreTheLanguagesWorthALook() {
        let event = InAppEvent(
            id: "e", referenceName: "E", state: .draft, primaryLocale: "en-US",
            localizations: ["en-US": "Winter", "de-DE": "Winter-Reflexions-Herausforderung", "fr-FR": "Hiver", "ja": "冬", "ar-SA": "الشتاء"]
                .sorted { $0.key < $1.key }
                .map { InAppEventLocalization(id: $0.key, locale: $0.key, name: $0.value) }
        )
        let flow = flow(event: event)
        #expect(flow.checkLocales == ["en-US", "de-DE", "ja", "ar-SA"])
    }

    @Test func askingForChangesRedrawsOnlyThatPair() async throws {
        let flow = flow()
        try chosen(flow)
        var prompt: String?
        flow.launch = { _, text in
            prompt = text
            return UUID()
        }
        await flow.sendChanges("Warmer. More snow", to: "a")
        let run = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(run.step == .making)
        #expect(run.revisingID == "a")
        #expect(run.revisionRequest == "Warmer. More snow")
        #expect(prompt?.contains("“Concept a”") == true)
        #expect(flow.progressText == "Changing “Concept a” · about 3 min left")
        // A second request waits for the first.
        await flow.sendChanges("Darker", to: "b")
        #expect(flow.run.revisingID == "a")
        flow.stop()
        #expect(flow.step == .check)
        #expect(flow.run.revisingID == nil)
    }

    // MARK: - Use This Artwork

    @Test func useQueuesThePairForThePrimaryLanguageAccepted() async throws {
        let flow = flow()
        try chosen(flow)
        var undo: InAppEventsUndo?
        var toast: ToastMessage?
        flow.onToast = { message, given in
            toast = message
            undo = given
        }
        #expect(await flow.use())
        let changes = queue.changes
        // German has no image of its own: it shows the English pair
        // without a copy.
        #expect(changes.count == 2)
        #expect(changes.allSatisfy { $0.awaitingAcceptance == nil })
        #expect(changes.allSatisfy { $0.source == .assistant(client: "Claude Code") })
        #expect(Set(changes.map(\.id)) == [
            "inAppEvents.\(Events.app.id).winter.artwork.card.en-US", "inAppEvents.\(Events.app.id).winter.artwork.details.en-US",
        ])
        let run = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(run.usedConceptID == "a")
        #expect(run.usedAt == Events.now)
        #expect(studio.presentedKey == nil)
        #expect(toast?.text == "“Concept a” is the artwork for Winter Reflection 2026. Both images are in Review & Push.")
        #expect(toast?.canUndo == true)
        #expect(undo?.artwork == Test.key)
    }

    @Test func undoPutsTheQueueAndTheConceptBack() async throws {
        let events = InAppEventsViewModel(app: Events.app, services: FakeInAppEventsServices(), store: InAppEventsStore(), queue: queue)
        events.artworkStudio = studio
        let flow = flow()
        try chosen(flow)
        flow.onToast = { message, undo in
            events.toast = message
            events.undo = undo
        }
        await flow.use()
        #expect(queue.changes.count == 2)
        events.undoAccept()
        #expect(queue.changes.isEmpty)
        #expect(studio.run(appID: Test.key.appID, eventID: Test.key.eventID)?.usedConceptID == nil)
    }

    /// A language with its own card in App Store Connect would keep showing
    /// it: it gets the new one too (its details page shows the English one).
    @Test func aLanguageWithItsOwnImageGetsTheNewOneToo() async throws {
        var event = Events.winter
        event.localizations[1].media = [InAppEventMedia(kind: .card, width: 1920, height: 1080, fileName: "old-de.png", fileSize: 10)]
        let flow = flow(event: event)
        try chosen(flow)
        #expect(await flow.use())
        #expect(Set(queue.changes.map(\.id)) == [
            "inAppEvents.\(Events.app.id).winter.artwork.card.en-US", "inAppEvents.\(Events.app.id).winter.artwork.details.en-US",
            "inAppEvents.\(Events.app.id).winter.artwork.card.de-DE",
        ])
    }

    /// Art drawn per language (the name in it) is a file of its own in each.
    @Test func artDrawnPerLanguageGoesIntoEachLanguage() async throws {
        func tagged(_ stills: [EventArtworkImage], _ locale: String) -> [EventArtworkImage] {
            stills.map { still in
                var tagged = still
                tagged.locale = locale
                return tagged
            }
        }
        var concept = try Test.concept("a", isPick: true, in: directory)
        // The German pair looks different: its own files.
        let drawnInGerman = try Test.concept("de", busy: true, in: directory)
        concept.stills = tagged(concept.stills, "en-US") + tagged(drawnInGerman.stills, "de-DE")
        var run = Test.run(step: .check, concepts: [concept])
        run.pickedID = "a"
        studio.begin(run)
        #expect(await flow().use())
        #expect(queue.changes.count == 4)
        let german = InAppEventChangeBuilder(appID: Events.app.id).queuedArtwork(for: "winter", in: queue.changes).filter { $0.locale == "de-DE" }
        #expect(german.map(\.push.fileName).sorted() == ["de-card.png", "de-details.png"])
    }

    @Test func chosenFilesOpenFullSize() async throws {
        let flow = flow()
        let card = directory.appending(path: "mine-card.png")
        let details = directory.appending(path: "mine-details.png")
        try EventArtworkTestFiles.png(width: 1920, height: 1080).write(to: card)
        try EventArtworkTestFiles.png(width: 1080, height: 1920, busy: true).write(to: details)
        await flow.chooseFiles([card, details])
        let concept = try #require(flow.run.picked)
        #expect(flow.step == .check)
        #expect(concept.source == .files)
        #expect(concept.kinds == [.card, .details])
        #expect(!concept.isMadeByClaudeDesign)
        #expect(concept.checks.first?.isOK == false)
        // They open full size, with where the App Store writes.
        #expect(flow.viewer?.conceptID == EventArtworkFlow.filesConceptID)
        #expect(flow.viewer?.showsTextArea == true)
        #expect(await flow.use())
        #expect(queue.changes.allSatisfy { $0.source == .you })
    }

    @Test func filesAtlasCantReadSaySo() async {
        let flow = flow()
        let text = directory.appending(path: "notes.txt")
        try? Data("hello".utf8).write(to: text)
        await flow.chooseFiles([text])
        #expect(flow.problem?.hasPrefix("Atlas couldn’t read those files.") == true)
        #expect(!flow.isStarted)
    }

    // MARK: - Make Them Move

    @Test func makeThemMoveAnimatesTheConceptsAsTheyAre() async throws {
        let flow = flow()
        var run = try Test.run(step: .choose, concepts: [Test.concept("a", isPick: true, in: directory), Test.concept("b", in: directory)])
        for index in run.concepts.indices { run.concepts[index].pages = [.card: "<html>card</html>", .details: "<html>details</html>"] }
        studio.begin(run)
        #expect(flow.run.canAddMotion)
        var prompt: String?
        flow.launch = { _, text in
            prompt = text
            return UUID()
        }
        await flow.addMotion()
        let started = try #require(studio.run(appID: Test.key.appID, eventID: Test.key.eventID))
        #expect(started.step == .making)
        #expect(started.makesMotion)
        #expect(started.animatingIDs == ["a", "b"])
        #expect(started.concepts.count == 2)
        #expect(prompt?.contains("“Concept a” and “Concept b”") == true)
        #expect(prompt?.contains("addMotion") == true)
        #expect(flow.progressText == "Adding motion to 2 concepts · about 6 min left")
        #expect(!flow.run.canAddMotion)
        flow.stop()
        #expect(flow.step == .choose)
        #expect(flow.run.animatingIDs == nil)
        #expect(flow.run.concepts.count == 2)
    }

    /// Concepts without their pages (files the person chose) can't be
    /// animated, and moving ones need nothing.
    @Test func onlyStillDesignedConceptsCanMove() throws {
        var run = try Test.run(step: .choose, concepts: [Test.concept("a", in: directory)])
        #expect(!run.canAddMotion)
        run.concepts[0].pages = [.card: "<html></html>"]
        #expect(run.canAddMotion)
        run.concepts[0].videos = run.concepts[0].stills
        #expect(!run.canAddMotion)
    }
}
