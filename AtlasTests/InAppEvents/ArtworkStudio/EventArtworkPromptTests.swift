//
//  EventArtworkPromptTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// What Make the Artwork starts Claude Code with: the brief, then the app's
/// own visual world, then the pages, each rendered and looked at under the
/// App Store's text before it's sent. The first Alba run (2026-11-18) sent
/// three concepts it had never looked at.
@Suite("Event artwork prompts")
struct EventArtworkPromptTests {
    private let text = EventArtworkPrompt.text(app: "Alba", appID: "1", event: "Gratitude Week", eventID: "2", count: 3)

    @Test func theStepsComeInOrder() throws {
        let steps = ["get_event_artwork_brief", "Glob, Grep and Read", "3 different ideas", "render_event_artwork", "propose_event_artwork_concept"]
        let positions = try steps.map { step in try #require(text.range(of: step)?.lowerBound, "missing \(step)") }
        #expect(positions == positions.sorted())
    }

    @Test func eachRenderIsLookedAtUnderTheAppStoresText() {
        #expect(text.contains("look at both images it returns"))
        #expect(text.contains("selfCheck"))
        #expect(text.contains("the art direction"))
        #expect(text.contains("Never push and never submit the event"))
    }

    @Test func aRevisionIsRenderedBeforeItsSent() throws {
        let revision = EventArtworkPrompt.revision(app: "Alba", appID: "1", event: "Gratitude Week", eventID: "2", concept: "First Light")
        let render = try #require(revision.range(of: "render_event_artwork")?.lowerBound)
        let send = try #require(revision.range(of: "propose_event_artwork_concept")?.lowerBound)
        #expect(render < send)
    }

    @Test func theAskPromptChecksEachRenderAgainstTheArtDirection() {
        let ask = InAppEventArtworkAskPrompt.text(app: "Alba", appID: "1", event: "Gratitude Week", eventID: "2")
        #expect(ask.contains("art direction"))
        #expect(ask.contains("selfCheck"))
    }

    /// Templates are compositions to build a scene from, not pictures:
    /// "a row of steps" came back as six rounded bars.
    @Test func templatesDescribeScenesNotShapes() {
        for template in EventArtworkTemplate.allCases {
            #expect(template.layout.contains("In a loop"), "\(template) says how it moves")
        }
        #expect(EventArtworkTemplate.challenge.layout.contains("not a row of steps"))
    }

    @Test func motionKeepsTheDrawingsAndChecksTheLoop() throws {
        let motion = EventArtworkPrompt.motion(app: "Alba", appID: "1", event: "Gratitude Week", eventID: "2", concepts: ["Seven Dawns", "Firefly Bloom"])
        #expect(motion.contains("“Seven Dawns” and “Firefly Bloom”"))
        #expect(motion.contains("Keep every drawing exactly as it is"))
        let check = try #require(motion.range(of: "motionFrames: true")?.lowerBound)
        let send = try #require(motion.range(of: "propose_event_artwork_concept and replaces")?.lowerBound)
        #expect(check < send)
        #expect(motion.contains("Never push and never submit the event"))
    }

    @Test func aMovingRunChecksItsMotionBeforeSending() {
        let moving = EventArtworkPrompt.text(app: "Alba", appID: "1", event: "Gratitude Week", eventID: "2", count: 3, makesMotion: true)
        #expect(moving.contains("motionDirection"))
        #expect(moving.contains("motionFrames: true"))
        #expect(!text.contains("motionFrames"))
    }

    /// Apple's rules for event videos, as the brief gives them.
    @Test func theMotionDirectionHasApplesRules() {
        let apple = EventArtworkMotion.apple.joined(separator: " ")
        #expect(apple.contains("5 to 30 seconds at 30 or 60 fps"))
        #expect(apple.contains("muted, over and over"))
        #expect(apple.contains("no words or logos"))
        let craft = EventArtworkMotion.craft.joined(separator: " ")
        #expect(craft.contains("never more than three flashes a second"))
        #expect(craft.contains("negative animation-delay"))
        #expect(EventArtworkMotion.selfCheck.first?.contains("motionFrames: true") == true)
    }
}
