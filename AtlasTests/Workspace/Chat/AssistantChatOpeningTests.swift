//
//  AssistantChatOpeningTests.swift
//  AtlasTests
//

import SwiftUI
import Testing
@testable import Atlas

/// The chat opens by growing out of the pill and closes back into it, from
/// the corner they share, on motion.base; with Reduce Motion the two only
/// cross-fade, on motion.fast.
@Suite("Chat · opening and closing")
struct AssistantChatOpeningTests {
    @Test func reduceMotionCrossFadesAndOtherwiseThePillGrows() {
        #expect(AssistantChatOpening.style(reduceMotion: false) == .grow)
        #expect(AssistantChatOpening.style(reduceMotion: true) == .fade)
    }

    @Test func growingTakesTheBaseTokenAndFadingTheFastOne() {
        #expect(AssistantChatOpening.grow.token == MotionTiming.base)
        #expect(AssistantChatOpening.fade.token == MotionTiming.fast)
        // No one-shot over 1.2 s (README — Design system §7).
        #expect(AssistantChatOpening.grow.token.duration <= 1.2)
    }

    @Test func thePanelStartsAtThePillsWidthAndThePillEndsAtThePanels() {
        let grow = AssistantChatOpening.grow
        #expect(abs(Metrics.chatPanelWidth * grow.panelScale - Metrics.chatPillWidth) < 0.001)
        #expect(abs(Metrics.chatPillWidth * grow.pillScale - Metrics.chatPanelWidth) < 0.001)
        #expect(grow.panelScale < 1)
        #expect(grow.pillScale > 1)
        #expect(grow.panelTransition.scale == grow.panelScale)
        #expect(grow.pillTransition.scale == grow.pillScale)
    }

    @Test func withReduceMotionNothingScales() {
        let fade = AssistantChatOpening.fade
        #expect(fade.panelScale == 1)
        #expect(fade.pillScale == 1)
        #expect(fade.panelTransition.scale == 1)
        #expect(fade.pillTransition.scale == 1)
    }

    @Test func bothGrowFromTheCornerTheyShare() {
        #expect(AssistantChatOpening.anchor == .bottomTrailing)
    }
}
