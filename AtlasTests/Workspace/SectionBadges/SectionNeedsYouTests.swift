//
//  SectionNeedsYouTests.swift
//  AtlasTests
//

#if DEBUG
import Testing
@testable import Atlas

/// The sidebar's purple mark: Screenshots while the guided run waits for
/// the person (Alba's “Autopilot needs you · Pick the captures” had no mark
/// in the sidebar), Reviews while Reply Automatically left replies.
@MainActor
@Suite("Section needs you")
struct SectionNeedsYouTests {
    @Test func theGuidedRunsTurnMarksScreenshots() {
        for stage in [AutopilotStage.pick, .choose, .watchPreview] {
            #expect(SectionBadgeCounts.needsYou(run: AutopilotTestFixtures.run(stage), autoReplyNeeds: 0) == [.screenshots], "\(stage)")
        }
    }

    @Test func aWorkingRunMarksNothing() {
        for stage in [AutopilotStage.waiting, .capture, .design, .localize, .plan] {
            #expect(SectionBadgeCounts.needsYou(run: AutopilotTestFixtures.run(stage), autoReplyNeeds: 0).isEmpty, "\(stage)")
        }
        #expect(SectionBadgeCounts.needsYou(run: nil, autoReplyNeeds: 0).isEmpty)
    }

    @Test func repliesLeftForThePersonMarkReviews() {
        #expect(SectionBadgeCounts.needsYou(run: nil, autoReplyNeeds: 2) == [.reviews])
    }

    @Test func voiceOverHearsIt() {
        let counts = SectionBadgeCounts([.screenshots: 3], needsYou: [.screenshots, .reviews])
        #expect(counts.accessibilityText(for: .screenshots) == "Screenshots, 3 suggestions to review, Autopilot needs you")
        #expect(counts.accessibilityText(for: .reviews) == "Reviews, Autopilot needs you")
        #expect(counts.accessibilitySummary == "Screenshots, 3 suggestions to review, Autopilot needs you. Reviews, Autopilot needs you")
    }
}
#endif
