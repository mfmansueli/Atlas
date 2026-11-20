//
//  PageShotsProposalTests.swift
//  AtlasTests
//

import Foundation
import Testing
@testable import Atlas

/// A plan propose_page_screenshots sends (board 52), checked like the
/// person's own captions: the default set's screens each once, every
/// caption in a page language, within App Review's rules and fitting on
/// every device; the primary language on every screen or nothing is kept.
@MainActor
@Suite("Page screenshots proposal")
struct PageShotsProposalTests {
    typealias Test = PageShotsTestFixtures

    private func check(
        _ screens: [JSONValue], angle: String? = "Privacy first.", run: PageShotsRun = Test.run(displays: [.iPhone, .iPad])
    ) async throws -> PageShotsProposal.Outcome {
        try await PageShotsProposal(run: run, source: Test.source())
            .check(angle: angle, reason: "The lock first.", screens: screens, locales: nil, client: "Claude Code")
    }

    @Test func aPlanInThePagesOrderKeepsEveryCaptionThatFits() async throws {
        let outcome = try await check([
            Test.screen(5, ["en-US": "Locked with Face ID", "de-DE": "Mit Face ID gesperrt"]),
            Test.screen(1, ["en-US": "Write what you can’t say", "de-DE": "Schreib, was du denkst"]),
            Test.screen(3, ["en-US": "Find any day", "ar": "اعثر على أي يوم"]),
        ])
        guard case let .planned(plan, refused) = outcome else {
            Issue.record("Refused: \(outcome)")
            return
        }
        #expect(refused.isEmpty)
        #expect(plan.screens.map(\.slot) == [4, 0, 2])
        #expect(plan.angle == "Privacy first.")
        #expect(plan.source == "Claude Code")
        #expect(plan.screens[2].caption("ar-SA")?.headline == "اعثر على أي يوم")
        #expect(plan.completeLocales(among: Test.languages) == ["en-US"])
        #expect(plan.missingPlaces(in: "de-DE") == [3])
    }

    @Test func eachScreenOnceAndOnlyTheDefaultSetsScreens() async throws {
        for screens in [[Test.screen(1, ["en-US": "A"]), Test.screen(1, ["en-US": "B"])], [Test.screen(9, ["en-US": "A"])], []] {
            guard case let .refused(message, _) = try await check(screens) else {
                Issue.record("\(screens) was kept")
                continue
            }
            #expect(!message.isEmpty)
        }
        guard case let .refused(twice, _) = try await check([Test.screen(2, ["en-US": "A"]), Test.screen(2, ["en-US": "B"])]) else { return }
        #expect(twice.contains("Screen 2 is there twice"))
        guard case let .refused(noAngle, _) = try await check([Test.screen(1, ["en-US": "A"])], angle: nil) else { return }
        #expect(noAngle.contains("`angle`"))
    }

    @Test func aCaptionThatCantBeKeptIsLeftOutAndSaid() async throws {
        let long = String(repeating: "Schreib alles auf, was dir einfällt ", count: 6)
        let outcome = try await check([
            Test.screen(5, ["en-US": "Locked with Face ID", "fr-FR": "Verrouillé", "xx": "?", "de-DE": long]),
            Test.screen(1, ["en-US": "Write it down", "ja": "無料で書こう", "ar-SA": "  "]),
        ])
        guard case let .planned(plan, refused) = outcome else {
            Issue.record("Refused: \(outcome)")
            return
        }
        let reasons = Dictionary(refused.map { ("\($0.place) \($0.locale)", $0.reason) }) { first, _ in first }
        #expect(reasons["1 fr-FR"]?.contains("The page isn’t in fr-FR") == true)
        #expect(reasons["1 xx"]?.contains("isn’t an App Store locale") == true)
        #expect(reasons["1 de-DE"]?.contains("Write it shorter") == true)
        #expect(reasons["2 ja"] != nil)
        #expect(reasons["2 ar-SA"] == "The headline is empty.")
        #expect(plan.screens[0].caption("de-DE") == nil)
        #expect(plan.screens[1].caption("ja") == nil)
        #expect(refused.map(\.locale) == ["ar-SA", "de-DE", "fr-FR", "ja", "xx"])
    }

    @Test func withoutTheirPrimaryCaptionNothingIsKept() async throws {
        let outcome = try await check([
            Test.screen(5, ["en-US": "Locked with Face ID"]),
            Test.screen(1, ["de-DE": "Schreib es auf"]),
            Test.screen(2, ["en-US": "Try it free"]),
        ])
        guard case let .refused(message, refused) = outcome else {
            Issue.record("Kept: \(outcome)")
            return
        }
        #expect(message.contains("place 2"))
        #expect(refused.map(\.place) == [3])
    }

    @Test func aScreenKeepsItsCaptionsWhereverItMoves() async throws {
        let first = Test.plan(locales: ["en-US", "de-DE"], count: 2)
        let run = Test.run(plan: first, displays: [.iPhone])
        let outcome = try await check([Test.screen(1, ["en-US": "Write what you can’t say"]), Test.screen(5, [:])], run: run)
        guard case let .planned(plan, refused) = outcome else {
            Issue.record("Refused: \(outcome)")
            return
        }
        #expect(refused.isEmpty)
        #expect(plan.screens.map(\.slot) == [0, 4])
        #expect(plan.screens[0].caption("en-US")?.headline == "Write what you can’t say")
        #expect(plan.screens[0].caption("de-DE")?.headline == "Schreib, was du nicht laut sagst")
        #expect(plan.screens[1].caption("en-US")?.headline == "Locked with Face ID")
        #expect(plan.angle == "Privacy first.")
    }
}
