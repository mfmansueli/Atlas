//
//  ProposedCaptionPreviewTests.swift
//  AtlasTests
//

#if DEBUG
import Foundation
import Testing
@testable import Atlas

/// A suggested caption drawn on its slot from the template, with the
/// suggestion or as it reads now, on Lumen Journal's sample document where
/// Claude Code suggested three shorter German captions.
@MainActor
@Suite("Proposed caption preview")
struct ProposedCaptionPreviewTests {
    private let document = ScreenshotsDebugDocuments.standard

    private var previews: ProposedCaptionPreview {
        ProposedCaptionPreview(document: document, primaryLocale: .englishUS, engine: ScreenshotLayoutEngine(catalog: ScreenshotsTestFixtures.fonts))
    }

    /// The words the layout draws, line after line.
    private func drawn(_ preview: SlotPreview) -> String {
        preview.layout.lines.map(\.text).joined(separator: " ")
    }

    private func caption(slot: Int) throws -> ProposedCaption {
        try #require(document.openProposedCaptions(in: "de-DE").first { $0.slot == slot })
    }

    @Test func theSuggestedPreviewDrawsTheSuggestedCaption() throws {
        let caption = try caption(slot: 1)
        let preview = try #require(previews.preview(for: caption, on: .iPhone))
        #expect(drawn(preview).contains("Blick"))
        #expect(preview.layout.locale == "de-DE")
        #expect(preview.layout.canvas.display == .iPhone)
    }

    @Test func nowDrawsTheCaptionTheSlotHas() throws {
        let caption = try caption(slot: 1)
        let now = try #require(previews.preview(for: caption, suggested: false, on: .iPhone))
        let suggested = try #require(previews.preview(for: caption, on: .iPhone))
        let current = try #require(document.captions.caption(locale: "de-DE", slot: 1)?.headline)
        let firstWord = try #require(current.split(separator: " ").first)
        #expect(drawn(now).contains(firstWord))
        #expect(now.job.key != suggested.job.key)
        #expect(!drawn(now).contains("Blick"))
    }

    @Test func aSlotTheTemplateDoesntHaveDrawsNothing() throws {
        var item = try caption(slot: 1)
        item.item.slot = 40
        #expect(previews.preview(for: item, on: .iPhone) == nil)
    }

    @Test func withoutATemplateNothingIsDrawn() throws {
        let caption = try caption(slot: 1)
        var bare = document
        bare.history = nil
        let previews = ProposedCaptionPreview(document: bare, primaryLocale: .englishUS, engine: ScreenshotLayoutEngine(catalog: ScreenshotsTestFixtures.fonts))
        #expect(previews.preview(for: caption, on: .iPhone) == nil)
    }

    @Test func eachSlotWithACaptionWaitingIsDrawn() {
        let german = previews.suggestedSlots(locale: "de-DE", on: .iPhone)
        #expect(Set(german.keys) == Set(document.openProposedCaptions(in: "de-DE").map(\.slot)))
        #expect(german.count == 3)
        #expect(previews.suggestedSlots(locale: "en-US", on: .iPhone).isEmpty)
    }
}
#endif
