//
//  AssistantChatRoomTests.swift
//  AtlasTests
//

import SwiftUI
import Testing
@testable import Atlas

/// The chat's pill in the corner (board 69) never covers a page's bottom
/// bar: the page leaves the pill's place, height and a gap under it, as
/// the prototype's product page does (`padding-bottom: 58px`), and a toast
/// lifts the pill above itself.
@Suite("Chat · room for the pill")
struct AssistantChatRoomTests {
    @Test func aPageLeavesThePillsPlaceHeightAndAGap() {
        let pillTop = AssistantChatRoom.bottomPadding(isToastShown: false) + Metrics.chatPillHeight
        #expect(AssistantChatRoom.pageRoom == pillTop + AssistantChatRoom.gap)
        #expect(AssistantChatRoom.pageRoom > pillTop)
        // 12 + 36 + 8: the prototype's 58 on the tokens' grid.
        #expect(AssistantChatRoom.pageRoom == 56)
    }

    @Test func withNoToastThePillRestsNearTheBottomEdge() {
        #expect(AssistantChatRoom.bottomPadding(isToastShown: false) == AssistantChatRoom.bottomInset)
        #expect(AssistantChatRoom.bottomPadding(isToastShown: false) < AssistantChatRoom.pageRoom)
    }

    @Test func aToastLiftsThePillAboveIt() {
        let lifted = AssistantChatRoom.bottomPadding(isToastShown: true)
        #expect(lifted == AssistantChatRoom.toastInset + Metrics.chatPillHeight + AssistantChatRoom.gap)
        #expect(lifted > AssistantChatRoom.bottomPadding(isToastShown: false))
        #expect(lifted > AssistantChatRoom.toastInset)
    }

    @Test func outsideTheWorkspaceNoRoomIsLeft() {
        #expect(EnvironmentValues().chatCornerRoom == 0)
    }

    @Test func anyToastOnScreenCounts() {
        #expect(ToastShownPreferenceKey.defaultValue == false)
        for (first, next, expected) in [(false, false, false), (false, true, true), (true, false, true), (true, true, true)] {
            var value = first
            ToastShownPreferenceKey.reduce(value: &value) { next }
            #expect(value == expected)
        }
    }
}
