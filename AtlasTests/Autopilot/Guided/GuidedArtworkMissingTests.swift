//
//  GuidedArtworkMissingTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// Review & push's header part when the header couldn't be made: why, and
/// what Make Again and Approve do; nothing while it's in the set.
@MainActor
@Suite("GuidedArtworkMissing")
struct GuidedArtworkMissingTests {
    private static let none = ScreenshotExtras(directionName: "Ink Sky", madeAt: .now)

    @Test func aHeaderThatFailedSaysWhyAndOffersMakeAgain() throws {
        let run = StudioDebugHeaderStyle.headerNotMade
        let missing = try #require(GuidedArtworkMissing(run: run, extras: Self.none))
        #expect(missing.title == "Header artwork couldn’t be made")
        #expect(missing.detail == """
        Make Again rebuilds it from your choices, no new design. Or approve the rest without it.
        Details: Couldn’t render the header page in English (U.S.): The page didn’t load
        """)
    }

    /// A run from before `artworkProblem`: the set just has none of it.
    @Test func withoutAReasonItSaysNothingWasSaved() throws {
        var run = StudioDebugHeaderStyle.headerNotMade
        run.extrasProgress?.artworkProblem = nil
        let missing = try #require(GuidedArtworkMissing(run: run, extras: Self.none))
        #expect(missing.detail.hasPrefix("None of it was saved with the set. Make Again"), "\(missing.detail)")
        #expect(!missing.detail.contains("Details:"))
    }

    /// The renderer's reason is never the message: it goes after Details.
    @Test func theReasonGoesInDetails() throws {
        var run = StudioDebugHeaderStyle.headerNotMade
        run.extrasProgress?.artworkProblem = "The page was too heavy."
        let missing = try #require(GuidedArtworkMissing(run: run, extras: Self.none))
        #expect(missing.detail.hasPrefix("Make Again"), "\(missing.detail)")
        #expect(missing.detail.hasSuffix("\nDetails: The page was too heavy."), "\(missing.detail)")
    }

    @Test func madeArtworkOrARunNotReadyIsntMissing() {
        var made = Self.none
        made.artwork = [ExtrasArtworkFile(kind: .header, locale: "en-US", fileID: "h", headline: "", fits: true, byteCount: 1)]
        var run = StudioDebugHeaderStyle.headerNotMade
        run.extrasProgress?.artworkProblem = nil
        #expect(GuidedArtworkMissing(run: run, extras: made) == nil)

        var making = StudioDebugHeaderStyle.headerNotMade
        making.stage = .localize
        #expect(GuidedArtworkMissing(run: making, extras: Self.none) == nil)
    }
}
#endif
