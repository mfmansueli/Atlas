//
//  EventArtworkViewerTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// The full-size viewer over the window (board 47): opened on a concept,
/// ← → round the concepts with the page's preview following, the title
/// and subtitle, the languages of the App Store's text, a moving version
/// over the still, Ask for Changes in its panel, and Use This Artwork.
@MainActor
@Suite("Event artwork viewer")
struct EventArtworkViewerTests {
    typealias Test = EventArtworkStudioTestData
    typealias Events = InAppEventsTestData

    private let directory = EventArtworkTestFiles.directory()
    private let studio = EventArtworkStudio()
    private let queue = ChangeQueue()

    private func flow(step: EventArtworkStep = .choose, videos: [EventArtworkImage] = []) throws -> EventArtworkFlow {
        var first = try Test.concept("a", isPick: true, in: directory)
        first.videos = videos
        let run = try Test.run(step: step, concepts: [first, Test.concept("b", in: directory), Test.concept("c", in: directory)])
        studio.begin(run)
        let flow = EventArtworkFlow(app: Events.app, event: Events.winter, studio: studio, queue: queue, hasDesignSystem: true)
        flow.directory = directory
        flow.now = { Events.now }
        return flow
    }

    private func video(_ kind: InAppEventMedia.Kind) -> EventArtworkImage {
        EventArtworkImage(kind: kind, fileID: "loop-\(kind.mcpValue)", path: "/tmp/loop-\(kind.mcpValue).mov", isVideo: true)
    }

    @Test func opensOnTheConceptClickedAndThePreviewFollows() throws {
        let flow = try flow()
        flow.openViewer(conceptID: "b", kind: .card, locale: "en-US")
        #expect(flow.viewer?.conceptID == "b")
        #expect(flow.viewer?.showsText == true)
        #expect(flow.viewer?.showsTextArea == false)
        #expect(flow.previewConcept?.id == "b")
        #expect(flow.viewerTitle == "Concept b")
        #expect(flow.viewerSubtitle == "Concept 2 of 3 · Claude · Event card · 1920 × 1080")
        #expect(flow.viewerWhy == "Why b.")
    }

    @Test func theArrowsGoRoundTheConcepts() throws {
        let flow = try flow()
        flow.openViewer(conceptID: "c", kind: .details, locale: "en-US")
        #expect(flow.viewerCanStep)
        flow.stepViewer(1)
        #expect(flow.viewer?.conceptID == "a")
        #expect(flow.previewConcept?.id == "a")
        flow.stepViewer(-1)
        flow.stepViewer(-1)
        #expect(flow.viewer?.conceptID == "b")
        #expect(flow.viewerPosition?.index == 2)
        #expect(flow.viewerSubtitle == "Concept 2 of 3 · Claude · Event details · 1080 × 1920")
    }

    @Test func aConceptThatIsntInOpensTheEventsOwnImages() throws {
        let flow = try flow()
        flow.openViewer(conceptID: "missing", kind: .card, locale: "en-US")
        #expect(flow.viewer?.conceptID == nil)
        #expect(!flow.viewerCanStep)
        #expect(flow.viewerTitle == "Winter Reflection 2026")
        #expect(flow.viewerWhy == "Event card and event details for Winter Reflection 2026.")
        #expect(!flow.viewerCanUse)
        #expect(!flow.viewerCanAsk)
    }

    @Test func theMovingVersionPlaysOverTheStill() throws {
        let flow = try flow(videos: [video(.card)])
        flow.openViewer(conceptID: "a", kind: .card, locale: "en-US")
        #expect(flow.viewerVideo(.card)?.isVideo == true)
        #expect(flow.viewerStill(.card)?.isVideo == false)
        #expect(flow.viewerVideo(.details) == nil)
        #expect(flow.viewerSubtitle.hasSuffix("moving version, \(AutopilotArtworkMotion.loopSeconds) s loop"))
    }

    @Test func theTextReadsInTheLanguagesWorthALookSuggestedOnesToo() throws {
        let flow = try flow()
        flow.openViewer(conceptID: "a", kind: .card, locale: "en-US")
        // The event is written in English (the longest name) and German;
        // Japanese and Arabic are only suggested.
        #expect(flow.viewerLocales(pageLocale: "en-US", languages: ["en-US", "de-DE", "ja", "ar-SA"]) == ["en-US", "ja", "ar-SA"])
        // The page's language comes second, and the one shown is always there.
        flow.viewer?.locale = "fr-FR"
        #expect(flow.viewerLocales(pageLocale: "de-DE", languages: ["en-US", "de-DE", "ja", "fr-FR"]) == ["en-US", "de-DE", "ja", "fr-FR"])
    }

    @Test func askForChangesRedrawsThePairInPlace() async throws {
        let flow = try flow()
        var prompt: String?
        flow.launch = { _, text in
            prompt = text
            return UUID()
        }
        flow.openViewer(conceptID: "b", kind: .card, locale: "en-US")
        flow.openAsk()
        #expect(flow.viewer?.isAsking == true)
        #expect(flow.viewer?.request == EventArtworkViewer.defaultRequest)
        flow.useChip("Warmer")
        #expect(flow.viewer?.request == "Warmer.")
        await flow.sendViewerChanges()
        #expect(flow.viewer?.isAsking == false)
        #expect(flow.viewer?.conceptID == "b")
        #expect(flow.viewerIsRevising)
        #expect(!flow.viewerCanAsk)
        #expect(!flow.viewerCanUse)
        #expect(flow.run.revisionRequest == "Warmer.")
        #expect(prompt?.contains("“Concept b”") == true)
    }

    @Test func askIsntOfferedInFullScreen() throws {
        let flow = try flow()
        flow.openViewer(conceptID: "a", kind: .card, locale: "en-US")
        flow.viewer?.isFull = true
        flow.openAsk()
        #expect(flow.viewer?.isAsking == false)
    }

    @Test func useFromTheViewerClosesItAndMarksTheConcept() async throws {
        let flow = try flow()
        flow.openViewer(conceptID: "c", kind: .card, locale: "en-US")
        #expect(flow.viewerCanUse)
        #expect(await flow.use("c"))
        #expect(flow.viewer == nil)
        #expect(flow.run.usedConceptID == "c")
        flow.openViewer(conceptID: "c", kind: .card, locale: "en-US")
        #expect(flow.viewerIsUsed)
        #expect(!flow.viewerCanUse)
        flow.stepViewer(1)
        #expect(flow.viewerCanUse)
    }
}
